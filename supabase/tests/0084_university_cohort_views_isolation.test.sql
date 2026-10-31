begin;
select plan(27);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('00840000-0000-4000-8000-000000000001','authenticated','authenticated','uni-cohort-a@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('00840000-0000-4000-8000-000000000002','authenticated','authenticated','uni-cohort-b@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('00840000-0000-4000-8000-000000000003','authenticated','authenticated','student-cohort@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('00840000-0000-4000-8000-000000000001','university'),
 ('00840000-0000-4000-8000-000000000002','university'),
 ('00840000-0000-4000-8000-000000000003','student');
insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,approved_at)
values
 ('00840000-0000-4000-8000-000000000011','Synthetic Cohort University A','SCA',2,'public','Jaipur','Rajasthan','approved',array['sca.edu.test'],now()),
 ('00840000-0000-4000-8000-000000000012','Synthetic Cohort University B','SCB',3,'public','Ajmer','Rajasthan','approved',array['scb.edu.test'],now());
insert into public.university_members(university_id,user_id,member_role) values
 ('00840000-0000-4000-8000-000000000011','00840000-0000-4000-8000-000000000001','tpo'),
 ('00840000-0000-4000-8000-000000000012','00840000-0000-4000-8000-000000000002','tpo');
insert into public.students(id,full_name,primary_email)
values
 ('00840000-0000-4000-8000-000000000021','Synthetic Cohort Learner A','cohort-a@demo.aptohire.test'),
 ('00840000-0000-4000-8000-000000000022','Synthetic Cohort Learner B','cohort-b@demo.aptohire.test');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,student_id,program_level,program,year,status)
values
 ('00840000-0000-4000-8000-000000000031','00840000-0000-4000-8000-000000000011',repeat('a',64),'cohort-a@demo.aptohire.test','Synthetic Cohort Learner A','00840000-0000-4000-8000-000000000021','ug','Computer Science',2,'enrolled'),
 ('00840000-0000-4000-8000-000000000032','00840000-0000-4000-8000-000000000011',repeat('b',64),'cohort-new@demo.aptohire.test','Synthetic Incoming Learner',null,'ug','Computer Science',1,'incoming'),
 ('00840000-0000-4000-8000-000000000033','00840000-0000-4000-8000-000000000012',repeat('c',64),'cohort-b@demo.aptohire.test','Synthetic Cohort Learner B','00840000-0000-4000-8000-000000000022','pg','Data Science',1,'enrolled');
insert into public.affiliations(student_id,university_id,verification,program_level,year,status,is_current)
values
 ('00840000-0000-4000-8000-000000000021','00840000-0000-4000-8000-000000000011','roster','ug',2,'enrolled',true),
 ('00840000-0000-4000-8000-000000000022','00840000-0000-4000-8000-000000000012','roster','pg',1,'enrolled',true);

select has_view('public','university_funnel_v','cohort funnel view exists');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_funnel_v'),
  array['university_id','invited','registered','submitted','verified','year','program','status']::text[],
  'funnel preserves the exact frozen aggregate/cohort column order'
);
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name='university_funnel_v'
  and column_name in ('student_id','full_name','email','student_name')),0,'funnel contains no student identity columns');
select has_view('public','university_overview_v','university overview view exists');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_overview_v'),
  array['university_id','student_count','claimed_count','assessed_count','verified_count','students_total','verified_students','active_this_month','projects_reviewed']::text[],
  'overview preserves the exact frozen counter column order'
);
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name='university_overview_v'
  and column_name in ('student_id','full_name','email','student_name')),0,'overview contains no student identity columns');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00840000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_students_v),2,'university A sees its two own roster projection rows');
select is((select count(*)::int from public.university_students_v where student_id is null and claimed=false),1,'university A projection preserves its unclaimed roster student');
select is((select count(*)::int from public.university_funnel_v),2,'university A sees its two cohort rows only');
select is((select sum(invited)::int from public.university_funnel_v),2,'university A invited total excludes university B');
select is((select sum(registered)::int from public.university_funnel_v),1,'university A registered total excludes unclaimed rows and university B');
select is((select invited from public.university_funnel_v where year=2 and program='Computer Science' and status='enrolled'),1,'funnel preserves university A enrolled year/program cohort');
select is((select invited from public.university_funnel_v where year=1 and program='Computer Science' and status='incoming'),1,'funnel preserves university A unclaimed incoming cohort');
select is((select students_total from public.university_overview_v),2,'university A overview counts its two roster entries');
select is((select student_count from public.university_overview_v),1,'overview legacy student count includes only linked current affiliations');
select is((select claimed_count from public.university_overview_v),0,'overview claim count excludes students without linked Auth users');
select is((select assessed_count from public.university_overview_v),0,'overview assessed count excludes students without scored submissions');
select is((select verified_count from public.university_overview_v),0,'overview verified count excludes students without verified shareable scores');
select is((select verified_students from public.university_overview_v),0,'overview verified roster count excludes unverified students');
select is((select projects_reviewed from public.university_overview_v),0,'overview project review count excludes students without audits');
select is((select active_this_month from public.university_overview_v),1,'university A activity counter is scoped to its linked student');
select set_config('request.jwt.claims','{"sub":"00840000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_students_v),1,'university B sees only its own roster projection row');
select is((select count(*)::int from public.university_funnel_v),1,'university B sees only its own cohort row');
select is((select sum(invited)::int from public.university_funnel_v),1,'university B aggregate excludes university A');
select is((select students_total from public.university_overview_v),1,'university B overview excludes university A roster');
select set_config('request.jwt.claims','{"sub":"00840000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_students_v),0,'student without university membership cannot query university roster rows');
select is((select count(*)::int from public.university_funnel_v),0,'student without university membership cannot query funnel rows');

select * from finish();
rollback;
