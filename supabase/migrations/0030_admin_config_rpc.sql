-- Admin configuration writes are atomic, audited, and restricted to a fixed key/value contract.
-- TODO(decision): review configurable numeric bounds against operational policy before production use.
create or replace function public.admin_update_config(p_actor_id uuid, p_key text, p_value jsonb)
returns table(config_key text, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  v_old_value jsonb;
  v_updated_at timestamptz;
begin
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='admin') then
    raise exception using errcode='42501', message='admin role required';
  end if;
  if p_key is null or p_key not in ('AGENT_MODE','PASS_MARK','REQUIRE_VIDEO','AI_KILL_SWITCH','AI_DAILY_CAP_PER_USER','VIDEO_MAX_MB','VIDEO_MAX_SECONDS','BORDERLINE') then
    raise exception using errcode='22023', message='configuration key is not allowed';
  end if;
  if p_key='AGENT_MODE' then
    if jsonb_typeof(p_value) is distinct from 'string' or p_value#>>'{}' not in ('mock','direct','n8n') then
      raise exception using errcode='22023', message='invalid AGENT_MODE value';
    end if;
  elsif p_key in ('REQUIRE_VIDEO','AI_KILL_SWITCH') then
    if jsonb_typeof(p_value) is distinct from 'boolean' then raise exception using errcode='22023', message='configuration value must be boolean'; end if;
  elsif p_key in ('PASS_MARK','AI_DAILY_CAP_PER_USER','VIDEO_MAX_MB','VIDEO_MAX_SECONDS') then
    if jsonb_typeof(p_value) is distinct from 'number' then raise exception using errcode='22023', message='configuration value must be numeric'; end if;
    if p_key='PASS_MARK' and (p_value#>>'{}')::numeric not between 0 and 100 then raise exception using errcode='22023', message='PASS_MARK must be between 0 and 100'; end if;
    if p_key='AI_DAILY_CAP_PER_USER' and ((p_value#>>'{}')::numeric not between 1 and 100 or trunc((p_value#>>'{}')::numeric)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='AI_DAILY_CAP_PER_USER must be an integer from 1 to 100'; end if;
    if p_key='VIDEO_MAX_MB' and ((p_value#>>'{}')::numeric not between 1 and 500 or trunc((p_value#>>'{}')::numeric)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='VIDEO_MAX_MB must be an integer from 1 to 500'; end if;
    if p_key='VIDEO_MAX_SECONDS' and ((p_value#>>'{}')::numeric not between 1 and 3600 or trunc((p_value#>>'{}')::numeric)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='VIDEO_MAX_SECONDS must be an integer from 1 to 3600'; end if;
  elsif p_key='BORDERLINE' then
    if jsonb_typeof(p_value) is distinct from 'array' then
      raise exception using errcode='22023', message='BORDERLINE must be a two-number array';
    end if;
    if jsonb_array_length(p_value)<>2 then
      raise exception using errcode='22023', message='BORDERLINE must be a two-number array';
    end if;
    if jsonb_typeof(p_value->0) is distinct from 'number' or jsonb_typeof(p_value->1) is distinct from 'number' then
      raise exception using errcode='22023', message='BORDERLINE must be a two-number array';
    end if;
    if (p_value->>0)::numeric<0 or (p_value->>1)::numeric>100 or (p_value->>0)::numeric>(p_value->>1)::numeric then
      raise exception using errcode='22023', message='BORDERLINE bounds must be ordered within 0 to 100';
    end if;
  end if;

  select c.value into v_old_value from public.app_config c where c.key=p_key for update;
  if not found then raise exception using errcode='P0002', message='configuration key not found'; end if;
  update public.app_config c set value=p_value,updated_by=p_actor_id,updated_at=now()
   where c.key=p_key returning c.updated_at into v_updated_at;
  insert into public.audit_log(actor_id,action,target_type,metadata)
  values(p_actor_id,'admin_config_updated','app_config',jsonb_build_object('key',p_key,'old_value',v_old_value,'new_value',p_value));
  return query select p_key,v_updated_at;
end;
$$;
revoke all on function public.admin_update_config(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.admin_update_config(uuid,text,jsonb) to service_role;
comment on function public.admin_update_config(uuid,text,jsonb) is 'Service-role-only atomic config write. Edge caller must first pass aal2 and private.is_admin() view gating.';
