-- Atomic anonymous application insert plus idempotency storage. The Edge Function
-- performs Zod validation, captcha and hashed rate limits before these RPCs run.
create or replace function public.lookup_submit_application_idempotency(p_key uuid,p_request_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_response jsonb;
begin
  if p_key is null or p_request_hash is null or p_request_hash !~ '^[a-f0-9]{64}$' then
    raise exception using errcode='22023', message='invalid idempotency request';
  end if;
  select i.request_hash,i.response into v_hash,v_response
    from private.idempotency_keys i where i.key=p_key and i.function='submit-application';
  if not found then return null; end if;
  if v_hash is distinct from p_request_hash then
    raise exception using errcode='23505', message='idempotency key reused with a different request';
  end if;
  return v_response;
end;
$$;
revoke all on function public.lookup_submit_application_idempotency(uuid,text) from public,anon,authenticated;
grant execute on function public.lookup_submit_application_idempotency(uuid,text) to service_role;

create or replace function public.submit_application(p_key uuid,p_request_hash text,p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing_hash text;
  v_existing_response jsonb;
  v_subject_id uuid;
  v_application_id uuid;
  v_reference text;
  v_random bytea;
  v_alphabet text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  v_char text;
  v_business_payload jsonb;
  v_email_domains text[] := '{}'::text[];
  v_attempt int;
  v_response jsonb;
begin
  if p_key is null or p_request_hash is null or p_request_hash !~ '^[a-f0-9]{64}$'
     or p_payload is null or jsonb_typeof(p_payload) is distinct from 'object'
     or p_payload ? 'hp' or p_payload ? 'captcha_token'
     or p_payload->>'consent' is distinct from 'true'
     or coalesce(p_payload->>'type','') not in ('university','organization') then
    raise exception using errcode='22023', message='invalid application payload';
  end if;
  if p_payload->>'contact_email' is null and p_payload->>'work_email' is null then
    raise exception using errcode='22023', message='contact email is required';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('submit-application:'||p_key::text,0));
  select i.request_hash,i.response into v_existing_hash,v_existing_response
    from private.idempotency_keys i where i.key=p_key and i.function='submit-application' for update;
  if found then
    if v_existing_hash is distinct from p_request_hash then
      raise exception using errcode='23505', message='idempotency key reused with a different request';
    end if;
    if v_existing_response is not null then return v_existing_response; end if;
  else
    insert into private.idempotency_keys(key,function,request_hash,response)
    values(p_key,'submit-application',p_request_hash,null);
  end if;

  if p_payload->>'type'='university' then
    if jsonb_typeof(coalesce(p_payload->'email_domains','[]'::jsonb)) is distinct from 'array' then
      raise exception using errcode='22023', message='invalid email domains';
    end if;
    select coalesce(array_agg(pg_catalog.lower(d.value)),'{}'::text[]) into v_email_domains
    from pg_catalog.jsonb_array_elements_text(coalesce(p_payload->'email_domains','[]'::jsonb)) as d(value);
    if exists(select 1 from pg_catalog.unnest(v_email_domains) as domains(value)
              where domains.value !~* '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') then
      raise exception using errcode='22023', message='invalid email domain';
    end if;
    insert into public.universities(name,short_name,kind,tier,city,state,email_domains,status)
    values(pg_catalog.btrim(p_payload->>'institution_name'),nullif(pg_catalog.btrim(p_payload->>'short_name'),''),
      p_payload->>'kind',case p_payload->>'tier' when 'tier1' then 1 when 'tier2' then 2 when 'tier3' then 3 else null end,
      pg_catalog.btrim(p_payload->>'city'),pg_catalog.btrim(p_payload->>'state'),v_email_domains,'pending')
    returning id into v_subject_id;
    v_business_payload := pg_catalog.jsonb_build_object(
      'student_count_band',p_payload->>'student_count_band',
      'departments',nullif(pg_catalog.btrim(p_payload->>'departments'),''),
      'message',nullif(pg_catalog.btrim(p_payload->>'message'),''),
      'consent',true
    );
  else
    insert into public.organizations(name,kind,size,website,status,subscription_status)
    values(pg_catalog.btrim(p_payload->>'org_name'),p_payload->>'org_kind',p_payload->>'size_band',
      pg_catalog.btrim(p_payload->>'website'),'pending','inactive')
    returning id into v_subject_id;
    v_business_payload := pg_catalog.jsonb_build_object(
      'hiring_focus',p_payload->'hiring_focus',
      'message',nullif(pg_catalog.btrim(p_payload->>'message'),''),
      'consent',true
    );
  end if;

  for v_attempt in 1..8 loop
    v_random := extensions.gen_random_bytes(6);
    v_reference := 'AH-';
    for i in 0..5 loop
      v_char := pg_catalog.substr(v_alphabet,(pg_catalog.get_byte(v_random,i)%36)+1,1);
      v_reference := v_reference||v_char;
    end loop;
    begin
      insert into public.applications(reference,type,subject_id,contact_name,contact_role,contact_email,contact_phone,payload,status)
      values(v_reference,p_payload->>'type',v_subject_id,pg_catalog.btrim(p_payload->>'contact_name'),
        pg_catalog.btrim(p_payload->>'contact_role'),
        pg_catalog.lower(coalesce(p_payload->>'contact_email',p_payload->>'work_email')),
        nullif(pg_catalog.btrim(p_payload->>'contact_phone'),''),v_business_payload,'received')
      returning id into v_application_id;
      exit;
    exception when unique_violation then
      if v_attempt=8 then raise; end if;
    end;
  end loop;

  v_response := pg_catalog.jsonb_build_object('reference',v_reference,'status','received');
  update private.idempotency_keys i set response=v_response
   where i.key=p_key and i.function='submit-application';
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(null,'application_received','application',v_application_id,
    pg_catalog.jsonb_build_object('reference',v_reference,'application_type',p_payload->>'type'));
  return v_response;
end;
$$;
revoke all on function public.submit_application(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.submit_application(uuid,text,jsonb) to service_role;
comment on function public.submit_application(uuid,text,jsonb) is
  'Service-role-only anonymous application writer; atomically creates pending subject/application, idempotency receipt, audit event, and safe admin notification via trigger.';
