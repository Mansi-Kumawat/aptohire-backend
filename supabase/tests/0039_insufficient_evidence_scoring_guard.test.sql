begin;
select plan(6);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('e0540000-0000-4000-8000-000000000001','authenticated','authenticated','no-evidence@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('e0540000-0000-4000-8000-000000000001','student');
insert into public.students(id,user_id,full_name,primary_email)
values('e0540000-0000-4000-8000-000000000002','e0540000-0000-4000-8000-000000000001','Synthetic No Evidence','no-evidence@demo.aptohire.test');
insert into public.skill_families(id,slug,name) values('e0540000-0000-4000-8000-000000000003','no-evidence-test','No Evidence Test');
insert into public.skills(id,family_id,slug,name) values('e0540000-0000-4000-8000-000000000004','e0540000-0000-4000-8000-000000000003','no-evidence-skill','No Evidence Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
values('e0540000-0000-4000-8000-000000000010','e0540000-0000-4000-8000-000000000002','No Evidence Project','auditing',array['e0540000-0000-4000-8000-000000000004'::uuid]);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,review_status)
values('e0540000-0000-4000-8000-000000000020','e0540000-0000-4000-8000-000000000010','web-frontend@1','test@1',0,0.1,'Evidence unavailable',
  '[{"key":"functionality","score":95,"insufficient_evidence":true,"evidence":[]},{"key":"skill_score","skill_id":"e0540000-0000-4000-8000-000000000004","score":95,"insufficient_evidence":true,"evidence":[]}]'::jsonb,'unreviewed');
select ok(pg_get_functiondef('public.apply_audit(uuid,numeric,numeric,numeric)'::regprocedure) ilike '%insufficient_evidence%' and pg_get_functiondef('public.apply_audit(uuid,numeric,numeric,numeric)'::regprocedure) ilike '%has_scorable_skill%','scoring routine excludes insufficient-evidence skill entries');
select ok(pg_get_functiondef('public.apply_audit(uuid,numeric,numeric,numeric)'::regprocedure) ilike '%needs_review%' and pg_get_functiondef('public.apply_audit(uuid,numeric,numeric,numeric)'::regprocedure) ilike '%jsonb_array_length%','audits without cited evidence remain pending human review');
select ok(has_function_privilege('service_role','public.apply_audit(uuid,numeric,numeric,numeric)','execute') and not has_function_privilege('authenticated','public.apply_audit(uuid,numeric,numeric,numeric)','execute'),'only service_role can apply audit scoring');
set local role service_role;
select public.apply_audit('e0540000-0000-4000-8000-000000000020',50,40,60);
reset role;
select is((select count(*)::int from public.skill_scores where student_id='e0540000-0000-4000-8000-000000000002' and skill_id='e0540000-0000-4000-8000-000000000004'),0,'evidence-free audit does not create or overwrite a skill score');
select is((select status from public.submissions where id='e0540000-0000-4000-8000-000000000010'),'needs_review','evidence-free audit requires human review');
select is((select review_status from public.audits where id='e0540000-0000-4000-8000-000000000020'),'pending','evidence-free audit is marked pending');
select * from finish();
rollback;
