begin;
select plan(4);

select ok(exists(
  select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid=t.typnamespace
  join pg_catalog.pg_enum e on e.enumtypid=t.oid
  where n.nspname='public' and t.typname='life_status' and e.enumlabel='incoming'
),'life_status contains incoming');
select ok(exists(
  select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid=t.typnamespace
  join pg_catalog.pg_enum e on e.enumtypid=t.oid
  where n.nspname='public' and t.typname='life_status' and e.enumlabel='enrolled'
),'life_status contains enrolled');
select matches((select pg_catalog.pg_get_expr(d.adbin,d.adrelid) from pg_catalog.pg_attrdef d
  join pg_catalog.pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum
  where d.adrelid='public.roster_entries'::regclass and a.attname='status'),'.*enrolled.*','roster entries default to enrolled');
select matches((select pg_catalog.pg_get_expr(d.adbin,d.adrelid) from pg_catalog.pg_attrdef d
  join pg_catalog.pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum
  where d.adrelid='public.affiliations'::regclass and a.attname='status'),'.*enrolled.*','affiliations default to enrolled');

select * from finish();
rollback;
