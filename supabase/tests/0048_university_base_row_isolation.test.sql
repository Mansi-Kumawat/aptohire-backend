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
select plan(49);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0480000-0000-4000-8000-000000000001','authenticated','authenticated','uni-a-rls@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0480000-0000-4000-8000-000000000002','authenticated','authenticated','uni-b-rls@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0480000-0000-4000-8000-000000000003','authenticated','authenticated','student-uni-directory@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0480000-0000-4000-8000-000000000004','authenticated','authenticated','admin-uni-directory@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0480000-0000-4000-8000-000000000005','authenticated','authenticated','uni-a-staff-2@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0480000-0000-4000-8000-000000000006','authenticated','authenticated','uni-b-staff-2@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0480000-0000-4000-8000-000000000001','university'),
 ('a0480000-0000-4000-8000-000000000002','university'),
 ('a0480000-0000-4000-8000-000000000003','student'),
 ('a0480000-0000-4000-8000-000000000004','admin'),
 ('a0480000-0000-4000-8000-000000000005','university'),
 ('a0480000-0000-4000-8000-000000000006','university');
insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,approved_at)
values
 ('a0480000-0000-4000-8000-000000000011','Synthetic University A','SUA',2,'public','Jaipur','Rajasthan','approved',array['sua.edu.test'],now()),
 ('a0480000-0000-4000-8000-000000000012','Synthetic University B','SUB',3,'public','Ajmer','Rajasthan','approved',array['sub.edu.test'],now());
insert into public.university_members(university_id,user_id,member_role) values
 ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000001','tpo'),
 ('a0480000-0000-4000-8000-000000000012','a0480000-0000-4000-8000-000000000002','tpo'),
 ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000005','staff'),
 ('a0480000-0000-4000-8000-000000000012','a0480000-0000-4000-8000-000000000006','staff');
insert into public.students(id,full_name,primary_email)
values ('a0480000-0000-4000-8000-000000000031','Synthetic Linked Student','linked-roster@fixture.test');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,program,year,status,student_id)
values
 ('a0480000-0000-4000-8000-000000000021','a0480000-0000-4000-8000-000000000011',repeat('a',64),'roster-a@sua.edu.test','Synthetic Roster A','Bachelors','Computer Science',1,'student',null),
 ('a0480000-0000-4000-8000-000000000022','a0480000-0000-4000-8000-000000000012',repeat('b',64),'roster-b@sub.edu.test','Synthetic Roster B','Bachelors','Computer Science',2,'student',null),
 ('a0480000-0000-4000-8000-000000000023','a0480000-0000-4000-8000-000000000011',repeat('c',64),'roster-a-unclaimed@sua.edu.test','Synthetic Unclaimed A','Bachelors','Computer Science',1,'student',null),
 ('a0480000-0000-4000-8000-000000000024','a0480000-0000-4000-8000-000000000011',repeat('d',64),'roster-a-linked@sua.edu.test','Synthetic Linked A','Bachelors','Computer Science',2,'student','a0480000-0000-4000-8000-000000000031'),
 ('a0480000-0000-4000-8000-000000000025','a0480000-0000-4000-8000-000000000012',repeat('e',64),'roster-b-unclaimed@sub.edu.test','Synthetic Unclaimed B','Bachelors','Computer Science',2,'student',null);
insert into storage.objects(bucket_id,name) values
 ('rosters','a0480000-0000-4000-8000-000000000011/own.csv'),
 ('rosters','a0480000-0000-4000-8000-000000000012/own.csv'),
 ('rosters','a0480000-0000-4000-8000-000000000011/protected.csv'),
 ('videos','a0480000-0000-4000-8000-000000000099/submission/demo.mp4');

