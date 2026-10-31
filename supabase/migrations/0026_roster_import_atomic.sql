-- Atomic service-role batch processor for the roster-import Edge Function.
-- Raw student identifiers must already be HMAC-hashed by the Edge Function.
create or replace function public.process_roster_import(
  p_university_id uuid,
  p_rows jsonb,
  p_match_enabled boolean,
  p_dry_run boolean,
  p_actor_id uuid
)
returns table(created int, updated int, matched_existing int, proposals_created int)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_hash text;
  v_email text;
  v_full_name text;
  v_program_level text;
  v_program text;
  v_year int;
  v_status public.life_status;
  v_roster_id uuid;
  v_linked_student_id uuid;
  v_student_id uuid;
  v_current_university_id uuid;
  v_found boolean;
  v_created int := 0;
  v_updated int := 0;
  v_matched int := 0;
  v_proposals int := 0;
begin
  if p_university_id is null or p_actor_id is null or p_rows is null or p_match_enabled is null or p_dry_run is null
     or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 500 then
    raise exception 'invalid roster import arguments';
  end if;
  if not exists(select 1 from public.university_members m where m.university_id=p_university_id and m.user_id=p_actor_id) then
    raise exception 'university membership required' using errcode='42501';
  end if;
  if not exists(select 1 from public.universities u where u.id=p_university_id) then
    raise exception 'university not found' using errcode='P0002';
  end if;

  for v_item in select value from pg_catalog.jsonb_array_elements(p_rows) loop
    v_hash := nullif(v_item->>'student_id_hash','');
    v_email := nullif(pg_catalog.lower(pg_catalog.btrim(v_item->>'email')),'');
    v_full_name := v_item->>'full_name';
    v_program_level := nullif(v_item->>'program_level','');
    v_program := nullif(v_item->>'program','');
    v_year := nullif(v_item->>'year','')::int;
    v_status := nullif(v_item->>'status','')::public.life_status;
    if (v_hash is null and v_email is null) or v_full_name is null or pg_catalog.length(v_full_name)=0 then
      raise exception 'invalid normalized roster row';
    end if;
    if v_hash is not null and v_hash !~ '^[a-f0-9]{64}$' then raise exception 'invalid roster id hash'; end if;
    if v_year is not null and (v_year < 1 or v_year > 10) then raise exception 'invalid roster year'; end if;

    v_roster_id := null;
    v_linked_student_id := null;
    v_found := false;
    select r.id,r.student_id into v_roster_id,v_linked_student_id
      from public.roster_entries r
     where r.university_id=p_university_id
       and ((v_hash is not null and r.student_id_hash=v_hash) or (v_email is not null and r.email=v_email))
     order by case when v_hash is not null and r.student_id_hash=v_hash then 0 else 1 end, r.id
     limit 1 for update;
    v_found := found;
    if v_found then v_updated := v_updated+1; else v_created := v_created+1; end if;

    if not p_dry_run then
      if v_found then
        update public.roster_entries r set student_id_hash=coalesce(v_hash,r.student_id_hash),email=coalesce(v_email,r.email),full_name=v_full_name,
          program_level=coalesce(v_program_level,r.program_level),program=coalesce(v_program,r.program),year=coalesce(v_year,r.year),status=coalesce(v_status,r.status) where r.id=v_roster_id;
      else
        insert into public.roster_entries(university_id,student_id_hash,email,full_name,program_level,program,year,status)
        values(p_university_id,v_hash,v_email,v_full_name,v_program_level,v_program,v_year,coalesce(v_status,'student'::public.life_status))
        returning id into v_roster_id;
      end if;
    end if;

    v_student_id := v_linked_student_id;
    if p_match_enabled and v_student_id is null and v_hash is not null then
      select r.student_id into v_student_id from public.roster_entries r
       where r.student_id_hash=v_hash and r.student_id is not null order by r.created_at limit 1;
    end if;
    if p_match_enabled and v_student_id is null and v_email is not null then
      select s.id into v_student_id
        from public.students s join auth.users u on u.id=s.user_id
       where pg_catalog.lower(u.email)=v_email and u.email_confirmed_at is not null
       order by s.created_at limit 1;
    end if;

    if v_student_id is not null then
      v_matched := v_matched+1;
      select a.university_id into v_current_university_id
        from public.affiliations a where a.student_id=v_student_id and a.is_current limit 1;
      if v_current_university_id is distinct from p_university_id then
        perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_student_id::text||':'||p_university_id::text,0));
        if not exists(select 1 from public.affiliation_proposals ap where ap.student_id=v_student_id and ap.university_id=p_university_id and ap.state='pending') then
          v_proposals := v_proposals+1;
          if not p_dry_run then
            insert into public.affiliation_proposals(student_id,university_id,roster_entry_id,program_level,status,year)
            values(v_student_id,p_university_id,v_roster_id,v_program_level,v_status,v_year);
          end if;
        end if;
      end if;
    end if;

  end loop;

  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,case when p_dry_run then 'roster_import_dry_run' else 'roster_import' end,
    'university',p_university_id,jsonb_build_object('created',v_created,'updated',v_updated,
    'matched_existing',v_matched,'proposals_created',v_proposals,'rows',jsonb_array_length(p_rows)));
  return query select v_created,v_updated,v_matched,v_proposals;
end
$$;
revoke all on function public.process_roster_import(uuid,jsonb,boolean,boolean,uuid) from public,anon,authenticated;
grant execute on function public.process_roster_import(uuid,jsonb,boolean,boolean,uuid) to service_role;
comment on function public.process_roster_import(uuid,jsonb,boolean,boolean,uuid) is
  'Atomic batch upsert for roster-import. Service-role only; receives HMAC hashes, never raw student IDs.';
