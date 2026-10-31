begin;
select plan(12);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0540000-0000-4000-8000-000000000001','authenticated','authenticated','uni-a-skills@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0540000-0000-4000-8000-000000000002','authenticated','authenticated','uni-b-skills@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0540000-0000-4000-8000-000000000003','authenticated','authenticated','student-skills@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0540000-0000-4000-8000-000000000004','authenticated','authenticated','admin-skills@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0540000-0000-4000-8000-000000000001','university'),
 ('a0540000-0000-4000-8000-000000000002','university'),
 ('a0540000-0000-4000-8000-000000000003','student'),
 ('a0540000-0000-4000-8000-000000000004','admin');
insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,approved_at)
values
 ('a0540000-0000-4000-8000-000000000011','Synthetic Skills University A','SSA',2,'public','Jaipur','Rajasthan','approved',array['ssa.edu.test'],now()),
 ('a0540000-0000-4000-8000-000000000012','Synthetic Skills University B','SSB',3,'public','Ajmer','Rajasthan','approved',array['ssb.edu.test'],now());
insert into public.university_members(university_id,user_id,member_role) values
 ('a0540000-0000-4000-8000-000000000011','a0540000-0000-4000-8000-000000000001','tpo'),
 ('a0540000-0000-4000-8000-000000000012','a0540000-0000-4000-8000-000000000002','tpo');
insert into public.students(id,full_name,primary_email) values
 ('a0540000-0000-4000-8000-000000000021','Synthetic Learner A','learner-a@demo.aptohire.test'),
 ('a0540000-0000-4000-8000-000000000022','Synthetic Learner B','learner-b@demo.aptohire.test');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,student_id,program_level,program,year,status)
values
 ('a0540000-0000-4000-8000-000000000031','a0540000-0000-4000-8000-000000000011',repeat('a',64),'learner-a@demo.aptohire.test','Synthetic Learner A','a0540000-0000-4000-8000-000000000021','Bachelors','CS',2,'student'),
 ('a0540000-0000-4000-8000-000000000032','a0540000-0000-4000-8000-000000000012',repeat('b',64),'learner-b@demo.aptohire.test','Synthetic Learner B','a0540000-0000-4000-8000-000000000022','Bachelors','CS',2,'student');
insert into public.skill_families(id,slug,name) values('a0540000-0000-4000-8000-000000000041','aggregate-test','Aggregate Test');
insert into public.skills(id,family_id,slug,name) values
 ('a0540000-0000-4000-8000-000000000042','a0540000-0000-4000-8000-000000000041','aggregate-skill','Aggregate Skill'),
 ('a0540000-0000-4000-8000-000000000043','a0540000-0000-4000-8000-000000000041','pending-skill','Pending Skill');
insert into public.skill_scores(id,student_id,skill_id,score,level,verified,pending_review,share_ok)
values
 ('a0540000-0000-4000-8000-000000000051','a0540000-0000-4000-8000-000000000021','a0540000-0000-4000-8000-000000000042',80,'Proficient',true,false,true),
 ('a0540000-0000-4000-8000-000000000052','a0540000-0000-4000-8000-000000000022','a0540000-0000-4000-8000-000000000042',20,'Emerging',true,false,true),
 ('a0540000-0000-4000-8000-000000000053','a0540000-0000-4000-8000-000000000021','a0540000-0000-4000-8000-000000000043',99,'Advanced',true,true,true);

select ok(exists(select 1 from pg_views where schemaname='public' and viewname='university_skills_v'),'university skill aggregate view exists');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_skills_v'),
  array['skill_id','skill_name','family','verified_students','assessed_students','avg_score','open_jobs']::text[],
  'skills view preserves the exact frozen aggregate column order'
);
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name='university_skills_v' and column_name in ('student_id','full_name','email','student_name')),0,'aggregate has no student identity columns');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0540000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select verified_students from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),1,'university A aggregate counts only its verified student');
select is((select assessed_students from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),1,'university A aggregate counts only its assessed student');
select is((select avg_score from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),80::numeric,'university A average excludes university B score');
select is((select verified_students from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000043'),0,'pending-review skill is excluded from verified count');
select ok((select avg_score is null from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000043'),'pending-review score is excluded from the aggregate average');

select set_config('request.jwt.claims','{"sub":"a0540000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select avg_score from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),20::numeric,'university B average excludes university A score');

select set_config('request.jwt.claims','{"sub":"a0540000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),0,'student without university membership cannot query university aggregates');

select set_config('request.jwt.claims','{"sub":"a0540000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);
select is((select avg_score from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),50::numeric,'aal2 admin can see all-university aggregate');
select is((select verified_students from public.university_skills_v where skill_id='a0540000-0000-4000-8000-000000000042'),2,'aal2 admin aggregate includes both universities');

select * from finish();
rollback;
