-- Add admin-configurable matching thresholds with validated defaults and aal2-admin visibility.
insert into public.app_config(key,value) values
  ('MATCH_COVERAGE_FLOOR','0.25'::jsonb),
  ('MATCH_LEVEL_FLOORS','{"Emerging":51,"Competent":51,"Proficient":70,"Advanced":85}'::jsonb)
on conflict(key) do nothing;

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
  if p_key is null or p_key not in ('AGENT_MODE','PASS_MARK','REQUIRE_VIDEO','AI_KILL_SWITCH','AI_DAILY_CAP_PER_USER','VIDEO_MAX_MB','VIDEO_MAX_SECONDS','BORDERLINE','MATCH_COVERAGE_FLOOR','MATCH_LEVEL_FLOORS') then
    raise exception using errcode='22023', message='configuration key is not allowed';
  end if;
  if p_key='AGENT_MODE' then
    if jsonb_typeof(p_value) is distinct from 'string' or p_value#>>'{}' not in ('mock','direct','n8n') then
      raise exception using errcode='22023', message='invalid AGENT_MODE value';
    end if;
  elsif p_key in ('REQUIRE_VIDEO','AI_KILL_SWITCH') then
    if jsonb_typeof(p_value) is distinct from 'boolean' then raise exception using errcode='22023', message='configuration value must be boolean'; end if;
  elsif p_key in ('PASS_MARK','AI_DAILY_CAP_PER_USER','VIDEO_MAX_MB','VIDEO_MAX_SECONDS','MATCH_COVERAGE_FLOOR') then
    if jsonb_typeof(p_value) is distinct from 'number' then raise exception using errcode='22023', message='configuration value must be numeric'; end if;
    if p_key='PASS_MARK' and (p_value#>>'{}')::numeric not between 0 and 100 then raise exception using errcode='22023', message='PASS_MARK must be between 0 and 100'; end if;
    if p_key='MATCH_COVERAGE_FLOOR' and ((p_value#>>'{}')::numeric not between 0.05 and 0.75 or round((p_value#>>'{}')::numeric,2)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='MATCH_COVERAGE_FLOOR must be between 0.05 and 0.75 with at most two decimal places'; end if;
    if p_key='AI_DAILY_CAP_PER_USER' and ((p_value#>>'{}')::numeric not between 1 and 100 or trunc((p_value#>>'{}')::numeric)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='AI_DAILY_CAP_PER_USER must be an integer from 1 to 100'; end if;
    if p_key='VIDEO_MAX_MB' and ((p_value#>>'{}')::numeric not between 1 and 500 or trunc((p_value#>>'{}')::numeric)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='VIDEO_MAX_MB must be an integer from 1 to 500'; end if;
    if p_key='VIDEO_MAX_SECONDS' and ((p_value#>>'{}')::numeric not between 1 and 3600 or trunc((p_value#>>'{}')::numeric)<>(p_value#>>'{}')::numeric) then raise exception using errcode='22023', message='VIDEO_MAX_SECONDS must be an integer from 1 to 3600'; end if;
  elsif p_key='MATCH_LEVEL_FLOORS' then
    if jsonb_typeof(p_value) is distinct from 'object' then
      raise exception using errcode='22023', message='MATCH_LEVEL_FLOORS must contain four numeric level bounds';
    end if;
    if exists(select 1 from jsonb_object_keys(p_value) as k(key) where k.key not in ('Emerging','Competent','Proficient','Advanced'))
       or (select count(*) from jsonb_object_keys(p_value))<>4
       or exists(select 1 from jsonb_each(p_value) as levels(key,value) where jsonb_typeof(levels.value) is distinct from 'number') then
      raise exception using errcode='22023', message='MATCH_LEVEL_FLOORS must contain four numeric level bounds';
    end if;
    if exists(select 1 from jsonb_each(p_value) as levels(key,value) where (levels.value#>>'{}')::numeric not between 1 and 100 or (levels.value#>>'{}')::numeric<>trunc((levels.value#>>'{}')::numeric))
       or (p_value->>'Emerging')::numeric>(p_value->>'Competent')::numeric
       or (p_value->>'Competent')::numeric>(p_value->>'Proficient')::numeric
       or (p_value->>'Proficient')::numeric>(p_value->>'Advanced')::numeric then
      raise exception using errcode='22023', message='MATCH_LEVEL_FLOORS values must be ordered integers from 1 to 100';
    end if;
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

create or replace view public.admin_app_config_v with (security_invoker=false) as
select c.key,c.value,c.updated_by,c.updated_at
from public.app_config c
where c.key in ('AGENT_MODE','PASS_MARK','BORDERLINE','REQUIRE_VIDEO','VIDEO_MAX_MB',
                'VIDEO_MAX_SECONDS','AI_DAILY_CAP_PER_USER','AI_KILL_SWITCH','SCORE_BLEND_N','GRANT_DURATIONS',
                'MATCH_COVERAGE_FLOOR','MATCH_LEVEL_FLOORS')
  and private.is_admin();
revoke all on public.admin_app_config_v from public,anon,authenticated;
grant select on public.admin_app_config_v to authenticated;
comment on view public.admin_app_config_v is 'Aal2 admin-only allowlisted config with last editor and timestamp, including matching score thresholds.';
