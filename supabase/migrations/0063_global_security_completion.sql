-- Close the two global-security gaps found by the first full local pgTAP run.
-- Private operational tables remain inaccessible through client roles and now
-- have RLS enabled as defense in depth. Existing authenticated/service_role
-- grants on public RPCs are intentionally preserved.
alter table private.rate_limits enable row level security;
alter table private.idempotency_keys enable row level security;
alter table private.github_oauth_states enable row level security;
alter table private.access_expiry_notices enable row level security;

-- The private schema was created without a default-function ACL override in 0000.
-- Revoke inherited PUBLIC/anon execution now, and protect future functions in both
-- API schemas. Explicit grants to authenticated and service_role remain intact.
revoke execute on all functions in schema public, private from public, anon;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges in schema private revoke execute on functions from public, anon, authenticated;

comment on schema private is 'Internal-only schema; client roles have no direct object privileges and private tables enforce RLS.';
