-- A signed n8n ACK does not guarantee a callback. Fail stale jobs visibly so
-- the student can use the existing retry path; never silently switch providers.
create or replace function private.fail_stale_n8n_audit_runs(
  p_timeout_seconds integer default 480,
  p_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  if p_timeout_seconds < 60 or p_timeout_seconds > 3600 or p_limit < 1 or p_limit > 500 then
    raise exception using errcode='22023', message='invalid n8n timeout monitor bounds';
  end if;

  with candidates as (
    select r.id
      from public.agent_runs r
     where r.mode='n8n' and r.status='running'
       and r.started_at is not null
       and r.started_at <= now() - make_interval(secs => p_timeout_seconds)
     order by r.started_at, r.id
     for update skip locked
     limit p_limit
  ), failed_runs as (
    update public.agent_runs r
       set status='failed', error_code='N8N_CALLBACK_TIMEOUT', finished_at=now(),
           latency_ms=coalesce(r.latency_ms,greatest(0,floor(extract(epoch from(now()-coalesce(r.started_at,r.created_at)))*1000)::integer))
      from candidates c
     where r.id=c.id and r.status='running' and r.mode='n8n'
     returning r.id, r.submission_id
  ), failed_submissions as (
    update public.submissions s
       set status='failed', updated_at=now()
      from failed_runs r
     where s.id=r.submission_id and s.status='auditing'
     returning s.id
  )
  select count(*)::integer into v_count from failed_runs;

  return v_count;
end;
$$;
revoke all on function private.fail_stale_n8n_audit_runs(integer,integer) from public, anon, authenticated, service_role;
comment on function private.fail_stale_n8n_audit_runs(integer,integer) is
  'Fails only stale running n8n audit jobs after a bounded callback window; leaves runs retryable and records a safe error code.';

select cron.schedule(
  'aptohire-n8n-audit-timeout-monitor',
  '* * * * *',
  $cron$select private.fail_stale_n8n_audit_runs(480,100);$cron$
);
