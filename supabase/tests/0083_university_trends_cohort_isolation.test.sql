begin;
select plan(22);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('00830000-0000-4000-8000-000000000001','authenticated','authenticated','uni-trends-a@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('00830000-0000-4000-8000-000000000002','authenticated','authenticated','uni-trends-b@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('00830000-0000-4000-8000-000000000003','authenticated','authenticated','student-trends@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('00830000-0000-4000-8000-000000000004','authenticated','authenticated','admin-trends@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('00830000-0000-4000-8000-000000000001','university'),
 ('00830000-0000-4000-8000-000000000002','university'),
 ('00830000-0000-4000-8000-000000000003','student'),
 ('00830000-0000-4000-8000-000000000004','admin');
insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,approved_at)
values
 ('00830000-0000-4000-8000-000000000011','Synthetic Trends University A','STA',2,'public','Jaipur','Rajasthan','approved',array['sta.edu.test'],now()),
 ('00830000-0000-4000-8000-000000000012','Synthetic Trends University B','STB',3,'public','Ajmer','Rajasthan','approved',array['stb.edu.test'],now());
insert into public.university_members(university_id,user_id,member_role) values
 ('00830000-0000-4000-8000-000000000011','00830000-0000-4000-8000-000000000001','tpo'),
 ('00830000-0000-4000-8000-000000000012','00830000-0000-4000-8000-000000000002','tpo');
insert into public.students(id,full_name,primary_email,created_at)
values
 ('00830000-0000-4000-8000-000000000021','Synthetic Trends Learner A','trends-a@demo.aptohire.test',now()),
 ('00830000-0000-4000-8000-000000000022','Synthetic Trends Learner B','trends-b@demo.aptohire.test',now()-interval '30 weeks');
insert into public.affiliations(student_id,university_id,verification,program_level,status,is_current)
values
 ('00830000-0000-4000-8000-000000000021','00830000-0000-4000-8000-000000000011','roster','ug','enrolled',true),
 ('00830000-0000-4000-8000-000000000022','00830000-0000-4000-8000-000000000012','roster','ug','enrolled',true);
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,program,year,status,student_id)
values('00830000-0000-4000-8000-000000000034','00830000-0000-4000-8000-000000000011',repeat('f',64),'trends-a@sta.edu.test','Synthetic Trends Learner A','Bachelors','Computer Science',1,'student','00830000-0000-4000-8000-000000000021');
insert into public.skill_families(id,slug,name)
values('00830000-0000-4000-8000-000000000031','trend-fixture','Trend Fixture');
insert into public.skills(id,family_id,slug,name)
values
 ('00830000-0000-4000-8000-000000000032','00830000-0000-4000-8000-000000000031','trend-skill','Trend Skill'),
 ('00830000-0000-4000-8000-000000000033','00830000-0000-4000-8000-000000000031','pending-trend-skill','Pending Trend Skill');
insert into public.submissions(id,student_id,title,status)
values('00830000-0000-4000-8000-000000000041','00830000-0000-4000-8000-000000000021','Synthetic Trend Submission','scored');
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,review_status)
values('00830000-0000-4000-8000-000000000042','00830000-0000-4000-8000-000000000041','fixture@1','fixture@1',75,0.9,'complete');
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
values
 ('00830000-0000-4000-8000-000000000021','00830000-0000-4000-8000-000000000032',75,'Proficient',true,false,true,'00830000-0000-4000-8000-000000000042',now()),
 ('00830000-0000-4000-8000-000000000021','00830000-0000-4000-8000-000000000033',95,'Advanced',true,true,true,'00830000-0000-4000-8000-000000000042',now());

select has_view('public','university_trends_v','weekly university trends view exists');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_trends_v'),
  array['week_start','verified_total','reviews','new_registrations']::text[],
  'trend view preserves the exact frozen output column order'
);
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name='university_trends_v'
  and column_name in ('student_id','full_name','email','student_name')),0,'trend view exposes no student identity columns');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00830000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.my_university_v),1,'university A member sees exactly its own university profile');
select is((select count(*)::int from public.my_university_v where id='00830000-0000-4000-8000-000000000012'),0,'university A member cannot see university B profile');
select is((select count(*)::int from public.university_student_skills_v),1,'university A member sees its own verified shareable skill row');
select is((select count(*)::int from public.university_student_skills_v where skill_name='Pending Trend Skill'),0,'university student skills view excludes pending-review scores');
select is((select count(*)::int from public.university_trends_v),26,'university member receives exactly 26 weekly rows');
select is((select new_registrations from public.university_trends_v where week_start=date_trunc('week',now())::date),1,'current-week registrations count only university A cohort');
select is((select verified_total from public.university_trends_v where week_start=date_trunc('week',now())::date),1,'verified trend counts only university A shareable verified student');
select is((select reviews from public.university_trends_v where week_start=date_trunc('week',now())::date),1,'review trend counts only university A audit activity');
select set_config('request.jwt.claims','{"sub":"00830000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.my_university_v),1,'university B member sees exactly its own university profile');
select is((select count(*)::int from public.university_student_skills_v),0,'university B cannot see university A verified skill rows');
select is((select new_registrations from public.university_trends_v where week_start=date_trunc('week',now())::date),0,'university B does not inherit university A current-week registration');
select is((select verified_total from public.university_trends_v where week_start=date_trunc('week',now())::date),0,'university B does not inherit university A verified trend');
select is((select reviews from public.university_trends_v where week_start=date_trunc('week',now())::date),0,'university B does not inherit university A review activity');
select set_config('request.jwt.claims','{"sub":"00830000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_trends_v),0,'student without university membership cannot query trends');
select is((select count(*)::int from public.my_university_v),0,'student without university membership cannot query university profiles');
select is((select count(*)::int from public.university_student_skills_v),0,'student without university membership cannot query university student skills');
select set_config('request.jwt.claims','{"sub":"00830000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_trends_v),0,'aal1 admin receives no university trend aggregates');
select is((select count(*)::int from public.my_university_v),0,'aal1 admin receives no university profiles');
select is((select count(*)::int from public.university_student_skills_v),0,'aal1 admin receives no university student skill rows');

select * from finish();
rollback;
