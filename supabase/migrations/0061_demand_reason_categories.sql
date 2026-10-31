-- Expand strict anonymous-demand aggregate validation to the six documented categories.
create or replace function public.replace_demand_signals(p_job_id uuid,p_signals jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb;
  v_university_id uuid;
  v_reason_counts jsonb;
  v_skill_slugs text[];
  v_university_ids uuid[] := '{}'::uuid[];
  v_rows integer := 0;
begin
  if p_job_id is null or p_signals is null or jsonb_typeof(p_signals) is distinct from 'array' then
    raise exception using errcode='22023',message='invalid demand signal batch';
  end if;
  if jsonb_array_length(p_signals)>500 then
    raise exception using errcode='22023',message='demand signal batch is too large';
  end if;

  perform 1 from public.jobs j where j.id=p_job_id and j.status='open' for update;
  if not found then raise exception using errcode='P0002',message='open job not found'; end if;

  for v_row in select value from jsonb_array_elements(p_signals) as item(value) loop
    if jsonb_typeof(v_row) is distinct from 'object' then
      raise exception using errcode='22023',message='invalid demand signal row';
    end if;
    if exists(select 1 from jsonb_object_keys(v_row) as k(key) where k.key not in ('university_id','reason_counts','skill_slugs'))
       or (select count(*) from jsonb_object_keys(v_row))<>3 then
      raise exception using errcode='22023',message='invalid demand signal row keys';
    end if;
    if jsonb_typeof(v_row->'reason_counts') is distinct from 'object'
       or jsonb_typeof(v_row->'skill_slugs') is distinct from 'array' then
      raise exception using errcode='22023',message='invalid demand signal row values';
    end if;
    if jsonb_array_length(v_row->'skill_slugs')>30
       or exists(select 1 from jsonb_array_elements(v_row->'skill_slugs') as s(value)
         where jsonb_typeof(s.value) is distinct from 'string'
           or length(s.value#>>'{}') not between 1 and 80
           or s.value#>>'{}' !~ '^[a-z0-9-]+$') then
      raise exception using errcode='22023',message='invalid demand signal skill slugs';
    end if;
    if exists(select 1 from jsonb_object_keys(v_row->'reason_counts') as k(key) where k.key not in ('no_eligible','incomplete_assessments','insufficient_evidence','skills_mismatch','opted_out','not_assessed'))
       or (select count(*) from jsonb_object_keys(v_row->'reason_counts'))<>6
       or exists(select 1 from jsonb_each(v_row->'reason_counts') as counts(key,value) where jsonb_typeof(counts.value) is distinct from 'number') then
      raise exception using errcode='22023',message='invalid demand signal reason counts';
    end if;
    if exists(
      select 1 from jsonb_each(v_row->'reason_counts') as counts(key,value)
       where (counts.value#>>'{}')::numeric not between 0 and 1000000
          or (counts.value#>>'{}')::numeric<>trunc((counts.value#>>'{}')::numeric)
    ) then
      raise exception using errcode='22023',message='invalid demand signal reason counts';
    end if;
    begin
      v_university_id := (v_row->>'university_id')::uuid;
    exception when invalid_text_representation then
      raise exception using errcode='22023',message='invalid university';
    end;
    if v_university_id is null or not exists(select 1 from public.universities u where u.id=v_university_id) then
      raise exception using errcode='22023',message='invalid university';
    end if;
    if v_university_id=any(v_university_ids) then
      raise exception using errcode='22023',message='duplicate university demand signal';
    end if;

    v_university_ids := array_append(v_university_ids,v_university_id);
    v_reason_counts := v_row->'reason_counts';
    select coalesce(array_agg(value#>>'{}' order by ordinality),'{}'::text[])
      into v_skill_slugs
      from jsonb_array_elements(v_row->'skill_slugs') with ordinality as slug(value,ordinality);
    insert into public.demand_signals(job_id,university_id,reason_counts,skill_slugs)
    values(p_job_id,v_university_id,v_reason_counts,v_skill_slugs)
    on conflict(job_id,university_id) where university_id is not null
    do update set reason_counts=excluded.reason_counts,skill_slugs=excluded.skill_slugs,created_at=now();
    v_rows := v_rows+1;
  end loop;

  delete from public.demand_signals d
   where d.job_id=p_job_id
     and (d.university_id is null or not (d.university_id=any(v_university_ids)));
  return v_rows;
end;
$$;
revoke all on function public.replace_demand_signals(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.replace_demand_signals(uuid,jsonb) to service_role;
comment on function public.replace_demand_signals(uuid,jsonb) is 'Service-only atomic refresh of per-university counts-only demand aggregates using the documented six reasons.';
