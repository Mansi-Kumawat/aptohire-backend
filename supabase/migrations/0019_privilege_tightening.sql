-- Tighten two broad grants from the initial scaffolding migrations.
revoke select on public.profile_sources from authenticated;
grant select (id,student_id,source_type,auto_approve,consented_at,revoked_at) on public.profile_sources to authenticated;
revoke select on public.roster_entries from authenticated;
grant select (id,university_id,email,program_level,year,status,created_at) on public.roster_entries to authenticated;

create or replace function private.reject_profile_role_change() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.role is distinct from old.role and coalesce(current_setting('request.jwt.claim.role',true),'') <> 'service_role' then raise exception 'role changes require privileged provisioning'; end if;
 return new;
end $$;
