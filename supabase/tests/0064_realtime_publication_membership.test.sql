begin;
select plan(3);

select is(
  coalesce((
    select array_agg(schemaname || '.' || tablename order by schemaname, tablename)
    from pg_publication_tables where pubname='supabase_realtime'
  ), '{}'::text[]),
  array['public.access_requests','public.agent_runs','public.notifications','public.submissions']::text[],
  'Realtime publication contains exactly the four approved tables'
);
select ok(not exists(
  select 1 from pg_publication_tables
  where pubname='supabase_realtime' and schemaname='public'
    and tablename in ('profiles','students','roster_entries','affiliations','universities','organizations','audit_log','skill_scores')
),'identity-bearing and internal tables are not published to Realtime');
select ok(not exists(
  select 1 from pg_publication_tables pt
  join pg_namespace n on n.nspname=pt.schemaname
  join pg_class c on c.relnamespace=n.oid and c.relname=pt.tablename
  where pt.pubname='supabase_realtime' and not c.relrowsecurity
),'every published base table has RLS enabled');

select * from finish();
rollback;
