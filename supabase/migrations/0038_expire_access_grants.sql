-- Expire accepted consent grants in the database. Read paths also enforce expires_at,
-- so this hourly job is cleanup/notification and not the authorization boundary.
create or replace function public.expire_access_grants()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request record;
  v_user_id uuid;
  v_member record;
  v_count integer := 0;
begin
  for v_request in
    update public.access_requests r
       set status='expired', granted_scope='{}', responded_at=coalesce(r.responded_at,now())
     where r.status='accepted'
       and r.expires_at is not null
       and r.expires_at <= now()
    returning r.id,r.student_id,r.organization_id,r.job_id,r.expires_at
  loop
    select s.user_id into v_user_id from public.students s where s.id=v_request.student_id;
    if v_user_id is not null then
      insert into public.notifications(user_id,kind,payload)
      values(v_user_id,'access_expiring',jsonb_build_object('request_id',v_request.id,'status','expired'));
    end if;
    for v_member in
      select distinct m.user_id from public.organization_members m where m.organization_id=v_request.organization_id
    loop
      insert into public.notifications(user_id,kind,payload)
      values(v_member.user_id,'access_expiring',jsonb_build_object('request_id',v_request.id,'status','expired'));
    end loop;
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(null,'access_grant_expired','access_request',v_request.id,
      jsonb_build_object('organization_id',v_request.organization_id,'job_id',v_request.job_id));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.expire_access_grants() from public,anon,authenticated;
grant execute on function public.expire_access_grants() to service_role;
comment on function public.expire_access_grants() is 'Expires accepted consent grants atomically, clears granted scopes, notifies student and organization members with identity-free payloads, and appends an audit row.';

select cron.schedule('aptohire-expire-grants-hourly','0 * * * *',$cron$select public.expire_access_grants();$cron$);
