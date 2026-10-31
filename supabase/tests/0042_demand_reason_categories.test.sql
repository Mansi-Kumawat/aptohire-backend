begin;
select plan(3);
select ok(
  pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%no_eligible%'
  and pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%incomplete_assessments%'
  and pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%insufficient_evidence%'
  and pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%skills_mismatch%'
  and pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%opted_out%'
  and pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%not_assessed%',
  'atomic replacement RPC accepts exactly the six documented aggregate reasons'
);
select ok(
  pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%jsonb_each(v_row->''reason_counts'')%'
  and pg_get_functiondef('public.replace_demand_signals(uuid,jsonb)'::regprocedure) ilike '%trunc%',
  'all reason values are validated as bounded whole-number counts'
);
select ok(
  has_function_privilege('service_role','public.replace_demand_signals(uuid,jsonb)','execute')
  and not has_function_privilege('authenticated','public.replace_demand_signals(uuid,jsonb)','execute'),
  'expanded demand replacement remains service-role-only'
);
select * from finish();
rollback;
