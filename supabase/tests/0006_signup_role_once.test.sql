begin;
select plan(5);
insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('22222222-2222-4222-8222-222222222222','authenticated','authenticated','signup-once@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
set local role service_role;
set local request.jwt.claim.role = 'service_role';
select is(public.set_profile_role_once('22222222-2222-4222-8222-222222222222','student'),'student','first role can be set by service role');
select is(public.set_profile_role_once('22222222-2222-4222-8222-222222222222','student'),'student','same role is idempotent');
select throws_ok($$select public.set_profile_role_once('22222222-2222-4222-8222-222222222222','organization')$$,'23505',null,'different portal role cannot replace first role');
select throws_ok($$select public.set_profile_role_once('22222222-2222-4222-8222-222222222222','admin')$$,'P0001',null,'signup cannot grant the admin role');
reset role;
select ok(not has_function_privilege('authenticated','public.set_profile_role_once(uuid,text)','execute'),'authenticated cannot call privileged role RPC');
select * from finish();
rollback;
