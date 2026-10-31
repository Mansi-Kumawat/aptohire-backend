begin;
select plan(5);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0690000-0000-4000-8000-000000000001','authenticated','authenticated','audit-admin@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0690000-0000-4000-8000-000000000002','authenticated','authenticated','audit-student@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0690000-0000-4000-8000-000000000001','admin'),
 ('a0690000-0000-4000-8000-000000000002','student');
insert into public.audit_log(id,actor_id,action,target_type,metadata) values
 ('a0690000-0000-4000-8000-000000000011','a0690000-0000-4000-8000-000000000001','fixture_event','fixture','{}');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='audit_log'
 and policyname='audit_admin_read' and cmd='SELECT' and 'authenticated'::name=any(roles)),
 'audit_admin_read policy is the admin audit-log read gate');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0690000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::int from public.audit_log),0,'student cannot read admin audit log even at aal2');
select set_config('request.jwt.claims','{"sub":"a0690000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.audit_log),0,'aal1 admin cannot read audit log');
select set_config('request.jwt.claims','{"sub":"a0690000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::int from public.audit_log where id='a0690000-0000-4000-8000-000000000011'),1,'aal2 admin can read audit log entry');
select ok(not has_table_privilege('authenticated','public.audit_log','update')
 and not has_table_privilege('authenticated','public.audit_log','delete'),'audit log is not mutable by browser users');
select * from finish();
rollback;
