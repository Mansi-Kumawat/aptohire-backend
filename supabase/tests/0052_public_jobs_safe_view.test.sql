begin;
create function pg_temp.dml_row_count(p_sql text) returns integer
language plpgsql
as $$
declare
  affected_rows integer;
begin
  execute p_sql;
  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;
select plan(30);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0520000-0000-4000-8000-000000000001','authenticated','authenticated','student-public-jobs@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0520000-0000-4000-8000-000000000002','authenticated','authenticated','uni-public-jobs@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0520000-0000-4000-8000-000000000003','authenticated','authenticated','org-public-jobs@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0520000-0000-4000-8000-000000000004','authenticated','authenticated','other-org-public-jobs@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0520000-0000-4000-8000-000000000001','student'),
 ('a0520000-0000-4000-8000-000000000002','university'),
 ('a0520000-0000-4000-8000-000000000003','organization'),
 ('a0520000-0000-4000-8000-000000000004','organization');
insert into public.skill_families(id,slug,name)
values('a0520000-0000-4000-8000-000000000030','public-job-test','Public Job Test');
insert into public.skills(id,family_id,slug,name)
values('00000000-0000-4000-8000-000000000001','a0520000-0000-4000-8000-000000000030','public-job-skill','Public Job Skill');
insert into public.organizations(id,name,kind,size,website,status)
values
 ('a0520000-0000-4000-8000-000000000011','Synthetic Approved Co','corporate','small','https://approved.example.test','approved'),
 ('a0520000-0000-4000-8000-000000000012','Synthetic Pending Co','corporate','small','https://pending.example.test','pending'),
 ('a0520000-0000-4000-8000-000000000013','Synthetic Other Approved Co','corporate','small','https://other-approved.example.test','approved');
insert into public.organization_members(organization_id,user_id,member_role) values
 ('a0520000-0000-4000-8000-000000000011','a0520000-0000-4000-8000-000000000003','recruiter'),
 ('a0520000-0000-4000-8000-000000000012','a0520000-0000-4000-8000-000000000003','recruiter'),
 ('a0520000-0000-4000-8000-000000000013','a0520000-0000-4000-8000-000000000004','recruiter');
insert into public.jobs(id,organization_id,title,description,mode,location,status,required_skills,openings)
values
 ('a0520000-0000-4000-8000-000000000021','a0520000-0000-4000-8000-000000000011','Safe Open Role','private description','remote','India','open','[{"skill_id":"00000000-0000-4000-8000-000000000001","min_level":"Competent","weight":1}]',2),
 ('a0520000-0000-4000-8000-000000000022','a0520000-0000-4000-8000-000000000012','Pending Org Role','private description','remote','India','open','[]',1),
 ('a0520000-0000-4000-8000-000000000023','a0520000-0000-4000-8000-000000000011','Closed Role','private description','remote','India','closed','[]',1),
 ('a0520000-0000-4000-8000-000000000024','a0520000-0000-4000-8000-000000000013','Other Org Paused Role','private description','remote','India','paused','[]',1);

