-- Claim an exact, verified-email application and attach its pending subject member
-- in one transaction; `claimed_user_id` is the durable idempotency marker.
create or replace function public.claim_signup_application(
  p_application_id uuid,
  p_user_id uuid,
  p_portal text,
  p_verified_email text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_application public.applications%rowtype;
  v_auth_email text;
  v_subject_id uuid;
  v_subject_status text;
begin
  if p_application_id is null or p_user_id is null or p_portal is null or p_portal not in ('university','organization')
     or nullif(pg_catalog.btrim(p_verified_email),'') is null then
    return false;
  end if;
  select u.email into v_auth_email from auth.users u
   where u.id=p_user_id and u.email_confirmed_at is not null;
  if not found or v_auth_email is null or pg_catalog.lower(v_auth_email)<>pg_catalog.lower(pg_catalog.btrim(p_verified_email)) then
    return false;
  end if;
  -- Follow the approval RPC lock order (subject first, application second) to avoid
  -- deadlocks with an administrator approving this subject at the same time.
  select a.subject_id into v_subject_id from public.applications a
   where a.id=p_application_id and a.type=p_portal;
  if not found or v_subject_id is null then return false; end if;
  if p_portal='university' then
    select u.status into v_subject_status from public.universities u where u.id=v_subject_id for update;
  else
    select o.status into v_subject_status from public.organizations o where o.id=v_subject_id for update;
  end if;
  if not found or v_subject_status is distinct from 'pending' then return false; end if;

  select a.* into v_application from public.applications a where a.id=p_application_id for update;
  if not found or v_application.type is distinct from p_portal or v_application.status is distinct from 'received'
     or v_application.subject_id is distinct from v_subject_id
     or pg_catalog.lower(v_application.contact_email::text)<>pg_catalog.lower(v_auth_email) then
    return false;
  end if;
  if v_application.claimed_user_id is not null and v_application.claimed_user_id<>p_user_id then
    return false;
  end if;
  update public.applications set claimed_user_id=p_user_id where id=p_application_id and (claimed_user_id is null or claimed_user_id=p_user_id);
  if not found then return false; end if;
  if p_portal='university' then
    insert into public.university_members(university_id,user_id,member_role)
    values(v_subject_id,p_user_id,'applicant') on conflict(university_id,user_id) do nothing;
  else
    insert into public.organization_members(organization_id,user_id,member_role)
    values(v_subject_id,p_user_id,'applicant') on conflict(organization_id,user_id) do nothing;
  end if;
  return true;
end;
$$;
revoke all on function public.claim_signup_application(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.claim_signup_application(uuid,uuid,text,text) to service_role;
comment on function public.claim_signup_application(uuid,uuid,text,text) is
  'Atomically attaches a verified-email user to the single matching pending university or organization application; repeated claims by the same user are idempotent.';
