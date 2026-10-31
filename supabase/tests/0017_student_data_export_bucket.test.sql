begin;
select plan(3);
select ok(exists(
  select 1 from storage.buckets
  where id='data-exports' and name='data-exports' and public=false
    and file_size_limit=20971520 and allowed_mime_types @> array['application/json']
),'data export bucket is private, JSON-only, and size-limited');
select ok((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='storage' and c.relname='objects'),'storage object RLS is enabled');
select ok(not exists(
  select 1 from pg_policies p where p.schemaname='storage' and p.tablename='objects'
    and (coalesce(p.qual,'')||coalesce(p.with_check,'')) ilike '%data-exports%'
),'no authenticated or anonymous storage policy grants access to export objects');
select * from finish();
rollback;
