begin;
select plan(11);

select has_view('public','public_config','public_config view is part of the portal contract');
select has_column('public','public_config','key','public_config exposes only key/value pairs');
select has_column('public','public_config','value','public_config exposes JSON values');
select ok(has_table_privilege('authenticated','public.public_config','select'),'authenticated portals may read the public config allowlist');
select ok(not has_table_privilege('anon','public.public_config','select'),'anonymous callers cannot read public config');
select is((select count(*)::int from public.public_config),8,'public_config exposes exactly eight allowlisted keys when seeded');
select is((select value from public.public_config where key='BORDERLINE_LOW'),'40'::jsonb,'public config derives low threshold from the managed range');
select is((select value from public.public_config where key='BORDERLINE_HIGH'),'60'::jsonb,'public config derives high threshold from the managed range');
update public.app_config set value='[42,61]'::jsonb where key='BORDERLINE';
select is((select value from public.public_config where key='BORDERLINE_LOW'),'42'::jsonb,'public low bound follows an admin-managed range change without duplicated state');
select is((select value from public.public_config where key='BORDERLINE_HIGH'),'61'::jsonb,'public high bound follows an admin-managed range change without duplicated state');
select ok(not exists(select 1 from public.public_config where key in ('AGENT_MODE','BORDERLINE','SCORE_BLEND_N','GRANT_DURATIONS')),
  'public_config hides worker mode and internal settings');

select * from finish();
rollback;
