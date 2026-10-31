create table private.access_expiry_notices (
  request_id uuid primary key references public.access_requests(id) on delete cascade,
  notified_at timestamptz not null default now()
);
revoke all on private.access_expiry_notices from public,anon,authenticated;
grant select,insert on private.access_expiry_notices to service_role;

create or replace function public.notify_access_expiring()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_request record;
  v_user_id uuid;
  v_member record;
  v_count integer := 0;
begin
  for v_request in
    select r.id,r.student_id,r.organization_id,r.job_id,r.expires_at
      from public.access_requests r
     where r.status='accepted' and r.expires_at>now() and r.expires_at<=now()+interval '3 days'
       and not exists(select 1 from private.access_expiry_notices n where n.request_id=r.id)
     order by r.expires_at for update skip locked
  loop
    insert into private.access_expiry_notices(request_id) values(v_request.id) on conflict do nothing;
    if not found then continue; end if;
    select s.user_id into v_user_id from public.students s where s.id=v_request.student_id;
    if v_user_id is not null then
      insert into public.notifications(user_id,kind,payload)
      values(v_user_id,'access_expiring',jsonb_build_object('request_id',v_request.id,'status','expiring','expires_at',v_request.expires_at));
    end if;
    for v_member in
      select distinct m.user_id from public.organization_members m where m.organization_id=v_request.organization_id
    loop
      insert into public.notifications(user_id,kind,payload)
      values(v_member.user_id,'access_expiring',jsonb_build_object('request_id',v_request.id,'status','expiring','expires_at',v_request.expires_at));
    end loop;
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(null,'access_grant_expiring','access_request',v_request.id,jsonb_build_object('organization_id',v_request.organization_id,'job_id',v_request.job_id));
    v_count:=v_count+1;
  end loop;
  return v_count;
end; $$;
revoke all on function public.notify_access_expiring() from public,anon,authenticated;
grant execute on function public.notify_access_expiring() to service_role;
select cron.schedule('aptohire-notify-access-expiring-daily','0 8 * * *',$cron$select public.notify_access_expiring();$cron$);
comment on function public.notify_access_expiring() is 'Idempotently notifies student and organization users when an accepted access grant will expire within three days; organization payload contains request/status/expiry only.';
