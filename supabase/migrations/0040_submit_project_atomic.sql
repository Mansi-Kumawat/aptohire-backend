-- Atomically freezes an owned submission and creates its first/retry agent run.
create or replace function public.submit_project(p_actor_id uuid,p_submission_id uuid,p_mode text)
returns table(run_id uuid,submission_id uuid,status text,mode text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_submission public.submissions%rowtype;
  v_run_id uuid;
  v_attempt int;
  v_config_mode text;
  v_kill_switch boolean;
begin
  if p_actor_id is null or p_submission_id is null then
    raise exception using errcode='22023', message='invalid submission request';
  end if;
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='student') then
    raise exception using errcode='42501', message='student role required';
  end if;
  select s.id into v_student_id from public.students s where s.user_id=p_actor_id for update;
  if not found then raise exception using errcode='42501', message='student profile required'; end if;
  select s.* into v_submission from public.submissions s
   where s.id=p_submission_id and s.student_id=v_student_id for update;
  if not found then raise exception using errcode='P0002', message='submission not found'; end if;
  if v_submission.status not in ('draft','failed') then
    raise exception using errcode='40001', message='submission is not retryable';
  end if;
  if coalesce(cardinality(v_submission.claimed_skill_ids),0)<1 then
    raise exception using errcode='23514', message='at least one claimed skill is required';
  end if;
  if p_mode not in ('mock','direct','n8n') then
    raise exception using errcode='22023', message='invalid agent mode';
  end if;
  select c.value#>>'{}' into v_config_mode from public.app_config c where c.key='AGENT_MODE';
  select coalesce((c.value#>>'{}')::boolean,false) into v_kill_switch from public.app_config c where c.key='AI_KILL_SWITCH';
  if v_config_mode is null or v_kill_switch is null then
    raise exception using errcode='55000', message='submission configuration is missing';
  end if;
  if v_kill_switch then raise exception using errcode='55000', message='agent processing is paused'; end if;
  if v_config_mode is distinct from p_mode then
    raise exception using errcode='40001', message='agent mode changed; retry request';
  end if;
  select coalesce(max(r.attempt),0)+1 into v_attempt from public.agent_runs r where r.submission_id=p_submission_id;
  update public.submissions s set status='auditing',updated_at=now() where s.id=p_submission_id;
  insert into public.agent_runs(submission_id,user_id,stage,attempt,mode,status)
  values(p_submission_id,p_actor_id,'received',v_attempt,p_mode,'queued')
  returning id into v_run_id;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'student_project_submitted','submission',p_submission_id,
    jsonb_build_object('run_id',v_run_id,'mode',p_mode,'attempt',v_attempt));
  return query select v_run_id,p_submission_id,'queued'::text,p_mode;
end;
$$;
revoke all on function public.submit_project(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.submit_project(uuid,uuid,text) to service_role;
comment on function public.submit_project(uuid,uuid,text) is
  'Service-role-only atomic transition for an authenticated student-owned draft/retry; locks the submission, enforces config mode/kill switch, creates the run, and audits the submission.';
