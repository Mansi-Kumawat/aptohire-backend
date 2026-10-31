-- Lock down Data API access before creating application objects. Re-grant per object later.
create schema if not exists private;
revoke all on schema public from anon, authenticated;
revoke all on schema private from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from public, anon, authenticated;

comment on schema private is 'Internal only; not exposed through the Supabase Data API.';
