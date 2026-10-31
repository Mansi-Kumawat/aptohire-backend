begin;
select plan(6);
insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('11111111-1111-4111-8111-111111111111','authenticated','authenticated','delta-admin@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{"full_name":"Delta Admin"}'::jsonb,now(),now());
insert into public.profiles(id,role) values('11111111-1111-4111-8111-111111111111','admin');
select ok(not has_table_privilege('anon','public.admin_users_v','select'),'anon cannot select admin user view');
select ok(has_table_privilege('authenticated','public.admin_users_v','select'),'authenticated can reach gated admin view');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal1"}',true);
select ok(not private.is_admin(),'aal1 admin profile is denied');
select is((select count(*)::int from public.admin_users_v),0,'aal1 admin sees no admin users');
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","aal":"aal2"}',true);
select ok(private.is_admin(),'aal2 admin profile is authorized');
select is((select count(*)::int from public.admin_users_v where user_id='11111111-1111-4111-8111-111111111111'),1,'aal2 admin can read the gated admin view');
select * from finish();
rollback;
