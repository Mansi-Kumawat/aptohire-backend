begin;
select plan(9);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('af450000-0000-4000-8000-000000000001','authenticated','authenticated','expiring-student@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
('af450000-0000-4000-8000-000000000002','authenticated','authenticated','expiring-org@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('af450000-0000-4000-8000-000000000001','student'),('af450000-0000-4000-8000-000000000002','organization');
insert into public.students(id,user_id,full_name,primary_email) values('af450000-0000-4000-8000-000000000010','af450000-0000-4000-8000-000000000001','Synthetic Expiring Student','expiring-student@demo.aptohire.test');
insert into public.organizations(id,name,status,subscription_status) values('af450000-0000-4000-8000-000000000020','Synthetic Expiring Org','approved','active');
insert into public.organization_members(id,organization_id,user_id,member_role) values('af450000-0000-4000-8000-000000000021','af450000-0000-4000-8000-000000000020','af450000-0000-4000-8000-000000000002','member');
insert into public.jobs(id,organization_id,title,description,status,required_skills) values
('af450000-0000-4000-8000-000000000030','af450000-0000-4000-8000-000000000020','Synthetic Role','Fictional job','open','[]'::jsonb),
('af450000-0000-4000-8000-000000000031','af450000-0000-4000-8000-000000000020','Synthetic Second Role','Fictional job','open','[]'::jsonb);
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,granted_scope,duration_days,status,expires_at,responded_at)
values('af450000-0000-4000-8000-000000000040','af450000-0000-4000-8000-000000000020','af450000-0000-4000-8000-000000000010','af450000-0000-4000-8000-000000000030',array['profile'],array['profile'],30,'accepted',now()+interval '2 days',now()),
('af450000-0000-4000-8000-000000000041','af450000-0000-4000-8000-000000000020','af450000-0000-4000-8000-000000000010','af450000-0000-4000-8000-000000000031',array['profile'],array['profile'],30,'accepted',now()+interval '4 days',now());

select has_function('public','notify_access_expiring',array[]::text[],'daily access-expiry notifier exists');
select ok(has_function_privilege('service_role','public.notify_access_expiring()','execute'),'service role can run the expiry notifier');
select ok(not has_function_privilege('anon','public.notify_access_expiring()','execute'),'anonymous callers cannot invoke the expiry notifier');
set local role service_role;
select is(public.notify_access_expiring(),1,'only accepted grant expiring within three days is notified');
select ok(exists(select 1 from public.notifications where user_id='af450000-0000-4000-8000-000000000001' and kind='access_expiring' and payload->>'request_id'='af450000-0000-4000-8000-000000000040' and payload->>'status'='expiring'),'student gets expiring notice');
select ok(exists(select 1 from public.notifications where user_id='af450000-0000-4000-8000-000000000002' and kind='access_expiring' and payload->>'request_id'='af450000-0000-4000-8000-000000000040' and not (payload ? 'student_id')),'organization gets an identity-free expiring notice');
select ok(exists(select 1 from public.audit_log where action='access_grant_expiring' and target_id='af450000-0000-4000-8000-000000000040'),'expiring notice is audited');
select is(public.notify_access_expiring(),0,'repeat daily run is idempotent');
select is((select count(*)::int from public.notifications where kind='access_expiring' and payload->>'request_id'='af450000-0000-4000-8000-000000000040'),2,'replay does not duplicate either notice');
reset role;
select * from finish();
rollback;
