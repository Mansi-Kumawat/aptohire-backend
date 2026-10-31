begin;
select plan(2);
select has_column('public', 'access_requests', 'pipeline_stage', 'access_requests retains the pipeline stage column');
select ok(
  (select pg_get_constraintdef(oid) ilike '%reviewed%' from pg_constraint where conrelid = 'public.access_requests'::regclass and conname = 'access_requests_pipeline_stage_check'),
  'the accepted-candidate pipeline constraint allows the Reviewed stage'
);
select * from finish();
rollback;
