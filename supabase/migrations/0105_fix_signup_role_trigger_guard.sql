-- The role initializer is SECURITY DEFINER. Inside its trigger, current_user is
-- the function owner (usually postgres), not the caller's service_role JWT.
-- Check the verified PostgREST JWT role claim instead so service-only signup
-- provisioning can set a role while authenticated clients still cannot.
create or replace function private.reject_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.role is distinct from old.role
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'role changes require privileged provisioning';
  end if;
  return new;
end;
$function$;
revoke all on function private.reject_profile_role_change() from public, anon, authenticated;
notify pgrst, 'reload schema';
