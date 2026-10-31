begin;
select plan(4);
select is((select value from public.app_config where key='MATCH_COVERAGE_FLOOR'),'0.25'::jsonb,'matching coverage floor is seeded as configurable data');
select is((select value from public.app_config where key='MATCH_LEVEL_FLOORS'),'{"Emerging":51,"Competent":51,"Proficient":70,"Advanced":85}'::jsonb,'level score floors are seeded as configurable data');
select ok(
  pg_get_functiondef('public.admin_update_config(uuid,text,jsonb)'::regprocedure) ilike '%MATCH_COVERAGE_FLOOR%'
  and pg_get_functiondef('public.admin_update_config(uuid,text,jsonb)'::regprocedure) ilike '%MATCH_LEVEL_FLOORS%'
  and pg_get_viewdef('public.admin_app_config_v'::regclass) ilike '%MATCH_LEVEL_FLOORS%',
  'admin config write validation and aal2 config view allowlist include matching thresholds'
);
select ok(
  has_function_privilege('service_role','public.admin_update_config(uuid,text,jsonb)','execute')
  and not has_function_privilege('authenticated','public.admin_update_config(uuid,text,jsonb)','execute'),
  'config write remains service-role-only'
);
select * from finish();
rollback;
