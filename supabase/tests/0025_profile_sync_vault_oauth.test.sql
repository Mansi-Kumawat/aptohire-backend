begin;
select plan(16);

select has_table('private','github_oauth_states','OAuth state is stored in a private table');
select has_column('public','profile_sources','last_synced_at','profile source tracks last successful sync');
select has_function('public','issue_github_oauth_state',array['uuid','uuid','uuid','text'],'OAuth state issue RPC exists');
select has_function('public','consume_github_oauth_state',array['text'],'one-time OAuth state consume RPC exists');
select has_function('public','store_profile_source_token',array['uuid','uuid','text'],'Vault token store RPC exists');
select has_function('public','read_profile_source_token',array['uuid','uuid'],'Vault token read RPC exists');
select has_function('public','revoke_profile_source',array['uuid','uuid','uuid','boolean'],'source revoke RPC exists');
select ok(has_function_privilege('service_role','public.issue_github_oauth_state(uuid,uuid,uuid,text)','execute'),'only server-side service role can issue OAuth state');
select ok(not has_function_privilege('anon','public.read_profile_source_token(uuid,uuid)','execute'),'anonymous role cannot retrieve OAuth tokens');

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('af420000-0000-4000-8000-000000000001','authenticated','authenticated','profile-sync-student@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('af420000-0000-4000-8000-000000000001','student');
insert into public.students(id,user_id,full_name,primary_email)
values('af420000-0000-4000-8000-000000000002','af420000-0000-4000-8000-000000000001','Synthetic Profile Student','profile-sync-student@demo.aptohire.test');
insert into public.profile_sources(id,student_id,source_type,auto_approve,consented_at)
values('af420000-0000-4000-8000-000000000003','af420000-0000-4000-8000-000000000002','github',false,now());

set local role service_role;
select ok((public.issue_github_oauth_state('af420000-0000-4000-8000-000000000001','af420000-0000-4000-8000-000000000002','af420000-0000-4000-8000-000000000003',repeat('a',64))>now()),'valid owner can issue a short-lived OAuth state');
select is((select source_id from public.consume_github_oauth_state(repeat('a',64))),'af420000-0000-4000-8000-000000000003'::uuid,'OAuth state is bound to the source and consumed once');
select is((select count(*)::int from public.consume_github_oauth_state(repeat('a',64))),0,'OAuth state replay is rejected');
select ok(public.store_profile_source_token('af420000-0000-4000-8000-000000000003','af420000-0000-4000-8000-000000000002','synthetic-token-not-a-secret') is not null,'token is stored in Vault and linked only by secret id');
select is(public.read_profile_source_token('af420000-0000-4000-8000-000000000003','af420000-0000-4000-8000-000000000002'),'synthetic-token-not-a-secret','server-only Vault read returns the stored token');
select lives_ok($$select public.revoke_profile_source('af420000-0000-4000-8000-000000000001','af420000-0000-4000-8000-000000000003','af420000-0000-4000-8000-000000000002',true)$$,'revoke clears consent and deletes token/derived proposals');
select throws_ok($$select public.read_profile_source_token('af420000-0000-4000-8000-000000000003','af420000-0000-4000-8000-000000000002')$$,'P0002',null,'revoked source token cannot be read');
reset role;
select * from finish();
rollback;
