begin;
select plan(7);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0500000-0000-4000-8000-000000000001','authenticated','authenticated','source-owner@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0500000-0000-4000-8000-000000000002','authenticated','authenticated','source-other@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0500000-0000-4000-8000-000000000001','student'),
 ('a0500000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
 ('a0500000-0000-4000-8000-000000000011','a0500000-0000-4000-8000-000000000001','Synthetic Source Owner','source-owner@demo.aptohire.test'),
 ('a0500000-0000-4000-8000-000000000012','a0500000-0000-4000-8000-000000000002','Synthetic Other Student','source-other@demo.aptohire.test');
insert into public.profile_sources(id,student_id,source_type,token_secret_id) values
 ('a0500000-0000-4000-8000-000000000021','a0500000-0000-4000-8000-000000000011','github','a0500000-0000-4000-8000-000000000031'),
 ('a0500000-0000-4000-8000-000000000022','a0500000-0000-4000-8000-000000000012','github','a0500000-0000-4000-8000-000000000032');

select ok(exists(
  select 1 from pg_policies where schemaname='public' and tablename='profile_sources'
    and policyname='sources_self_read' and cmd='SELECT' and 'authenticated'::name=any(roles)
    and qual ilike '%my_student_id%'
),'sources_self_read scopes profile-source reads to the owner or authorized admin');
select ok(not has_column_privilege('authenticated','public.profile_sources','token_secret_id','SELECT'),'authenticated cannot select the Vault secret reference');
select ok(has_column_privilege('authenticated','public.profile_sources','source_type','SELECT'),'authenticated can select safe source metadata');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0500000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.profile_sources where id='a0500000-0000-4000-8000-000000000021'),1,'student can read own safe profile-source row');
select is((select count(*)::int from public.profile_sources where id='a0500000-0000-4000-8000-000000000022'),0,'student cannot read another student profile-source row');
select throws_ok($$select token_secret_id from public.profile_sources where id='a0500000-0000-4000-8000-000000000021'$$,'42501',null,'attempt to read Vault secret reference is denied');
select throws_ok($$select * from public.profile_sources where id='a0500000-0000-4000-8000-000000000021'$$,'42501',null,'wildcard source read is denied because it includes hidden secret reference');

select * from finish();
rollback;
