begin;
select plan(3);
select ok(
  not exists(
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private' and c.relkind in ('r','p') and not c.relrowsecurity
  ),
  'all private base tables enable row-level security'
);
select ok(
  not exists(
    select 1 from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','private') and has_function_privilege('anon',p.oid,'EXECUTE')
  ),
  'anon inherits no EXECUTE privilege on public or private functions'
);
select ok(
  has_function_privilege('authenticated','public.update_my_visibility(jsonb)','execute')
  and has_function_privilege('service_role','public.consume_rate_limit(text,text,integer,integer)','execute'),
  'explicit authenticated and service-role function grants survive the blanket PUBLIC/anon revoke'
);
select * from finish();
rollback;
