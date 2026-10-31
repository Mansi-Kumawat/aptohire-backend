-- A submission UUID is metadata, not evidence; retries start with an empty evidence manifest.
create or replace function public.admin_retry_run(p_actor_id uuid,p_failed_run_id uuid)
returns table(run_id uuid,status text,mode text)
language plpgsql security definer set search_path = '' as $$
declare
  v_old public.agent_runs%rowtype;
  v_submission public.submissions%rowtype;
  v_mode text;
  v_kill_switch boolean;
  v_email text;
  v_attempt int;
  v_new_run_id uuid;
begin
  if p_actor_id is null or p_failed_run_id is null then raise exception using errcode='22023',message='invalid retry request'; end if;
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='admin') then
    raise exception using errcode='42501',message='admin role required';
  end if;
  select * into v_old from public.agent_runs r where r.id=p_failed_run_id for update;
  if not found or v_old.status is distinct from 'failed' or v_old.submission_id is null or v_old.user_id is null then
    raise exception using errcode='40001',message='run is not retryable';
  end if;
  select * into v_submission from public.submissions s where s.id=v_old.submission_id for update;
  if not found or v_submission.status is distinct from 'failed' then
    raise exception using errcode='40001',message='submission is not retryable';
  end if;
  if coalesce(cardinality(v_submission.claimed_skill_ids),0)<1 then raise exception using errcode='23514',message='submission has no claimed skills'; end if;
  select lower(u.email) into v_email from auth.users u where u.id=v_old.user_id;
  if v_email is null or v_email not like '%.test' then raise exception using errcode='42501',message='mock retries restricted to fictional demo users'; end if;
  select c.value#>>'{}' into v_mode from public.app_config c where c.key='AGENT_MODE';
  select coalesce((c.value#>>'{}')::boolean,true) into v_kill_switch from public.app_config c where c.key='AI_KILL_SWITCH';
  if v_mode is distinct from 'mock' then raise exception using errcode='55000',message='only the implemented mock provider can be retried'; end if;
  if v_kill_switch then raise exception using errcode='55000',message='agent processing is paused'; end if;
  select coalesce(max(r.attempt),0)+1 into v_attempt from public.agent_runs r where r.submission_id=v_submission.id;
  update public.submissions set status='auditing',updated_at=now() where id=v_submission.id;
  insert into public.agent_runs(submission_id,user_id,stage,attempt,mode,status,evidence_manifest)
  values(v_submission.id,v_old.user_id,'received',v_attempt,'mock','queued','{}'::text[])
  returning id into v_new_run_id;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'admin_retry_run','agent_run',p_failed_run_id,jsonb_build_object('new_run_id',v_new_run_id,'attempt',v_attempt));
  return query select v_new_run_id,'queued'::text,'mock'::text;
end; $$;
revoke all on function public.admin_retry_run(uuid,uuid) from public,anon,authenticated;
grant execute on function public.admin_retry_run(uuid,uuid) to service_role;
comment on function public.admin_retry_run(uuid,uuid) is 'Aal2-gated at the Edge Function; RPC permits only failed synthetic .test mock runs, queues an empty evidence manifest, and atomically records a new attempt.';
