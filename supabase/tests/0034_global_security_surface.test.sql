begin;
select plan(6);

-- Every base table in exposed/internal application schemas must enforce RLS.
select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private')
      and c.relkind in ('r','p')
      and not c.relrowsecurity
  ),
  'all public/private base tables have row-level security enabled'
);

-- The anonymous role must not read or write any table, view, materialized view, or partition.
select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private')
      and c.relkind in ('r','p','v','m')
      and (
        has_table_privilege('anon',c.oid,'SELECT')
        or has_table_privilege('anon',c.oid,'INSERT')
        or has_table_privilege('anon',c.oid,'UPDATE')
        or has_table_privilege('anon',c.oid,'DELETE')
        or has_table_privilege('anon',c.oid,'TRUNCATE')
        or has_table_privilege('anon',c.oid,'REFERENCES')
        or has_table_privilege('anon',c.oid,'TRIGGER')
      )
  ),
  'anon has no table/view privileges in public or private'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private'
      and c.relkind in ('r','p','v','m')
      and (
        has_table_privilege('authenticated',c.oid,'SELECT')
        or has_table_privilege('authenticated',c.oid,'INSERT')
        or has_table_privilege('authenticated',c.oid,'UPDATE')
        or has_table_privilege('authenticated',c.oid,'DELETE')
        or has_table_privilege('authenticated',c.oid,'TRUNCATE')
        or has_table_privilege('authenticated',c.oid,'REFERENCES')
        or has_table_privilege('authenticated',c.oid,'TRIGGER')
      )
  ),
  'authenticated has no direct table/view privileges in private'
);

-- Explicit function grants are required: anonymous callers must not inherit EXECUTE on RPCs.
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private')
      and has_function_privilege('anon',p.oid,'EXECUTE')
  ),
  'anon cannot execute public/private functions or RPCs'
);

-- SECURITY DEFINER must never inherit a caller-controlled search_path.
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private')
      and p.prosecdef
      and not coalesce(p.proconfig,'{}'::text[]) @> array['search_path=""']::text[]
  ),
  'all SECURITY DEFINER functions set an empty search_path'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private')
      and c.relkind='v'
      and pg_catalog.pg_get_viewdef(c.oid,true) ~* '(^|[[:space:]])select[[:space:]]+[*]([[:space:]]|$)'
  ),
  'public/private views do not use SELECT *'
);

select * from finish();
rollback;
