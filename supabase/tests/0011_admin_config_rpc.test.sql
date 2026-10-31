begin;
select plan(9);
insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('ab000000-0000-4000-8000-000000000001','authenticated','authenticated','config-admin@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ab000000-0000-4000-8000-000000000002','authenticated','authenticated','config-user@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
 ('ab000000-0000-4000-8000-000000000001','admin'),
 ('ab000000-0000-4000-8000-000000000002','student');
insert into public.app_config(key,value) values('PASS_MARK','50'::jsonb) on conflict(key) do update set value=excluded.value;

select has_function('public','admin_update_config',array['uuid','text','jsonb'],'admin config RPC exists');
select ok(has_function_privilege('service_role','public.admin_update_config(uuid,text,jsonb)','execute'),'service role can call config RPC');
select ok(not has_function_privilege('authenticated','public.admin_update_config(uuid,text,jsonb)','execute'),'authenticated cannot call config RPC directly');
set local role service_role;
select is((select config_key from public.admin_update_config('ab000000-0000-4000-8000-000000000001','PASS_MARK','55'::jsonb)),'PASS_MARK','admin config RPC updates an allowed key');
select throws_ok($$select * from public.admin_update_config('ab000000-0000-4000-8000-000000000001','VIDEO_MAX_SECONDS','9999'::jsonb)$$,'22023',null,'invalid config value is rejected');
select throws_ok($$select * from public.admin_update_config('ab000000-0000-4000-8000-000000000002','PASS_MARK','60'::jsonb)$$,'42501',null,'non-admin actor is rejected');
reset role;
select is((select value from public.app_config where key='PASS_MARK'),'55'::jsonb,'allowed config value persisted');
select is((select updated_by from public.app_config where key='PASS_MARK'),'ab000000-0000-4000-8000-000000000001'::uuid,'config records the admin actor');
select ok(exists(select 1 from public.audit_log where actor_id='ab000000-0000-4000-8000-000000000001' and action='admin_config_updated' and metadata->>'key'='PASS_MARK' and metadata->'new_value'='55'::jsonb),'config change is audited');
select * from finish();
rollback;
