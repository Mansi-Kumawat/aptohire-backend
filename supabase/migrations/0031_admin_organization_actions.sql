-- Approval and subscription actions for organizations are service-role-only and atomic.
create or replace function public.admin_organization_action(
  p_actor_id uuid,
  p_organization_id uuid,
  p_action text,
  p_value text,
  p_note text default null
)
returns table(organization_id uuid, status text, subscription_status text)
language plpgsql security definer set search_path = '' as $$
declare
  v_old_status text;
  v_old_subscription text;
  v_new_status text;
  v_new_subscription text;
  v_notification_kind text;
begin
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='admin') then
    raise exception using errcode='42501', message='admin role required';
  end if;
  if p_organization_id is null then raise exception using errcode='22023', message='organization id required'; end if;
  if p_action is null or p_action not in ('approve_org','set_subscription') then raise exception using errcode='22023', message='action is not allowed'; end if;
  if p_note is not null and length(p_note)>500 then raise exception using errcode='22023', message='note is too long'; end if;

  select o.status,o.subscription_status into v_old_status,v_old_subscription
    from public.organizations o where o.id=p_organization_id for update;
  if not found then raise exception using errcode='P0002', message='organization not found'; end if;
  v_new_status := v_old_status;
  v_new_subscription := v_old_subscription;

  if p_action='approve_org' then
    if p_value is null or p_value not in ('approve','reject') then raise exception using errcode='22023', message='decision is not allowed'; end if;
    v_new_status := case when p_value='approve' then 'approved' else 'rejected' end;
    update public.organizations o set status=v_new_status,
      verified_at=case when p_value='approve' then now() else null end,
      status_note=case when p_value='reject' then nullif(pg_catalog.btrim(p_note),'') else null end
    where o.id=p_organization_id;
    update public.applications a set status=case when p_value='approve' then 'approved'::public.application_status else 'rejected'::public.application_status end
     where a.type='organization' and a.subject_id=p_organization_id and a.status='received';
    v_notification_kind := 'application_decided';
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_actor_id,'admin_org_decided','organization',p_organization_id,jsonb_build_object('decision',p_value,'status',v_new_status));
  else
    if p_value is null or p_value not in ('active','inactive') then raise exception using errcode='22023', message='subscription status is not allowed'; end if;
    v_new_subscription := p_value;
    update public.organizations o set subscription_status=v_new_subscription where o.id=p_organization_id;
    v_notification_kind := 'subscription_changed';
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_actor_id,'admin_subscription_changed','organization',p_organization_id,jsonb_build_object('subscription_status',v_new_subscription));
  end if;

  insert into public.notifications(user_id,kind,payload)
  select om.user_id,v_notification_kind,
    case when p_action='approve_org'
      then jsonb_build_object('organization_id',p_organization_id,'status',v_new_status)
      else jsonb_build_object('organization_id',p_organization_id,'subscription_status',v_new_subscription)
    end
  from public.organization_members om where om.organization_id=p_organization_id;

  return query select p_organization_id,v_new_status,v_new_subscription;
end;
$$;
revoke all on function public.admin_organization_action(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.admin_organization_action(uuid,uuid,text,text,text) to service_role;
comment on function public.admin_organization_action(uuid,uuid,text,text,text) is 'Service-role-only atomic organization approval or subscription update; the Edge caller must pass aal2/private.is_admin() gating.';
