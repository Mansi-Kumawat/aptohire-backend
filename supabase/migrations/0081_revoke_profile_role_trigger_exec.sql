-- Trigger-only SECURITY DEFINER helper inherited PUBLIC execution from the original migration.
-- Trigger invocation does not require callers to execute the trigger function directly.
revoke all on function private.reject_profile_role_change() from public,anon,authenticated,service_role;
comment on function private.reject_profile_role_change() is
  'Trigger-only role immutability guard; direct execution is revoked from client and service roles.';
