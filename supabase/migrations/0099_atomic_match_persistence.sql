-- Persist matches, announce only genuinely new candidates, and write the audit event atomically.
create or replace function public.persist_job_matches(p_job_id uuid,p_actor_id uuid,p_rows jsonb)
returns table(candidate_count integer,new_match_count integer)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
  v_candidate_count integer;
  v_distinct_student_count integer;
  v_new_match_count integer;
  v_vector_count integer;
begin
  if p_job_id is null or p_actor_id is null or p_rows is null
     or jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception using errcode='22023',message='Invalid match persistence batch';
  end if;
  if jsonb_array_length(p_rows)>50000 then
    raise exception using errcode='22023',message='Match persistence batch exceeds the safe bound';
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_rows) as rows(value)
    where case when jsonb_typeof(value)='object' then
      jsonb_object_length(value)<>9
      or not (value ?& array['job_id','student_id','alias','final_score','confidence','reasons','gaps','structured_score','vector_score'])
      or jsonb_typeof(value->'job_id') is distinct from 'string'
      or jsonb_typeof(value->'student_id') is distinct from 'string'
      or jsonb_typeof(value->'alias') is distinct from 'string'
      or jsonb_typeof(value->'final_score') is distinct from 'number'
      or jsonb_typeof(value->'confidence') is distinct from 'number'
      or jsonb_typeof(value->'structured_score') is distinct from 'number'
      or jsonb_typeof(value->'vector_score') not in ('number','null')
      or case when jsonb_typeof(value->'reasons')='array' then
           jsonb_array_length(value->'reasons')>3 or exists(
             select 1 from jsonb_array_elements(value->'reasons') as reason(item)
             where jsonb_typeof(item) is distinct from 'string' or length(item#>>'{}')>400)
         else true end
      or case when jsonb_typeof(value->'gaps')='array' then
           jsonb_array_length(value->'gaps')>3 or exists(
             select 1 from jsonb_array_elements(value->'gaps') as gap(item)
             where jsonb_typeof(item) is distinct from 'string' or length(item#>>'{}')>400)
         else true end
      else true end
  ) then
    raise exception using errcode='22023',message='Match rows must contain exactly the frozen result fields and value types';
  end if;

  -- Lock the job row so concurrent match runs cannot both count and notify the same new candidate.
  select j.organization_id into v_organization_id
  from public.jobs j
  join public.organizations o on o.id=j.organization_id
  join public.organization_members om on om.organization_id=j.organization_id and om.user_id=p_actor_id
  where j.id=p_job_id and j.status='open' and o.status='approved' and o.subscription_status='active'
  -- Lock all authorization/state rows through commit so membership revocation or job/org suspension
  -- cannot race between the authorization check and writes. Keep organization/member locks shareable
  -- so separate jobs can still be matched concurrently for the same organization.
  for update of j
  for share of o, om;
  if not found then
    raise exception using errcode='42501',message='Active approved organization membership and open job required';
  end if;

  if exists (
    select 1 from jsonb_to_recordset(p_rows) as r(
      job_id uuid,student_id uuid,alias text,final_score numeric,confidence numeric,
      reasons text[],gaps text[],structured_score numeric,vector_score numeric
    )
    where r.job_id is distinct from p_job_id or r.student_id is null
      or r.alias is null or r.alias !~ '^Candidate [A-Z2-7]{6}$'
      or r.final_score is null or r.final_score<0 or r.final_score>100
      or r.confidence is null or r.confidence<0 or r.confidence>1
      or r.structured_score is null or r.structured_score<0 or r.structured_score>100
      or (r.vector_score is not null and (r.vector_score<0 or r.vector_score>100))
      or r.reasons is null or cardinality(r.reasons)>3
      or r.gaps is null or cardinality(r.gaps)>3
      or exists(select 1 from unnest(coalesce(r.reasons,'{}'::text[])||coalesce(r.gaps,'{}'::text[])) as text_items(item)
                where item is null or length(item)>400)
  ) then
    raise exception using errcode='22023',message='Match result values violate the frozen result bounds';
  end if;

  select count(*)::int,count(distinct student_id)::int,count(*) filter(where vector_score is not null)::int
    into v_candidate_count,v_distinct_student_count,v_vector_count
  from jsonb_to_recordset(p_rows) as r(
    job_id uuid,student_id uuid,alias text,final_score numeric,confidence numeric,
    reasons text[],gaps text[],structured_score numeric,vector_score numeric
  );
  if v_candidate_count<>v_distinct_student_count then
    raise exception using errcode='22023',message='Match persistence batch contains duplicate students';
  end if;

  -- Recheck live privacy and serialize against opt-out updates until this transaction commits.
  -- Stable student-id ordering reduces deadlock risk for overlapping batches.
  perform s.id
  from jsonb_to_recordset(p_rows) as r(job_id uuid,student_id uuid)
  join public.students s on s.id=r.student_id
  order by s.id
  for update of s;

  if exists (
    select 1 from jsonb_to_recordset(p_rows) as r(job_id uuid,student_id uuid)
    left join public.students s on s.id=r.student_id
    where s.id is null or s.visibility->'discoverable' is distinct from 'true'::jsonb
  ) then
    raise exception using errcode='42501',message='Every matched student must be currently discoverable';
  end if;

  select count(*)::int into v_new_match_count
  from jsonb_to_recordset(p_rows) as r(
    job_id uuid,student_id uuid,alias text,final_score numeric,confidence numeric,
    reasons text[],gaps text[],structured_score numeric,vector_score numeric
  )
  left join public.match_results existing on existing.job_id=r.job_id and existing.student_id=r.student_id
  where existing.id is null;

  insert into public.match_results(job_id,student_id,alias,final_score,confidence,reasons,gaps,structured_score,vector_score)
  select r.job_id,r.student_id,r.alias,r.final_score,r.confidence,r.reasons,r.gaps,r.structured_score,r.vector_score
  from jsonb_to_recordset(p_rows) as r(
    job_id uuid,student_id uuid,alias text,final_score numeric,confidence numeric,
    reasons text[],gaps text[],structured_score numeric,vector_score numeric
  )
  on conflict(job_id,student_id) do update set
    alias=excluded.alias,final_score=excluded.final_score,confidence=excluded.confidence,
    reasons=excluded.reasons,gaps=excluded.gaps,structured_score=excluded.structured_score,
    vector_score=excluded.vector_score;

  if v_new_match_count>0 then
    insert into public.notifications(user_id,kind,payload)
    select distinct om.user_id,'new_match',jsonb_build_object('job_id',p_job_id,'new_match_count',v_new_match_count)
    from public.organization_members om where om.organization_id=v_organization_id;
  end if;

  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'match_job_computed','job',p_job_id,
    jsonb_build_object('organization_id',v_organization_id,'candidate_count',v_candidate_count,'vector_reranked_count',v_vector_count));

  return query select v_candidate_count,v_new_match_count;
end;
$function$;

revoke all on function public.persist_job_matches(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.persist_job_matches(uuid,uuid,jsonb) to service_role;
comment on function public.persist_job_matches(uuid,uuid,jsonb) is
  'Service-only atomic match upsert, count-only new-match notifications, and audit write; job-row lock prevents duplicate concurrent new-match alerts.';
