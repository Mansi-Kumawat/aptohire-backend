-- Reassert the service-only signup role initializer for hosted demo projects.
-- This is idempotent and does not change existing profiles or grant client access.
create or replace function public.set_profile_role_once(p_user_id uuid,p_role text)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
begin
  if p_user_id is null or p_role not in ('student','university','organization') then
    raise exception 'invalid signup role';
  end if;
  insert into public.profiles(id,role) values(p_user_id,null)
  on conflict(id) do nothing;
  update public.profiles set role=p_role
   where id=p_user_id and role is null;
  select role into v_role from public.profiles where id=p_user_id;
  if v_role is distinct from p_role then
    raise exception 'role already set' using errcode='23505';
  end if;
  return v_role;
end;
$function$;
revoke all on function public.set_profile_role_once(uuid,text) from public,anon,authenticated;
grant execute on function public.set_profile_role_once(uuid,text) to service_role;
comment on function public.set_profile_role_once(uuid,text) is
  'Atomically initializes a non-admin profile role once; callable only by the service role.';
notify pgrst, 'reload schema';
