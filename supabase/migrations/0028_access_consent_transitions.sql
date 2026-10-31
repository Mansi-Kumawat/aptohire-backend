-- Atomic student response and withdrawal for organization access requests.
create or replace function public.respond_access(
  p_student_id uuid,
  p_actor_id uuid,
  p_request_id uuid,
  p_decision text,
  p_granted_scope text[],
  p_duration_days int
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_request public.access_requests%rowtype;
  v_duration int;
  v_expires_at timestamptz;
begin
  if p_student_id is null or p_actor_id is null or p_request_id is null or p_decision is null
     or p_decision not in ('accept','decline') then
    raise exception 'invalid access response' using errcode='22023';
  end if;
  if not exists(select 1 from public.students s where s.id=p_student_id and s.user_id=p_actor_id) then
    raise exception 'student identity mismatch' using errcode='42501';
  end if;
  select r.* into v_request from public.access_requests r
   where r.id=p_request_id and r.student_id=p_student_id for update;
  if not found then raise exception 'access request not found' using errcode='P0002'; end if;
  if v_request.status<>'pending' then raise exception 'access request already answered' using errcode='40001'; end if;

  if p_decision='accept' then
    if p_granted_scope is null or cardinality(p_granted_scope)=0
       or exists(select 1 from pg_catalog.unnest(p_granted_scope) as u(scope) where u.scope not in ('profile','scorecard','projects','contact'))
       or pg_catalog.cardinality(p_granted_scope)<>(select pg_catalog.count(distinct u.scope)::int from pg_catalog.unnest(p_granted_scope) as u(scope))
       or not (p_granted_scope <@ v_request.requested_scope) then
      raise exception 'granted scopes must be a unique non-empty subset of requested scopes' using errcode='23514';
    end if;
    v_duration := coalesce(p_duration_days,v_request.duration_days);
    if v_duration is null or v_duration not in (7,30,90) or (v_request.duration_days is not null and v_duration>v_request.duration_days) then
      raise exception 'grant duration is invalid' using errcode='23514';
    end if;
    v_expires_at := pg_catalog.now()+pg_catalog.make_interval(days=>v_duration);
    update public.access_requests set status='accepted',granted_scope=p_granted_scope,
      duration_days=v_duration,expires_at=v_expires_at,responded_at=pg_catalog.now()
     where id=p_request_id;
  else
    v_expires_at := null;
    update public.access_requests set status='declined',granted_scope='{}'::text[],expires_at=null,responded_at=pg_catalog.now()
     where id=p_request_id;
  end if;

  insert into public.notifications(user_id,kind,payload)
  select om.user_id,case when p_decision='accept' then 'access_accepted' else 'access_declined' end,
    pg_catalog.jsonb_build_object('request_id',p_request_id,'status',case when p_decision='accept' then 'accepted' else 'declined' end)
  from public.organization_members om where om.organization_id=v_request.organization_id;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,case when p_decision='accept' then 'access_accepted' else 'access_declined' end,
    'access_request',p_request_id,pg_catalog.jsonb_build_object('granted_scope',case when p_decision='accept' then p_granted_scope else '{}'::text[] end,'duration_days',v_duration));
  return pg_catalog.jsonb_build_object('status',case when p_decision='accept' then 'accepted' else 'declined' end,'expires_at',v_expires_at);
end
$$;

create or replace function public.withdraw_access(
  p_student_id uuid,
  p_actor_id uuid,
  p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request public.access_requests%rowtype;
begin
  if p_student_id is null or p_actor_id is null or p_request_id is null then
    raise exception 'invalid access withdrawal' using errcode='22023';
  end if;
  if not exists(select 1 from public.students s where s.id=p_student_id and s.user_id=p_actor_id) then
    raise exception 'student identity mismatch' using errcode='42501';
  end if;
  select r.* into v_request from public.access_requests r
   where r.id=p_request_id and r.student_id=p_student_id for update;
  if not found then raise exception 'access request not found' using errcode='P0002'; end if;
  if v_request.status<>'accepted' or v_request.expires_at is null or v_request.expires_at<=pg_catalog.now() then
    raise exception 'active accepted request required' using errcode='40001';
  end if;
  update public.access_requests set status='withdrawn',granted_scope='{}'::text[],expires_at=pg_catalog.now(),responded_at=pg_catalog.now()
   where id=p_request_id;
  insert into public.notifications(user_id,kind,payload)
  select om.user_id,'access_withdrawn',pg_catalog.jsonb_build_object('request_id',p_request_id,'status','withdrawn')
    from public.organization_members om where om.organization_id=v_request.organization_id;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'access_withdrawn','access_request',p_request_id,
    pg_catalog.jsonb_build_object('granted_scope_revoked',v_request.granted_scope));
  return pg_catalog.jsonb_build_object('status','withdrawn');
end
$$;

revoke all on function public.respond_access(uuid,uuid,uuid,text,text[],int) from public,anon,authenticated;
revoke all on function public.withdraw_access(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.respond_access(uuid,uuid,uuid,text,text[],int) to service_role;
grant execute on function public.withdraw_access(uuid,uuid,uuid) to service_role;
comment on function public.respond_access(uuid,uuid,uuid,text,text[],int) is 'Atomically accepts or declines a pending student access request, writes identity-free organization notifications, and appends audit metadata.';
comment on function public.withdraw_access(uuid,uuid,uuid) is 'Atomically withdraws an active consent grant and notifies organization members without identity details.';
