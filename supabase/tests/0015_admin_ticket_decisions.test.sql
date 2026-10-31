begin;
select plan(21);
insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('b0000000-0000-4000-8000-000000000001','authenticated','authenticated','ticket-original-admin@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('b0000000-0000-4000-8000-000000000002','authenticated','authenticated','ticket-appeal-admin@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('b0000000-0000-4000-8000-000000000003','authenticated','authenticated','ticket-student@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
 ('b0000000-0000-4000-8000-000000000001','admin'),
 ('b0000000-0000-4000-8000-000000000002','admin'),
 ('b0000000-0000-4000-8000-000000000003','student');
insert into public.students(id,user_id,full_name,primary_email,visibility)
values('b0000000-0000-4000-8000-000000000010','b0000000-0000-4000-8000-000000000003','Fictional Appeal Student','ticket-student@demo.aptohire.test','{"discoverable":true,"public_verify":["skills","levels"],"university_files":false}');
insert into public.skill_families(id,slug,name) values('b0000000-0000-4000-8000-000000000020','appeal-family','Fictional Appeal Family');
insert into public.skills(id,family_id,slug,name) values('b0000000-0000-4000-8000-000000000021','b0000000-0000-4000-8000-000000000020','appeal-skill','Fictional Appeal Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
values('b0000000-0000-4000-8000-000000000030','b0000000-0000-4000-8000-000000000010','Fictional Appealed Project','scored',array['b0000000-0000-4000-8000-000000000021'::uuid]);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,reviewed_score,confidence,rubric,review_status,reviewed_by)
values('b0000000-0000-4000-8000-000000000040','b0000000-0000-4000-8000-000000000030','appeal@1','audit@1',70,70,0.8,'[{"skill_id":"b0000000-0000-4000-8000-000000000021","score":70}]'::jsonb,'complete','b0000000-0000-4000-8000-000000000001');
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id)
values('b0000000-0000-4000-8000-000000000010','b0000000-0000-4000-8000-000000000021',70,'Proficient',true,false,true,'b0000000-0000-4000-8000-000000000040');
insert into public.app_config(key,value) values('PASS_MARK','50'::jsonb) on conflict(key) do update set value=excluded.value;

select has_column('public','tickets','original_reviewer_id','ticket preserves its original reviewer');
select ok(not has_column_privilege('authenticated','public.tickets','original_reviewer_id','select'),'student base-table read cannot reveal the internal reviewer id');
select ok(has_column_privilege('authenticated','public.tickets','id','select'),'authenticated retains the safe ticket identifiers it needs');
select has_function('public','admin_decide_ticket',array['uuid','uuid','text','uuid','text','text','text','jsonb'],'ticket action RPC exists');
select ok(has_function_privilege('service_role','public.admin_decide_ticket(uuid,uuid,text,uuid,text,text,text,jsonb)','execute'),'service role can call ticket RPC');
select ok(not has_function_privilege('authenticated','public.admin_decide_ticket(uuid,uuid,text,uuid,text,text,text,jsonb)','execute'),'authenticated cannot call ticket RPC directly');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b0000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
insert into public.tickets(submission_id,student_id,reason)
values('b0000000-0000-4000-8000-000000000030','b0000000-0000-4000-8000-000000000010','The score did not account for the demonstrated test coverage.');
select set_config('test.ticket_id',(select id::text from public.tickets where submission_id='b0000000-0000-4000-8000-000000000030'),true);
reset role;
select is((select original_reviewer_id from public.tickets where id=current_setting('test.ticket_id')::uuid),'b0000000-0000-4000-8000-000000000001'::uuid,'ticket captures original review author');
select is((select status from public.submissions where id='b0000000-0000-4000-8000-000000000030'),'appealed','ticket creation marks submission appealed');
select ok(exists(select 1 from public.notifications where user_id='b0000000-0000-4000-8000-000000000001' and kind='ticket_opened' and payload->>'ticket_id'=current_setting('test.ticket_id')),'admin receives ticket-opened notification');
select ok(not exists(select 1 from public.notifications where kind='ticket_opened' and payload ?| array['student_id','email','full_name']),'ticket notification omits student identity');

set local role service_role;
select is((select status from public.admin_decide_ticket('b0000000-0000-4000-8000-000000000002',current_setting('test.ticket_id')::uuid,'ack',null,null,null,null,null)),'assigned','acknowledgement assigns ticket to current admin');
select throws_ok($$select * from public.admin_decide_ticket('b0000000-0000-4000-8000-000000000001',current_setting('test.ticket_id')::uuid,'decide',null,'upheld',null,null,null)$$,'42501',null,'original reviewer cannot decide own appeal');
select is((select decision from public.admin_decide_ticket('b0000000-0000-4000-8000-000000000002',current_setting('test.ticket_id')::uuid,'decide',null,'adjusted','testing','Adjusted after a second review.','[{"skill_id":"b0000000-0000-4000-8000-000000000021","score":82}]'::jsonb)),'adjusted','second reviewer can adjust a ticket with new scores');
select is((select status from public.tickets where id=current_setting('test.ticket_id')::uuid),'closed','decided ticket is closed');
select is((select original_reviewer_id from public.tickets where id=current_setting('test.ticket_id')::uuid),'b0000000-0000-4000-8000-000000000001'::uuid,'original reviewer remains stable after appeal review');
select is((select reviewed_by from public.audits where id='b0000000-0000-4000-8000-000000000040'),'b0000000-0000-4000-8000-000000000002'::uuid,'appeal reviewer is recorded separately');
select is((select status from public.submissions where id='b0000000-0000-4000-8000-000000000030'),'scored','adjusted appeal restores scored status');
select is((select score from public.skill_scores where student_id='b0000000-0000-4000-8000-000000000010' and skill_id='b0000000-0000-4000-8000-000000000021'),82::numeric,'adjusted ticket score is applied');
select ok(exists(select 1 from public.rubric_feedback_log where ticket_id=current_setting('test.ticket_id')::uuid and criterion='testing' and outcome='adjusted'),'rubric feedback captures criterion and outcome');
select ok(exists(select 1 from public.notifications where user_id='b0000000-0000-4000-8000-000000000003' and kind='appeal_update' and payload->>'decision'='adjusted'),'student receives appeal update');
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b0000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
select is((select original_reviewer_id from public.admin_tickets_v where id=current_setting('test.ticket_id')::uuid),'b0000000-0000-4000-8000-000000000001'::uuid,'admin view exposes preserved original reviewer only to aal2 admin');
reset role;
select * from finish();
rollback;
