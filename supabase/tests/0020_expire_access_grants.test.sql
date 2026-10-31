begin;
select plan(10);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a0380000-0000-4000-8000-000000000001','authenticated','authenticated','expire-student@demo.aptohire.test',now(),extensions.crypt('fictional-password',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
('a0380000-0000-4000-8000-000000000002','authenticated','authenticated','expire-org@demo.aptohire.test',now(),extensions.crypt('fictional-password',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
('a0380000-0000-4000-8000-000000000001','student'),
('a0380000-0000-4000-8000-000000000002','organization');
insert into public.students(id,user_id,full_name,primary_email)
values('a0380000-0000-4000-8000-000000000003','a0380000-0000-4000-8000-000000000001','Fictional Expiry Student','expire-student@demo.aptohire.test');
insert into public.organizations(id,name,status,subscription_status)
values('a0380000-0000-4000-8000-000000000004','Fictional Expiry Organization','approved','active');
insert into public.organization_members(organization_id,user_id,member_role)
values('a0380000-0000-4000-8000-000000000004','a0380000-0000-4000-8000-000000000002','member');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings) values
('a0380000-0000-4000-8000-000000000005','a0380000-0000-4000-8000-000000000004','Synthetic Expiry Role','Fictional fixture','open','[]'::jsonb,1),
('a0380000-0000-4000-8000-000000000008','a0380000-0000-4000-8000-000000000004','Synthetic Future Role','Fictional fixture','open','[]'::jsonb,1);
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,granted_scope,duration_days,status,expires_at)
values
('a0380000-0000-4000-8000-000000000006','a0380000-0000-4000-8000-000000000004','a0380000-0000-4000-8000-000000000003','a0380000-0000-4000-8000-000000000005',array['profile'],array['profile'],7,'accepted',now()-interval '1 hour'),
('a0380000-0000-4000-8000-000000000007','a0380000-0000-4000-8000-000000000004','a0380000-0000-4000-8000-000000000003','a0380000-0000-4000-8000-000000000008',array['profile'],array['profile'],7,'accepted',now()+interval '1 day');

select has_function('public','expire_access_grants',array[]::text[],'grant expiry RPC exists');
select ok(has_function_privilege('service_role','public.expire_access_grants()','execute'),'service role can execute expiry RPC');
select ok(not has_function_privilege('authenticated','public.expire_access_grants()','execute'),'authenticated cannot execute expiry RPC');
select is(public.expire_access_grants(),1,'expired accepted grant is processed exactly once');
select ok((select status='expired' and granted_scope='{}'::text[] from public.access_requests where id='a0380000-0000-4000-8000-000000000006'),'expired grant loses all granted scopes');
select ok((select status='accepted' and granted_scope=array['profile']::text[] from public.access_requests where id='a0380000-0000-4000-8000-000000000007'),'future grant remains active');
select ok(exists(select 1 from public.notifications where user_id='a0380000-0000-4000-8000-000000000001' and kind='access_expiring' and payload->>'request_id'='a0380000-0000-4000-8000-000000000006'),'student receives an expiry notification');
select ok(exists(select 1 from public.notifications where user_id='a0380000-0000-4000-8000-000000000002' and kind='access_expiring' and payload->>'request_id'='a0380000-0000-4000-8000-000000000006' and not (payload ? 'student_id')),'organization receives identity-free expiry notification');
select ok(exists(select 1 from public.audit_log where action='access_grant_expired' and target_id='a0380000-0000-4000-8000-000000000006' and actor_id is null),'system expiry is append-only audited without an actor identity');
select ok(public.expire_access_grants()=0 and (select count(*)=2 from public.notifications where payload->>'request_id'='a0380000-0000-4000-8000-000000000006'),'repeat run is idempotent and does not duplicate notifications');
select * from finish();
rollback;
