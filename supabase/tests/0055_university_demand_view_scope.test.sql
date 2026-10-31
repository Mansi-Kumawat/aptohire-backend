begin;
select plan(9);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0550000-0000-4000-8000-000000000001','authenticated','authenticated','uni-a-demand@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0550000-0000-4000-8000-000000000002','authenticated','authenticated','uni-b-demand@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0550000-0000-4000-8000-000000000003','authenticated','authenticated','student-demand@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0550000-0000-4000-8000-000000000001','university'),
 ('a0550000-0000-4000-8000-000000000002','university'),
 ('a0550000-0000-4000-8000-000000000003','student');
insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,approved_at)
values
 ('a0550000-0000-4000-8000-000000000011','Synthetic Demand University A','SDA',2,'public','Jaipur','Rajasthan','approved',array['sda.edu.test'],now()),
 ('a0550000-0000-4000-8000-000000000012','Synthetic Demand University B','SDB',3,'public','Ajmer','Rajasthan','approved',array['sdb.edu.test'],now());
insert into public.university_members(university_id,user_id,member_role) values
 ('a0550000-0000-4000-8000-000000000011','a0550000-0000-4000-8000-000000000001','tpo'),
 ('a0550000-0000-4000-8000-000000000012','a0550000-0000-4000-8000-000000000002','tpo');
insert into public.skill_families(id,slug,name) values('a0550000-0000-4000-8000-000000000021','demand-test','Demand Test');
insert into public.skills(id,family_id,slug,name) values('a0550000-0000-4000-8000-000000000022','a0550000-0000-4000-8000-000000000021','demand-skill','Demand Skill');
insert into public.organizations(id,name,kind,size,status) values
 ('a0550000-0000-4000-8000-000000000031','Approved Demand Co','corporate','small','approved'),
 ('a0550000-0000-4000-8000-000000000032','Pending Demand Co','corporate','small','pending');
insert into public.jobs(id,organization_id,title,description,status,required_skills,created_at)
values
 ('a0550000-0000-4000-8000-000000000041','a0550000-0000-4000-8000-000000000031','Approved Demand Job','Synthetic','open','[{"skill_id":"a0550000-0000-4000-8000-000000000022","min_level":"Competent","weight":1}]',now()-interval '1 hour'),
 ('a0550000-0000-4000-8000-000000000042','a0550000-0000-4000-8000-000000000032','Pending Demand Job','Synthetic','open','[{"skill_id":"a0550000-0000-4000-8000-000000000022","min_level":"Competent","weight":1}]',now()+interval '1 day'),
 ('a0550000-0000-4000-8000-000000000043','a0550000-0000-4000-8000-000000000031','Closed Demand Job','Synthetic','closed','[{"skill_id":"a0550000-0000-4000-8000-000000000022","min_level":"Competent","weight":1}]',now()+interval '2 days');
insert into public.demand_signals(id,job_id,university_id,reason_counts,skill_slugs)
values
 ('a0550000-0000-4000-8000-000000000051','a0550000-0000-4000-8000-000000000041','a0550000-0000-4000-8000-000000000011','{"insufficient_evidence":2}'::jsonb,array['demand-skill']),
 ('a0550000-0000-4000-8000-000000000052','a0550000-0000-4000-8000-000000000041','a0550000-0000-4000-8000-000000000012','{"skills_mismatch":5}'::jsonb,array['demand-skill']);

select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_demand_v'),
  array['id','skill_name','jobs_count','reasons','last_posted_at']::text[],
  'demand view preserves the exact frozen aggregate column order'
);
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name='university_demand_v' and column_name in ('student_id','full_name','email','student_name')),0,'demand view contains no student identity columns');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0550000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select jobs_count from public.university_demand_v where id='a0550000-0000-4000-8000-000000000022'),1,'University A counts only approved-organization open jobs');
select ok((select last_posted_at < now() from public.university_demand_v where id='a0550000-0000-4000-8000-000000000022'),'pending organization does not affect the latest-posted timestamp');
select is((select reasons from public.university_demand_v where id='a0550000-0000-4000-8000-000000000022'),'{"insufficient_evidence":2}'::jsonb,'University A sees only its own demand reasons');

select set_config('request.jwt.claims','{"sub":"a0550000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select jobs_count from public.university_demand_v where id='a0550000-0000-4000-8000-000000000022'),1,'University B also counts only approved-organization open jobs');
select is((select reasons from public.university_demand_v where id='a0550000-0000-4000-8000-000000000022'),'{"skills_mismatch":5}'::jsonb,'University B sees only its own demand reasons');

select set_config('request.jwt.claims','{"sub":"a0550000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.university_demand_v where id='a0550000-0000-4000-8000-000000000022'),0,'student cannot read university demand aggregates');
select ok(not has_table_privilege('anon','public.university_demand_v','select'),'anonymous callers cannot read university demand view');

select * from finish();
rollback;
