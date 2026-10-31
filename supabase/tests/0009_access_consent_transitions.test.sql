begin;
select plan(16);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','authenticated','authenticated','consent-student@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','authenticated','authenticated','consent-org@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.students(id,user_id,full_name,primary_email)
values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Fictional Consent Student','consent-student@demo.aptohire.test');
insert into public.organizations(id,name,status,subscription_status)
values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','Fictional Consent Employer','approved','active');
insert into public.organization_members(organization_id,user_id)
values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Synthetic Role','Fixture','open','[]'::jsonb,1);
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,duration_days,status)
values('11111111-2222-4111-8111-111111111111','dddddddd-dddd-4ddd-8ddd-dddddddddddd','cccccccc-cccc-4ccc-8ccc-cccccccccccc','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',array['profile','scorecard'],30,'pending');

select has_function('public','respond_access',array['uuid','uuid','uuid','text','text[]','integer'],'respond RPC exists');
select has_function('public','withdraw_access',array['uuid','uuid','uuid'],'withdraw RPC exists');
select ok(not has_function_privilege('authenticated','public.respond_access(uuid,uuid,uuid,text,text[],integer)','execute'),'authenticated cannot call response RPC');
select ok(not has_function_privilege('authenticated','public.withdraw_access(uuid,uuid,uuid)','execute'),'authenticated cannot call withdraw RPC');
select is((public.respond_access('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-2222-4111-8111-111111111111','accept',array['profile'],7)->>'status'),'accepted','student can grant a requested scope');
select ok((select expires_at>now() from public.access_requests where id='11111111-2222-4111-8111-111111111111'),'accepted grant expires in the future');
select ok(exists(select 1 from public.notifications where user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' and kind='access_accepted' and payload->>'request_id'='11111111-2222-4111-8111-111111111111'),'organization is notified on accept');
select ok(not exists(select 1 from public.notifications where kind='access_accepted' and payload ?| array['student_id','email','full_name']),'organization consent notification has no identity fields');
select is((public.withdraw_access('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-2222-4111-8111-111111111111')->>'status'),'withdrawn','student can withdraw consent');
select ok((select status='withdrawn' and granted_scope='{}'::text[] and expires_at<=now() from public.access_requests where id='11111111-2222-4111-8111-111111111111'),'withdrawal immediately clears scopes and ends the grant');
select ok(exists(select 1 from public.notifications where user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' and kind='access_withdrawn' and payload->>'request_id'='11111111-2222-4111-8111-111111111111'),'organization is notified on withdrawal');
select throws_ok($$select public.withdraw_access('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-2222-4111-8111-111111111111')$$,'40001',null,'withdrawal cannot be repeated');
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,duration_days,status)
values('22222222-3333-4222-8333-222222222222','dddddddd-dddd-4ddd-8ddd-dddddddddddd','cccccccc-cccc-4ccc-8ccc-cccccccccccc','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',array['profile'],30,'pending');
select is((public.respond_access('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-3333-4222-8333-222222222222','decline',null,null)->>'status'),'declined','student can decline a pending request');
select ok((select status='declined' and granted_scope='{}'::text[] and expires_at is null from public.access_requests where id='22222222-3333-4222-8333-222222222222'),'declined request carries no grant');
select ok(exists(select 1 from public.notifications where user_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' and kind='access_declined' and payload->>'request_id'='22222222-3333-4222-8333-222222222222'),'organization is notified on decline');
select ok(not exists(select 1 from public.notifications where kind='access_declined' and payload ?| array['student_id','email','full_name']),'decline notification does not expose student identity');

select * from finish();
rollback;
