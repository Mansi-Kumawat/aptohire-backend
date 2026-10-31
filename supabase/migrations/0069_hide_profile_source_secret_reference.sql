-- Vault tokens never reach the Data API: revoke table-wide SELECT and re-grant only safe metadata columns.
revoke all on public.profile_sources from public, anon, authenticated;
grant select (id, student_id, source_type, auto_approve, consented_at, revoked_at, last_synced_at)
  on public.profile_sources to authenticated;
comment on column public.profile_sources.token_secret_id is
  'Internal Vault secret reference; intentionally not selectable by anon or authenticated clients.';
