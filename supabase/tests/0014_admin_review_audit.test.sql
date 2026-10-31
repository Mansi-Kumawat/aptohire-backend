begin;
select plan(18);
insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('af000000-0000-4000-8000-000000000001','authenticated','authenticated','audit-review-admin@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('af000000-0000-4000-8000-000000000002','authenticated','authenticated','audit-review-student@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('af000000-0000-4000-8000-000000000003','authenticated','authenticated','audit-review-user@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
 ('af000000-0000-4000-8000-000000000001','admin'),
 ('af000000-0000-4000-8000-000000000002','student'),
 ('af000000-0000-4000-8000-000000000003','student');
insert into public.students(id,user_id,full_name,primary_email,visibility)
values('af000000-0000-4000-8000-000000000010','af000000-0000-4000-8000-000000000002','Fictional Reviewed Student','audit-review-student@demo.aptohire.test','{"discoverable":true,"public_verify":["skills","levels"],"university_files":false}');
insert into public.skill_families(id,slug,name) values('af000000-0000-4000-8000-000000000020','test-family','Fictional Family');
insert into public.skills(id,family_id,slug,name) values('af000000-0000-4000-8000-000000000021','af000000-0000-4000-8000-000000000020','test-skill','Fictional Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
values('af000000-0000-4000-8000-000000000030','af000000-0000-4000-8000-000000000010','Fictional Pending Project','needs_review',array['af000000-0000-4000-8000-000000000021'::uuid]),
      ('af000000-0000-4000-8000-000000000031','af000000-0000-4000-8000-000000000010','Fictional Adjusted Project','needs_review',array['af000000-0000-4000-8000-000000000021'::uuid]);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,rubric,review_status)
values
 ('af000000-0000-4000-8000-000000000040','af000000-0000-4000-8000-000000000030','test@1','audit@1',55,0.8,'[{"skill_id":"af000000-0000-4000-8000-000000000021","score":55}]'::jsonb,'pending'),
 ('af000000-0000-4000-8000-000000000041','af000000-0000-4000-8000-000000000031','test@1','audit@1',60,0.8,'[]'::jsonb,'pending');
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id)
values('af000000-0000-4000-8000-000000000010','af000000-0000-4000-8000-000000000021',55,'Competent',true,true,false,'af000000-0000-4000-8000-000000000040');
insert into public.app_config(key,value) values('PASS_MARK','50'::jsonb) on conflict(key) do update set value=excluded.value;

select has_function('public','admin_review_audit',array['uuid','uuid','text','jsonb','text'],'audit review RPC exists');
select ok(has_function_privilege('service_role','public.admin_review_audit(uuid,uuid,text,jsonb,text)','execute'),'service role can call audit review RPC');
select ok(not has_function_privilege('authenticated','public.admin_review_audit(uuid,uuid,text,jsonb,text)','execute'),'authenticated cannot call audit review RPC directly');
set local role service_role;
select is((select review_status from public.admin_review_audit('af000000-0000-4000-8000-000000000001','af000000-0000-4000-8000-000000000040','confirm',null,'Human confirmed the evidence.')),'complete','confirm resolves a pending audit');
select is((select reviewed_by from public.audits where id='af000000-0000-4000-8000-000000000040'),'af000000-0000-4000-8000-000000000001'::uuid,'reviewer is stored');
select is((select review_note from public.audits where id='af000000-0000-4000-8000-000000000040'),'Human confirmed the evidence.','review note is stored');
select ok((select verified and not pending_review and share_ok from public.skill_scores where student_id='af000000-0000-4000-8000-000000000010' and skill_id='af000000-0000-4000-8000-000000000021'),'human-confirmed above-pass score becomes shareable');
select is((select status from public.submissions where id='af000000-0000-4000-8000-000000000030'),'scored','submission returns to scored status');
select ok((select discoverable and skills @> '[{"name":"Fictional Skill","level":"Competent","score":55,"verified":true}]'::jsonb from public.candidate_profiles where student_id='af000000-0000-4000-8000-000000000010'),'candidate skills projection is refreshed without identity fields');
select ok(exists(select 1 from public.notifications where user_id='af000000-0000-4000-8000-000000000002' and kind='review_decided' and payload->>'audit_id'='af000000-0000-4000-8000-000000000040'),'student receives a review decision notification');
select ok(exists(select 1 from public.audit_log where actor_id='af000000-0000-4000-8000-000000000001' and action='admin_audit_reviewed' and target_id='af000000-0000-4000-8000-000000000040'),'human review is audited');
select is((select reviewed_score from public.admin_review_audit('af000000-0000-4000-8000-000000000001','af000000-0000-4000-8000-000000000041','adjust','[{"skill_id":"af000000-0000-4000-8000-000000000021","score":80}]'::jsonb,'Adjusted after reviewing tests.')),80::numeric,'adjust stores the human score');
select is((select score from public.skill_scores where student_id='af000000-0000-4000-8000-000000000010' and skill_id='af000000-0000-4000-8000-000000000021'),80::numeric,'adjusted skill score is applied');
select is((select level from public.skill_scores where student_id='af000000-0000-4000-8000-000000000010' and skill_id='af000000-0000-4000-8000-000000000021'),'Proficient','adjusted skill level is recomputed');
select ok(exists(select 1 from public.skill_score_history where student_id='af000000-0000-4000-8000-000000000010' and skill_id='af000000-0000-4000-8000-000000000021' and audit_id='af000000-0000-4000-8000-000000000041' and score=80),'adjusted score is appended to history');
select throws_ok($$select * from public.admin_review_audit('af000000-0000-4000-8000-000000000001','af000000-0000-4000-8000-000000000041','adjust','[]'::jsonb,'note')$$,'22023',null,'empty adjustment is rejected');
select throws_ok($$select * from public.admin_review_audit('af000000-0000-4000-8000-000000000003','af000000-0000-4000-8000-000000000041','confirm',null,'note')$$,'42501',null,'non-admin actor is rejected');
select throws_ok($$select * from public.admin_review_audit('af000000-0000-4000-8000-000000000001','af000000-0000-4000-8000-000000000040','confirm',null,'Repeated review')$$,'40001',null,'completed audit cannot be reviewed again');
reset role;
select * from finish();
rollback;
