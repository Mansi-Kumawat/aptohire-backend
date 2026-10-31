-- Replace the pg_cron no-op with a PII-free heartbeat row and bounded retention.
create table if not exists private.maintenance_heartbeat (
  id uuid primary key default gen_random_uuid(),
  task_name text not null check (task_name in ('keep-alive')),
  executed_at timestamptz not null default now()
);
alter table private.maintenance_heartbeat enable row level security;
revoke all on private.maintenance_heartbeat from public,anon,authenticated,service_role;

create or replace function public.keep_alive()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_time timestamptz := now();
begin
  insert into private.maintenance_heartbeat(task_name,executed_at) values('keep-alive',v_time);
  delete from private.maintenance_heartbeat where executed_at < v_time-interval '90 days';
  return v_time;
end;
$$;
revoke all on function public.keep_alive() from public,anon,authenticated;
grant execute on function public.keep_alive() to service_role;
comment on function public.keep_alive() is 'Service-only daily database heartbeat with a private 90-day PII-free run log.';

select cron.unschedule(jobid) from cron.job where jobname='aptohire-keep-alive-daily';
select cron.schedule('aptohire-keep-alive-daily','0 9 * * *',$cron$select public.keep_alive();$cron$);
