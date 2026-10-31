begin;
select plan(9);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('af440000-0000-4000-8000-000000000001','authenticated','authenticated','retry-admin@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
('af440000-0000-4000-8000-000000000002','authenticated','authenticated','retry-student@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('af440000-0000-4000-8000-000000000001','admin'),('af440000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email)
values('af440000-0000-4000-8000-000000000003','af440000-0000-4000-8000-000000000002','Synthetic Retry Student','retry-student@demo.aptohire.test');
insert into public.skill_families(id,slug,name) values('af440000-0000-4000-8000-000000000004','retry-test','Retry Test');
insert into public.skills(id,family_id,slug,name) values('af440000-0000-4000-8000-000000000005','af440000-0000-4000-8000-000000000004','retry-skill','Retry Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids) values('af440000-0000-4000-8000-000000000010','af440000-0000-4000-8000-000000000003','Synthetic Failed Run','failed',array['af440000-0000-4000-8000-000000000005'::uuid]);
insert into public.agent_runs(id,submission_id,user_id,stage,attempt,mode,status,error_code) values('af440000-0000-4000-8000-000000000020','af440000-0000-4000-8000-000000000010','af440000-0000-4000-8000-000000000002','done',1,'mock','failed','SYNTHETIC_FAILURE');
insert into public.app_config(key,value) values('AGENT_MODE','"mock"'::jsonb),('AI_KILL_SWITCH','false'::jsonb)
on conflict(key) do update set value=excluded.value;

select has_function('public','admin_retry_run',array['uuid','uuid'],'admin retry RPC exists');
select ok(has_function_privilege('service_role','public.admin_retry_run(uuid,uuid)','execute'),'service role can invoke retry RPC');
select ok(not has_function_privilege('authenticated','public.admin_retry_run(uuid,uuid)','execute'),'authenticated users cannot call retry RPC directly');
set local role service_role;
select is((select status from public.admin_retry_run('af440000-0000-4000-8000-000000000001','af440000-0000-4000-8000-000000000020')),'queued','retry creates a queued attempt');
select is((select mode from public.agent_runs where submission_id='af440000-0000-4000-8000-000000000010' and attempt=2),'mock','retry keeps the explicit demo mock mode');
select is((select cardinality(evidence_manifest) from public.agent_runs where submission_id='af440000-0000-4000-8000-000000000010' and attempt=2),0,'retry does not mislabel the submission record as evidence');
select is((select status from public.submissions where id='af440000-0000-4000-8000-000000000010'),'auditing','retry resumes the submission lifecycle');
select ok(exists(select 1 from public.audit_log where actor_id='af440000-0000-4000-8000-000000000001' and action='admin_retry_run' and target_id='af440000-0000-4000-8000-000000000020'),'admin retry is audit logged');
select throws_ok($$select * from public.admin_retry_run('af440000-0000-4000-8000-000000000001','af440000-0000-4000-8000-000000000020')$$,'40001',null,'retry cannot duplicate an already requeued submission');
reset role;
select * from finish();
rollback;