select is(
  (select count(*)::int from pg_policies where schemaname='public' and 'authenticated'::name=any(roles)
    and ((tablename='universities' and policyname='universities_member_read' and cmd='SELECT')
      or (tablename='universities' and policyname='universities_admin_read' and cmd='SELECT')
      or (tablename='university_members' and policyname='university_members_scope_read' and cmd='SELECT')
      or (tablename='roster_entries' and policyname='roster_member_read' and cmd='SELECT')
      or (tablename='roster_entries' and policyname='roster_university_read' and cmd='SELECT')
      or (tablename='roster_entries' and policyname='roster_university_delete_unclaimed' and cmd='DELETE')
      or (tablename='roster_entries' and policyname='roster_university_update' and cmd='UPDATE')
      or (tablename='roster_entries' and policyname='roster_university_insert' and cmd='INSERT'))),
  8,
  'university, membership, and roster behavior below maps to eight active named policies'
);
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='universities' and policyname='universities_member_read'),'member-only base-table policy exists');
select ok(not exists(select 1 from pg_policies where schemaname='public' and tablename='universities' and policyname='university_public_approved'),'broad approved-row policy is removed');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='university_members' and policyname='university_members_scope_read'),'university-scoped member policy exists');
select ok(not exists(select 1 from pg_policies where schemaname='public' and tablename='university_members' and policyname='members_self_read'),'user-only membership policy is removed');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='university_roster_objects_delete' and cmd='DELETE' and qual ilike '%bucket_id%' and qual ilike '%foldername%' and qual ilike '%my_university_ids%'),'roster object delete policy is a member-scoped DELETE rule');
select ok(not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='university_roster_objects' and cmd='ALL'),'legacy broad roster object policy is removed');
select ok(has_table_privilege('authenticated','storage.objects','delete'),'authenticated callers have Storage DELETE privilege gated by RLS');
select is((select count(*)::int from pg_policies where schemaname='storage' and tablename='objects'
 and 'authenticated'::name=any(roles) and ((policyname='university_roster_objects_select' and cmd='SELECT')
 or (policyname='university_roster_objects_insert' and cmd='INSERT')
 or (policyname='university_roster_objects_update' and cmd='UPDATE')
 or (policyname='university_roster_objects_delete' and cmd='DELETE'))),4,
 'university roster Storage policy set explicitly covers all four CRUD operations');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0480000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.universities where id='a0480000-0000-4000-8000-000000000011'),1,'university A member can read its own base row');
select is((select count(*)::int from public.universities where id='a0480000-0000-4000-8000-000000000012'),0,'university A member cannot read university B base row');
select is((select count(*)::int from public.public_universities where id='a0480000-0000-4000-8000-000000000012'),1,'approved public directory still exposes university B to university A');
select is((select count(*)::int from public.roster_entries where id='a0480000-0000-4000-8000-000000000021'),1,'university A member can read its own roster row');
select is((select count(*)::int from public.roster_entries where id='a0480000-0000-4000-8000-000000000022'),0,'university A member cannot read university B roster row');
select is(pg_temp.dml_row_count($$update public.roster_entries set year=3 where id='a0480000-0000-4000-8000-000000000021'$$),1,'university A can update an allowed field on its own roster row');
select is(pg_temp.dml_row_count($$update public.roster_entries set year=3 where id='a0480000-0000-4000-8000-000000000022'$$),0,'university A cannot update another university roster row');
select is(pg_temp.dml_row_count($$insert into public.roster_entries(university_id,email,program_level,year,status)
 values('a0480000-0000-4000-8000-000000000011','new-roster@sua.edu.test','Bachelors',1,'student')$$),1,'university A can insert a roster entry for its own university');
select throws_ok($$insert into public.roster_entries(university_id,email,program_level,year,status)
 values('a0480000-0000-4000-8000-000000000012','foreign-roster@sub.edu.test','Bachelors',1,'student')$$,'42501',null,'university A cannot insert a roster entry for university B');
