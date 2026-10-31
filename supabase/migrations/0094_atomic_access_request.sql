-- Commit the consent request, student notification, and audit event together.
-- The service-role Edge Function still performs contact-detail filtering and request rate limits.
create or replace function public.create_access_request(
  p_actor_id uuid,
  p_match_result_id uuid,
  p_message text,
  p_requested_scope text[],
  p_duration_days integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_student_user_id uuid;
  v_candidate_discoverable boolean;
  v_eligible_score_id uuid;
  v_job_id uuid;
  v_organization_id uuid;
  v_job_title text;
  v_organization_name text;
  v_organization_status text;
  v_subscription_status text;
  v_request_id uuid;
begin
  if p_actor_id is null or p_match_result_id is null
     or p_requested_scope is null or cardinality(p_requested_scope) < 1 or cardinality(p_requested_scope) > 4
     or exists(select 1 from pg_catalog.unnest(p_requested_scope) s(value)
       where s.value is null or s.value not in ('profile','scorecard','projects','contact'))
     or cardinality(p_requested_scope) <> (select count(distinct s.value) from pg_catalog.unnest(p_requested_scope) s(value))
     or p_duration_days is null or p_duration_days not in (7,30,90)
     or (p_message is not null and pg_catalog.length(p_message) > 500) then
    raise exception using errcode='22023', message='invalid access request';
  end if;

  select m.student_id,m.job_id,j.organization_id,j.title,o.name,o.status,o.subscription_status,s.user_id,cp.discoverable
    into v_student_id,v_job_id,v_organization_id,v_job_title,v_organization_name,v_organization_status,v_subscription_status,v_student_user_id,v_candidate_discoverable
  from public.match_results m
  join public.jobs j on j.id=m.job_id
  join public.organizations o on o.id=j.organization_id
  join public.students s on s.id=m.student_id
  join public.candidate_profiles cp on cp.student_id=s.id
  where m.id=p_match_result_id
    and exists(select 1 from public.organization_members om where om.organization_id=o.id and om.user_id=p_actor_id)
  for update of j,o,s,cp;
  if not found then raise exception using errcode='P0002', message='candidate match not found'; end if;
  if v_organization_status <> 'approved' or v_subscription_status <> 'active' then
    raise exception using errcode='42501', message='active organization subscription required';
  end if;
  if not exists(select 1 from public.jobs j where j.id=v_job_id and j.status='open') then
    raise exception using errcode='40001', message='job is not open';
  end if;
  if v_student_user_id is null
     or coalesce((select s.visibility->'discoverable'='true'::jsonb from public.students s where s.id=v_student_id),false) is not true
     or v_candidate_discoverable is not true then
    raise exception using errcode='P0002', message='candidate match not found';
  end if;
  select ss.id into v_eligible_score_id from public.skill_scores ss
    where ss.student_id=v_student_id and ss.verified and ss.share_ok and not ss.pending_review
    order by ss.id limit 1 for update;
  if v_eligible_score_id is null then raise exception using errcode='P0002', message='candidate match not found'; end if;

  insert into public.access_requests(organization_id,student_id,job_id,match_result_id,message,requested_scope,duration_days,status)
  values(v_organization_id,v_student_id,v_job_id,p_match_result_id,nullif(pg_catalog.btrim(p_message),''),p_requested_scope,p_duration_days,'pending')
  returning id into v_request_id;

  insert into public.notifications(user_id,kind,payload)
  values(v_student_user_id,'access_request',pg_catalog.jsonb_build_object(
    'request_id',v_request_id,'job_title',v_job_title,'organization_name',v_organization_name));
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'access_request_created','access_request',v_request_id,
    pg_catalog.jsonb_build_object('organization_id',v_organization_id,'job_id',v_job_id));
  return v_request_id;
end;
$$;
revoke all on function public.create_access_request(uuid,uuid,text,text[],integer) from public,anon,authenticated;
grant execute on function public.create_access_request(uuid,uuid,text,text[],integer) to service_role;
comment on function public.create_access_request(uuid,uuid,text,text[],integer) is
  'Service-only atomic consent request creation, live candidate visibility check, student notification, and minimized audit event.';
