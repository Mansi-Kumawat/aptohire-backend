begin;
select plan(6);

select has_function('private','fail_stale_n8n_audit_runs',array['integer','integer'],'bounded private n8n timeout monitor exists');
select ok(not has_function_privilege('service_role','private.fail_stale_n8n_audit_runs(integer,integer)','execute'),
  'service role cannot execute timeout monitor directly');
insert into public.agent_runs(id,mode,status,started_at,created_at)
values
 ('00980000-0000-4000-8000-000000000001','n8n','running',now()-interval '9 minutes',now()-interval '9 minutes'),
 ('00980000-0000-4000-8000-000000000002','n8n','running',now()-interval '2 minutes',now()-interval '2 minutes'),
 ('00980000-0000-4000-8000-000000000003','direct','running',now()-interval '9 minutes',now()-interval '9 minutes');
select is(private.fail_stale_n8n_audit_runs(480,100),1,'only stale n8n runs are failed');
select is((select status from public.agent_runs where id='00980000-0000-4000-8000-000000000001'),'failed','stale n8n run becomes retryable failed state');
select is((select status from public.agent_runs where id='00980000-0000-4000-8000-000000000002'),'running','recent n8n run remains active');
select throws_ok($$select private.fail_stale_n8n_audit_runs(10,100)$$,'22023',null,'unsafe timeout bounds are rejected');

select * from finish();
rollback;