select is((select count(*)::int from public.university_members where university_id='a0480000-0000-4000-8000-000000000011'),2,'university A member can read all memberships for its own university');
select is((select count(*)::int from public.university_members where university_id='a0480000-0000-4000-8000-000000000012'),0,'university A member cannot read university B membership row');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='university_roster_objects_delete' and cmd='DELETE' and qual ilike '%my_university_ids%'),'university roster delete policy is scoped to the caller university');
select is((select count(*)::int from storage.objects where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000012/own.csv'),0,'university A cannot see university B roster object for Storage API deletion');
select ok((select qual ilike '%bucket_id%rosters%' from pg_policies where schemaname='storage' and tablename='objects' and policyname='university_roster_objects_delete'),'university delete policy is limited to the roster bucket, not student media');
select is((select count(*)::int from storage.objects where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000011/protected.csv'),1,'university A can read its own roster Storage object');
select is((select count(*)::int from storage.objects where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000012/own.csv'),0,'university A cannot read university B roster Storage object');
select is(pg_temp.dml_row_count($$insert into storage.objects(bucket_id,name) values('rosters','a0480000-0000-4000-8000-000000000011/new.csv')$$),1,'university A can insert its own roster Storage object');
select throws_ok($$insert into storage.objects(bucket_id,name) values('rosters','a0480000-0000-4000-8000-000000000012/forged.csv')$$,'42501',null,'university A cannot insert university B roster Storage object');
select is(pg_temp.dml_row_count($$update storage.objects set name='a0480000-0000-4000-8000-000000000011/protected-renamed.csv' where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000011/protected.csv'$$),1,'university A can rename its roster object within its own path');
select throws_ok($$update storage.objects set name='a0480000-0000-4000-8000-000000000012/hijacked.csv' where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000011/protected-renamed.csv'$$,'42501',null,'university A cannot rekey its roster object into university B path');
select is(pg_temp.dml_row_count($$update storage.objects set name='a0480000-0000-4000-8000-000000000011/stolen.csv' where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000012/own.csv'$$),0,'university A cannot update university B roster Storage object');

select set_config('request.jwt.claims','{"sub":"a0480000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.universities where id='a0480000-0000-4000-8000-000000000012'),1,'university B member can read its own base row');
select is((select count(*)::int from public.universities where id='a0480000-0000-4000-8000-000000000011'),0,'university B member cannot read university A base row');
select is((select count(*)::int from public.roster_entries where id='a0480000-0000-4000-8000-000000000022'),1,'university B member can read its own roster row');
select is((select count(*)::int from public.roster_entries where id='a0480000-0000-4000-8000-000000000021'),0,'university B member cannot read university A roster row');
select is((select count(*)::int from public.university_members where university_id='a0480000-0000-4000-8000-000000000012'),2,'university B member can read all memberships for its own university');
select is((select count(*)::int from public.university_members where university_id='a0480000-0000-4000-8000-000000000011'),0,'university B member cannot read university A membership row');
select is((select count(*)::int from storage.objects where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000012/own.csv'),1,'university B sees its roster object to delete through the Storage API');
select is((select count(*)::int from storage.objects where bucket_id='rosters' and name='a0480000-0000-4000-8000-000000000011/protected-renamed.csv'),0,'university B cannot see university A roster object to delete through the Storage API');

select set_config('request.jwt.claims','{"sub":"a0480000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.public_universities where id in ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000012')),2,'student can browse both approved universities through the explicit public view');
select is((select count(*)::int from public.universities where id in ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000012')),0,'student cannot query university base rows directly');
select is((select count(*)::int from public.roster_entries where id in ('a0480000-0000-4000-8000-000000000021','a0480000-0000-4000-8000-000000000022')),0,'student cannot read university roster rows');
select is((select count(*)::int from public.university_members where university_id in ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000012')),0,'student cannot read university membership rows');

select set_config('request.jwt.claims','{"sub":"a0480000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::int from public.universities where id in ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000012')),2,'aal2 admin can read both university base rows');
select is((select count(*)::int from public.roster_entries where id in ('a0480000-0000-4000-8000-000000000021','a0480000-0000-4000-8000-000000000022')),2,'aal2 admin can read both roster rows');
select is((select count(*)::int from public.university_members where university_id in ('a0480000-0000-4000-8000-000000000011','a0480000-0000-4000-8000-000000000012')),4,'aal2 admin can read all university membership rows');

select set_config('request.jwt.claims','{"sub":"a0480000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is(pg_temp.dml_row_count($$delete from public.roster_entries where id='a0480000-0000-4000-8000-000000000023'$$),1,'university A can delete its own unclaimed roster row');
select is(pg_temp.dml_row_count($$delete from public.roster_entries where id='a0480000-0000-4000-8000-000000000024'$$),0,'university A cannot delete a claimed roster row');
select is(pg_temp.dml_row_count($$delete from public.roster_entries where id='a0480000-0000-4000-8000-000000000025'$$),0,'university A cannot delete another university roster row');
select set_config('request.jwt.claims','{"sub":"a0480000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is(pg_temp.dml_row_count($$delete from public.roster_entries where id='a0480000-0000-4000-8000-000000000025'$$),1,'university B can delete its own unclaimed roster row');

select * from finish();
rollback;
