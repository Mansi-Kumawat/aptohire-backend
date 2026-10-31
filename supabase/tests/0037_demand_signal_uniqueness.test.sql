begin;
select plan(2);
select ok(
  exists(
    select 1 from pg_catalog.pg_class i
    join pg_catalog.pg_namespace n on n.oid=i.relnamespace
    where n.nspname='public' and i.relname='demand_signals_job_university_uq'
  ),
  'one-job-per-university demand signal unique index exists'
);
select ok(
  exists(
    select 1 from pg_catalog.pg_index x
    join pg_catalog.pg_class i on i.oid=x.indexrelid
    join pg_catalog.pg_namespace n on n.oid=i.relnamespace
    where n.nspname='public' and i.relname='demand_signals_job_university_uq'
      and x.indisunique and x.indpred is not null
  ),
  'uniqueness applies only to non-null university aggregates'
);
select * from finish();
rollback;
