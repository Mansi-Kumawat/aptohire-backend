begin;
select plan(9);

select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind in ('r','p') and not c.relrowsecurity),
  0,
  'every public and private base table enables row-level security'
);
select is(
  (select count(*)::int
     from pg_policies p
     join pg_class c on c.relname=p.tablename
     join pg_namespace n on n.oid=c.relnamespace and n.nspname=p.schemaname
    where not c.relrowsecurity),
  0,
  'every relation with a policy has RLS enabled'
);
select ok(
  (select count(*) > 0 from pg_policies where schemaname='public')
  and exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
               where n.nspname='private' and c.relkind in ('r','p') and c.relrowsecurity),
  'public policies and RLS-protected private operational tables are present'
);
select ok(
  (select relrowsecurity from pg_class where oid='storage.objects'::regclass),
  'Storage object metadata has row-level security enabled'
);
select ok(
  not has_schema_privilege('anon','private','usage')
  and not has_table_privilege('anon','public.students','select')
  and not has_table_privilege('anon','public.app_config','select')
  and not has_table_privilege('anon','private.rate_limits','select')
  and not has_table_privilege('authenticated','private.rate_limits','select'),
  'anon cannot use the private schema or read internal identity/config/rate-limit tables; authenticated cannot read rate limits'
);

select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private')
      and c.relkind in ('r','p','v','m','f')
      and (
        has_table_privilege('anon',c.oid,'SELECT') or
        has_table_privilege('anon',c.oid,'INSERT') or
        has_table_privilege('anon',c.oid,'UPDATE') or
        has_table_privilege('anon',c.oid,'DELETE') or
        has_table_privilege('anon',c.oid,'TRUNCATE') or
        has_table_privilege('anon',c.oid,'REFERENCES') or
        has_table_privilege('anon',c.oid,'TRIGGER') or
        has_any_column_privilege('anon',c.oid,'SELECT') or
        has_any_column_privilege('anon',c.oid,'INSERT') or
        has_any_column_privilege('anon',c.oid,'UPDATE') or
        has_any_column_privilege('anon',c.oid,'REFERENCES')
      )),
  0,
  'anon has no table, view, foreign-table, or column privileges in exposed/internal schemas'
);
select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind='S'
      and (has_sequence_privilege('anon',c.oid,'USAGE')
        or has_sequence_privilege('anon',c.oid,'SELECT')
        or has_sequence_privilege('anon',c.oid,'UPDATE'))),
  0,
  'anon has no sequence privileges in exposed or internal schemas'
);
select is(
  (select count(*)::int from pg_policies where schemaname in ('public','private','storage') and ('anon'::name=any(roles) or 'public'::name=any(roles))),
  0,
  'no RLS policy directly targets anon or PUBLIC'
);
select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private' and c.relkind in ('r','p')
      and (has_table_privilege('anon',c.oid,'SELECT') or has_table_privilege('anon',c.oid,'INSERT')
        or has_table_privilege('anon',c.oid,'UPDATE') or has_table_privilege('anon',c.oid,'DELETE')
        or has_table_privilege('authenticated',c.oid,'SELECT') or has_table_privilege('authenticated',c.oid,'INSERT')
        or has_table_privilege('authenticated',c.oid,'UPDATE') or has_table_privilege('authenticated',c.oid,'DELETE'))),
  0,
  'browser roles have no direct CRUD privileges on private operational tables'
);

select * from finish();
rollback;
