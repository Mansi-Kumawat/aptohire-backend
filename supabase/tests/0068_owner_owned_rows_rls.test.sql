begin;
select plan(7);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0680000-0000-4000-8000-000000000001','authenticated','authenticated','owner-rows-a@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0680000-0000-4000-8000-000000000002','authenticated','authenticated','owner-rows-b@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.notifications(id,user_id,kind,payload) values
 ('a0680000-0000-4000-8000-000000000011','a0680000-0000-4000-8000-000000000001','audit_ready','{}'),
 ('a0680000-0000-4000-8000-000000000012','a0680000-0000-4000-8000-000000000002','audit_ready','{}');
insert into public.agent_runs(id,user_id,stage,status,mode) values
 ('a0680000-0000-4000-8000-000000000021','a0680000-0000-4000-8000-000000000001','received','queued','mock'),
 ('a0680000-0000-4000-8000-000000000022','a0680000-0000-4000-8000-000000000002','received','queued','mock');

select is((select count(*)::int from pg_policies where schemaname='public' and 'authenticated'::name=any(roles)
 and ((tablename='notifications' and policyname='notification_owner_select' and cmd='SELECT')
 or (tablename='agent_runs' and policyname='run_owner_select' and cmd='SELECT'))),2,
 'notification and agent-run ownership policies are present');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0680000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.notifications where id='a0680000-0000-4000-8000-000000000011'),1,'user can read own notification');
select is((select count(*)::int from public.notifications where id='a0680000-0000-4000-8000-000000000012'),0,'user cannot read another user notification');
select is((select count(*)::int from public.agent_runs where id='a0680000-0000-4000-8000-000000000021'),1,'user can read own agent run');
select is((select count(*)::int from public.agent_runs where id='a0680000-0000-4000-8000-000000000022'),0,'user cannot read another user agent run');
select set_config('request.jwt.claims','{"sub":"a0680000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.notifications where id='a0680000-0000-4000-8000-000000000012'),1,'second user can read their own notification');
select is((select count(*)::int from public.agent_runs where id='a0680000-0000-4000-8000-000000000022'),1,'second user can read their own agent run');

select * from finish();
rollback;
