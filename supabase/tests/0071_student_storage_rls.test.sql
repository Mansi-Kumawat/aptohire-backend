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
select plan(24);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0710000-0000-4000-8000-000000000001','authenticated','authenticated','storage-owner@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0710000-0000-4000-8000-000000000002','authenticated','authenticated','storage-other@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0710000-0000-4000-8000-000000000001','student'),
 ('a0710000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
 ('a0710000-0000-4000-8000-000000000011','a0710000-0000-4000-8000-000000000001','Synthetic Storage Owner','storage-owner@demo.aptohire.test'),
 ('a0710000-0000-4000-8000-000000000012','a0710000-0000-4000-8000-000000000002','Synthetic Other Student','storage-other@demo.aptohire.test');
insert into storage.objects(bucket_id,name) values
 ('videos','a0710000-0000-4000-8000-000000000011/submission/own.mp4'),
 ('videos','a0710000-0000-4000-8000-000000000012/submission/other.mp4'),
 ('documents','a0710000-0000-4000-8000-000000000011/project/own.pdf'),
 ('documents','a0710000-0000-4000-8000-000000000012/project/other.pdf'),
 ('avatars','a0710000-0000-4000-8000-000000000011.jpg'),
 ('avatars','a0710000-0000-4000-8000-000000000012.jpg'),
 ('resumes','a0710000-0000-4000-8000-000000000011/resume.pdf'),
 ('resumes','a0710000-0000-4000-8000-000000000012/resume.pdf');

select is((select count(*)::int from pg_policies where schemaname='storage' and tablename='objects'
 and 'authenticated'::name=any(roles) and ((policyname='student_storage_select' and cmd='SELECT')
 or (policyname='student_storage_insert' and cmd='INSERT') or (policyname='student_storage_update' and cmd='UPDATE')
 or (policyname='student_storage_delete' and cmd='DELETE'))),4,'student Storage policy set explicitly covers all four CRUD operations');
select ok(has_table_privilege('authenticated','storage.objects','select') and has_table_privilege('authenticated','storage.objects','insert')
 and has_table_privilege('authenticated','storage.objects','update') and has_table_privilege('authenticated','storage.objects','delete'),
'authenticated role has the Storage CRUD privileges that policies restrict');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0710000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from storage.objects where bucket_id='videos' and name='a0710000-0000-4000-8000-000000000011/submission/own.mp4'),1,'student can read own Storage object');
select is((select count(*)::int from storage.objects where bucket_id='videos' and name='a0710000-0000-4000-8000-000000000012/submission/other.mp4'),0,'student cannot read another student Storage object');
select is((select count(*)::int from storage.objects where bucket_id='documents' and name='a0710000-0000-4000-8000-000000000011/project/own.pdf'),1,'student can read own documents bucket object');
select is((select count(*)::int from storage.objects where bucket_id='documents' and name='a0710000-0000-4000-8000-000000000012/project/other.pdf'),0,'student cannot read another student documents object');
select is((select count(*)::int from storage.objects where bucket_id='avatars' and name='a0710000-0000-4000-8000-000000000011.jpg'),1,'student can read own exact-path avatar object');
select is((select count(*)::int from storage.objects where bucket_id='avatars' and name='a0710000-0000-4000-8000-000000000012.jpg'),0,'student cannot read another student avatar object');
select is((select count(*)::int from storage.objects where bucket_id='resumes' and name='a0710000-0000-4000-8000-000000000011/resume.pdf'),1,'student can read own resume object');
select is((select count(*)::int from storage.objects where bucket_id='resumes' and name='a0710000-0000-4000-8000-000000000012/resume.pdf'),0,'student cannot read another student resume object');
select is(pg_temp.dml_row_count($$insert into storage.objects(bucket_id,name) values('videos','a0710000-0000-4000-8000-000000000011/submission/new.mp4')$$),1,'student can insert own Storage object');
select throws_ok($$insert into storage.objects(bucket_id,name) values('videos','a0710000-0000-4000-8000-000000000012/submission/forged.mp4')$$,'42501',null,'student cannot insert another student Storage object');
select is(pg_temp.dml_row_count($$insert into storage.objects(bucket_id,name) values('documents','a0710000-0000-4000-8000-000000000011/project/new.pdf')$$),1,'student can insert own documents object');
select throws_ok($$insert into storage.objects(bucket_id,name) values('documents','a0710000-0000-4000-8000-000000000012/project/forged.pdf')$$,'42501',null,'student cannot insert another student documents object');
select throws_ok($$insert into storage.objects(bucket_id,name) values('avatars','a0710000-0000-4000-8000-000000000011-extra.jpg')$$,'42501',null,'student cannot insert a noncanonical avatar path');
select throws_ok($$insert into storage.objects(bucket_id,name) values('avatars','a0710000-0000-4000-8000-000000000012.jpg')$$,'42501',null,'student cannot insert another student avatar object');
select is(pg_temp.dml_row_count($$insert into storage.objects(bucket_id,name) values('resumes','a0710000-0000-4000-8000-000000000011/new.pdf')$$),1,'student can insert own resume object');
select throws_ok($$insert into storage.objects(bucket_id,name) values('resumes','a0710000-0000-4000-8000-000000000012/forged.pdf')$$,'42501',null,'student cannot insert another student resume object');
select is(pg_temp.dml_row_count($$update storage.objects set name='a0710000-0000-4000-8000-000000000011/submission/renamed.mp4' where bucket_id='videos' and name='a0710000-0000-4000-8000-000000000011/submission/own.mp4'$$),1,'student can rename own Storage object within own path');
select is(pg_temp.dml_row_count($$update storage.objects set name='a0710000-0000-4000-8000-000000000011/submission/stolen.mp4' where bucket_id='videos' and name='a0710000-0000-4000-8000-000000000012/submission/other.mp4'$$),0,'student cannot update another student Storage object');
select throws_ok($$update storage.objects set name='a0710000-0000-4000-8000-000000000012/project/hijacked.pdf' where bucket_id='documents' and name='a0710000-0000-4000-8000-000000000011/project/own.pdf'$$,'42501',null,'student cannot rekey an owned Storage object into another student path');
select throws_ok($$update storage.objects set name='a0710000-0000-4000-8000-000000000011-copy.jpg' where bucket_id='avatars' and name='a0710000-0000-4000-8000-000000000011.jpg'$$,'42501',null,'student cannot change an avatar away from the exact allowed path');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='student_storage_delete' and cmd='DELETE' and qual ilike '%my_student_id%'),'student delete policy restricts deletion to the caller-owned path');
reset role;
select ok(exists(select 1 from pg_trigger where tgrelid='storage.objects'::regclass and tgfoid='storage.protect_delete()'::regprocedure and not tgisinternal),'Storage prevents direct table deletes; callers must use the Storage API');

select * from finish();
rollback;
