-- Defense in depth for organization jobs: validate the exact JSON contract at the database boundary.
create or replace function private.job_required_skills_are_valid(p_requirements jsonb)
returns boolean
language plpgsql
immutable
security definer
set search_path = ''
as $function$
declare
  v_item jsonb;
  v_skill_id text;
  v_level text;
  v_weight text;
  v_seen text[] := array[]::text[];
begin
  if p_requirements is null or jsonb_typeof(p_requirements) is distinct from 'array' then
    return false;
  end if;
  if jsonb_array_length(p_requirements) > 30 then
    return false;
  end if;
  for v_item in select value from jsonb_array_elements(p_requirements) as entries(value) loop
    if jsonb_typeof(v_item) is distinct from 'object' then
      return false;
    end if;
    if (select count(*) from jsonb_object_keys(v_item)) <> 3 or not (v_item ?& array['skill_id','min_level','weight']) then
      return false;
    end if;
    if jsonb_typeof(v_item->'skill_id') is distinct from 'string'
       or jsonb_typeof(v_item->'min_level') is distinct from 'string'
       or jsonb_typeof(v_item->'weight') is distinct from 'number' then
      return false;
    end if;
    v_skill_id := lower(v_item->>'skill_id');
    v_level := v_item->>'min_level';
    v_weight := v_item->>'weight';
    if v_skill_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or v_level not in ('Emerging','Competent','Proficient','Advanced')
       or v_weight !~ '^(100(\.0{1,4})?|([0-9]{1,2})(\.[0-9]{1,4})?)$' then
      return false;
    end if;
    if v_weight::numeric < 0.01 or v_weight::numeric > 100 or v_skill_id = any(v_seen) then
      return false;
    end if;
    v_seen := array_append(v_seen, v_skill_id);
  end loop;
  return true;
end;
$function$;
revoke all on function private.job_required_skills_are_valid(jsonb) from public,anon,authenticated,service_role;

create or replace function private.validate_job_required_skills_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not private.job_required_skills_are_valid(new.required_skills) then
    raise exception using errcode='23514', message='jobs.required_skills must be an array of at most 30 unique, strictly shaped skill requirements';
  end if;
  if exists (
    select 1 from jsonb_array_elements(new.required_skills) as requirements(item)
     where not exists (select 1 from public.skills sk where sk.id=(requirements.item->>'skill_id')::uuid)
  ) then
    raise exception using errcode='23514', message='jobs.required_skills must reference existing skills';
  end if;
  return new;
end;
$function$;
revoke all on function private.validate_job_required_skills_trigger() from public,anon,authenticated,service_role;

-- Refuse to install over legacy malformed data; silently changing job requirements would be unsafe.
do $preflight$
begin
  if exists (select 1 from public.jobs j where not private.job_required_skills_are_valid(j.required_skills)) then
    raise exception using errcode='23514', message='Existing jobs contain malformed required_skills; correct them before applying migration 0080';
  end if;
  if exists (
    select 1 from public.jobs j
    cross join lateral jsonb_array_elements(j.required_skills) as requirements(item)
    where not exists (select 1 from public.skills sk where sk.id=(requirements.item->>'skill_id')::uuid)
  ) then
    raise exception using errcode='23514', message='Existing jobs reference missing skills; correct them before applying migration 0080';
  end if;
end;
$preflight$;

drop trigger if exists jobs_validate_required_skills on public.jobs;
create trigger jobs_validate_required_skills
before insert or update of required_skills on public.jobs
for each row execute function private.validate_job_required_skills_trigger();

comment on function private.job_required_skills_are_valid(jsonb) is
  'Private pure validator for the frozen match-job skill requirement JSON contract; max 30 distinct UUID skills, four allowed levels, and weights 0.01–100.';
comment on trigger jobs_validate_required_skills on public.jobs is
  'Rejects malformed job requirement JSON before it reaches match-job or aggregate views.';
