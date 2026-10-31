begin;
select plan(11);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0510000-0000-4000-8000-000000000001','authenticated','authenticated','admin-storage@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0510000-0000-4000-8000-000000000002','authenticated','authenticated','student-storage@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0510000-0000-4000-8000-000000000001','admin'),
 ('a0510000-0000-4000-8000-000000000002','student');
insert into storage.objects(bucket_id,name) values
 ('videos','a0510000-0000-4000-8000-000000000002/submission-review/demo.mp4'),
 ('documents','a0510000-0000-4000-8000-000000000002/sources/resume.pdf'),
 ('avatars','a0510000-0000-4000-8000-000000000002.jpg'),
 ('resumes','a0510000-0000-4000-8000-000000000002/resume.pdf');

select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='admin_review_media_select' and cmd='SELECT' and roles @> array['authenticated']::name[]),'admin media policy exists for authenticated SELECT');
select ok((select qual ilike '%private.is_admin%' and qual ilike '%videos%' and qual ilike '%documents%' from pg_policies where schemaname='storage' and tablename='objects' and policyname='admin_review_media_select'),'admin policy gates AAL2 and restricts media buckets');
select ok((select relrowsecurity from pg_class where oid='storage.objects'::regclass),'Storage metadata SELECT is protected by RLS even though the managed schema retains platform ACLs');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0510000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from storage.objects where bucket_id in ('videos','documents')),0,'aal1 admin cannot read review media metadata');

select set_config('request.jwt.claims','{"sub":"a0510000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::int from storage.objects where bucket_id in ('videos','documents')),2,'aal2 admin can read video and document metadata to mint signed URLs');
select is((select count(*)::int from storage.objects where bucket_id in ('avatars','resumes','rosters')),0,'aal2 admin policy does not expose other buckets');

select set_config('request.jwt.claims','{"sub":"a0510000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from storage.objects where bucket_id in ('videos','documents')),0,'non-owner student cannot read another student review media');
select is((select count(*)::int from storage.objects where bucket_id in ('avatars','resumes')),0,'non-owner student cannot read another student avatar or resume');
select ok(has_table_privilege('authenticated','storage.objects','select'),'authenticated role has the SELECT privilege needed for Storage reads');
select ok(not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='admin_review_media_select' and cmd <> 'SELECT'),'admin media policy grants no Storage write operation');
select ok(not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='admin_review_media_select' and (with_check is not null)),'admin media SELECT policy has no write check');

select * from finish();
rollback;
