begin;
select plan(14);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('af400000-0000-4000-8000-000000000001','authenticated','authenticated','submit-student@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
       ('af400000-0000-4000-8000-000000000002','authenticated','authenticated','submit-other@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
 ('af400000-0000-4000-8000-000000000001','student'),
 ('af400000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
 ('af400000-0000-4000-8000-000000000010','af400000-0000-4000-8000-000000000001','Fictional Submit Student','submit-student@demo.aptohire.test'),
 ('af400000-0000-4000-8000-000000000011','af400000-0000-4000-8000-000000000002','Fictional Other Student','submit-other@demo.aptohire.test');
insert into public.skill_families(id,slug,name) values ('af400000-0000-4000-8000-000000000020','submit-test','Submit Test');
insert into public.skills(id,family_id,slug,name) values ('af400000-0000-4000-8000-000000000021','af400000-0000-4000-8000-000000000020','submit-test-skill','Submit Test Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids) values
 ('af400000-0000-4000-8000-000000000030','af400000-0000-4000-8000-000000000010','Fictional Draft','draft',array['af400000-0000-4000-8000-000000000021'::uuid]),
 ('af400000-0000-4000-8000-000000000031','af400000-0000-4000-8000-000000000010','Fictional Retry','failed',array['af400000-0000-4000-8000-000000000021'::uuid]),
 ('af400000-0000-4000-8000-000000000032','af400000-0000-4000-8000-000000000010','Fictional No Skills','draft','{}'::uuid[]),
 ('af400000-0000-4000-8000-000000000033','af400000-0000-4000-8000-000000000011','Fictional Foreign Draft','draft',array['af400000-0000-4000-8000-000000000021'::uuid]),
 ('af400000-0000-4000-8000-000000000034','af400000-0000-4000-8000-000000000010','Fictional Config Draft','draft',array['af400000-0000-4000-8000-000000000021'::uuid]);
insert into public.agent_runs(id,submission_id,user_id,stage,attempt,mode,status,error_code)
values ('af400000-0000-4000-8000-000000000035','af400000-0000-4000-8000-000000000031','af400000-0000-4000-8000-000000000001','done',1,'mock','failed','SYNTHETIC_FAILURE');
insert into public.app_config(key,value) values
 ('AGENT_MODE','"mock"'::jsonb),('AI_KILL_SWITCH','false'::jsonb)
on conflict(key) do update set value=excluded.value;

select has_function('public','submit_project',array['uuid','uuid','text'],'atomic submit RPC exists');
select ok(has_function_privilege('service_role','public.submit_project(uuid,uuid,text)','execute'),'service role can invoke submit RPC');
select ok(not has_function_privilege('authenticated','public.submit_project(uuid,uuid,text)','execute'),'authenticated cannot invoke submit RPC directly');
set local role service_role;
select is((select mode from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000030','mock')),'mock','draft submission queues in configured mode');
select is((select status from public.submissions where id='af400000-0000-4000-8000-000000000030'),'auditing','owned draft is frozen for audit');
select ok(exists(select 1 from public.agent_runs where submission_id='af400000-0000-4000-8000-000000000030' and user_id='af400000-0000-4000-8000-000000000001' and stage='received' and attempt=1 and mode='mock' and status='queued'),'first run is created in received/queued state');
select ok(exists(select 1 from public.audit_log where actor_id='af400000-0000-4000-8000-000000000001' and action='student_project_submitted' and target_id='af400000-0000-4000-8000-000000000030'),'submission is audited');
select throws_ok($$select * from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000030','mock')$$,'40001',null,'already auditing submission cannot be queued twice');
select is((select mode from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000031','mock')),'mock','failed submission can be retried');
select is((select max(attempt) from public.agent_runs where submission_id='af400000-0000-4000-8000-000000000031'),2,'retry run increments attempt');
select throws_ok($$select * from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000032','mock')$$,'23514',null,'submission without claimed skills is rejected');
select throws_ok($$select * from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000033','mock')$$,'P0002',null,'another student submission is not found');
select throws_ok($$select * from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000034','direct')$$,'40001',null,'configured agent mode cannot be overridden');
update public.app_config set value='true'::jsonb where key='AI_KILL_SWITCH';
select throws_ok($$select * from public.submit_project('af400000-0000-4000-8000-000000000001','af400000-0000-4000-8000-000000000034','mock')$$,'55000',null,'kill switch prevents queueing');
reset role;
select * from finish();
rollback;