select is(
  (select count(*)::int from pg_policies where schemaname='public' and tablename='jobs'
    and 'authenticated'::name=any(roles)
    and ((policyname='organization_jobs_insert' and cmd='INSERT')
      or (policyname='organization_jobs_read' and cmd='SELECT')
      or (policyname='organization_jobs_update' and cmd='UPDATE'))),
  3,
  'job read/insert/update behavior below is bound to the three named organization policies'
);
select ok(has_table_privilege('authenticated','public.public_jobs','select'),'authenticated role can read the public jobs view');
select ok(not has_table_privilege('anon','public.public_jobs','select'),'anonymous role cannot read public jobs');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='public_jobs' and column_name='required_skills'),'public jobs view exposes required_skills');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='public_jobs' and column_name in ('description','openings')),'public jobs view omits descriptions and openings');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='public_jobs'),
  array['id','organization_id','title','mode','location','status','required_skills']::text[],
  'public_jobs preserves the exact frozen safe projection column order'
);
select ok(has_column_privilege('authenticated','public.jobs','title','INSERT'),'organization job insert grant permits the title field');
select ok(has_column_privilege('authenticated','public.jobs','required_skills','UPDATE'),'organization job update grant permits required skills');
select ok(not has_column_privilege('authenticated','public.jobs','organization_id','UPDATE'),'organization cannot move a job to another organization');
select ok(not has_column_privilege('authenticated','public.jobs','id','INSERT'),'organization cannot supply job identity');
select is(
  (select array_agg(column_name::text order by column_name::text) from information_schema.column_privileges where table_schema='public' and table_name='jobs' and grantee='authenticated' and privilege_type='INSERT'),
  array['description','location','mode','openings','organization_id','required_skills','status','title']::text[],
  'job INSERT privileges exactly match the frozen allowlist'
);
select is(
  (select array_agg(column_name::text order by column_name::text) from information_schema.column_privileges where table_schema='public' and table_name='jobs' and grantee='authenticated' and privilege_type='UPDATE'),
  array['description','location','mode','openings','required_skills','status','title']::text[],
  'job UPDATE privileges exactly match the frozen allowlist'
);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0520000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.public_jobs where id in ('a0520000-0000-4000-8000-000000000021','a0520000-0000-4000-8000-000000000022','a0520000-0000-4000-8000-000000000023','a0520000-0000-4000-8000-000000000024')),1,'fixture student sees only the open job of an approved organization');
select is((select count(*)::int from public.public_jobs where id='a0520000-0000-4000-8000-000000000021'),1,'student can read safe approved-org job projection');
select is((select required_skills from public.public_jobs where id='a0520000-0000-4000-8000-000000000021'), '[{"skill_id":"00000000-0000-4000-8000-000000000001","min_level":"Competent","weight":1}]'::jsonb,'student receives the structured required-skill contract');
select is((select count(*)::int from public.public_jobs where id in ('a0520000-0000-4000-8000-000000000022','a0520000-0000-4000-8000-000000000023')),0,'student cannot see pending-org or closed jobs');

select set_config('request.jwt.claims','{"sub":"a0520000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.public_jobs where id in ('a0520000-0000-4000-8000-000000000021','a0520000-0000-4000-8000-000000000022','a0520000-0000-4000-8000-000000000023','a0520000-0000-4000-8000-000000000024')),1,'university member sees the fixture approved open job projection');
select set_config('request.jwt.claims','{"sub":"a0520000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.public_jobs),0,'organization role does not receive the student/university public job view');
select is((select count(*)::int from public.my_organization_v where id in ('a0520000-0000-4000-8000-000000000011','a0520000-0000-4000-8000-000000000012','a0520000-0000-4000-8000-000000000013')),2,'organization member view returns each own organization membership');
select is((select count(*)::int from public.my_organization_v where id='a0520000-0000-4000-8000-000000000013'),0,'organization member view omits another approved organization');
select is((select count(*)::int from public.organization_members),2,'organization member read policy returns only memberships in the caller organizations');
select is((select count(*)::int from public.organization_members where user_id='a0520000-0000-4000-8000-000000000004'),0,'organization member cannot inspect an unrelated organization membership');
select is((select count(*)::int from public.jobs where id in ('a0520000-0000-4000-8000-000000000021','a0520000-0000-4000-8000-000000000022','a0520000-0000-4000-8000-000000000024')),1,'organization member can read only its approved-organization job base row');
select is((select count(*)::int from public.jobs where id='a0520000-0000-4000-8000-000000000024'),0,'organization member cannot read another approved organization job');
select is(pg_temp.dml_row_count($$insert into public.jobs(organization_id,title,description,status,required_skills,openings) values ('a0520000-0000-4000-8000-000000000011','New Approved Job','Synthetic','open','[]'::jsonb,1)$$),1,'approved organization member can insert a job');
select throws_ok($$insert into public.jobs(organization_id,title,description,status,required_skills,openings) values ('a0520000-0000-4000-8000-000000000012','Blocked Pending Job','Synthetic','open','[]'::jsonb,1)$$,'42501',null,'pending organization member cannot insert a job');
select throws_ok($$insert into public.jobs(organization_id,title,description,status,required_skills,openings) values ('a0520000-0000-4000-8000-000000000013','Blocked Other Org Job','Synthetic','open','[]'::jsonb,1)$$,'42501',null,'organization member cannot insert into another approved organization');
select is(pg_temp.dml_row_count($$update public.jobs set status='paused' where id='a0520000-0000-4000-8000-000000000021'$$),1,'approved organization member can update its own job');
select is(pg_temp.dml_row_count($$update public.jobs set status='paused' where id='a0520000-0000-4000-8000-000000000022'$$),0,'pending organization member cannot update a pending-org job');
select is(pg_temp.dml_row_count($$update public.jobs set status='closed' where id='a0520000-0000-4000-8000-000000000024'$$),0,'organization member cannot update another approved organization job');

select * from finish();
rollback;
