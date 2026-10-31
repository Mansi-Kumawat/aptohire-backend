begin;
select plan(10);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0940000-0000-4000-8000-000000000001','authenticated','authenticated','atomic-consent-student@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('a0940000-0000-4000-8000-000000000002','authenticated','authenticated','atomic-consent-org@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.students(id,user_id,full_name,primary_email,visibility)
values('b0940000-0000-4000-8000-000000000001','a0940000-0000-4000-8000-000000000001','Fictional Atomic Consent Student','atomic-consent-student@demo.aptohire.test','{"discoverable":true,"public_verify":["skills","levels"],"university_files":false}'::jsonb);
insert into public.organizations(id,name,status,subscription_status)
values('c0940000-0000-4000-8000-000000000001','Fictional Atomic Consent Employer','approved','active');
insert into public.organization_members(organization_id,user_id)
values('c0940000-0000-4000-8000-000000000001','a0940000-0000-4000-8000-000000000002');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('d0940000-0000-4000-8000-000000000001','c0940000-0000-4000-8000-000000000001','Synthetic Consent Role','Fixture','open','[]'::jsonb,1);
insert into public.skill_families(id,slug,name)
values('e0940000-0000-4000-8000-000000000001','phase6-family-094','Synthetic Phase Six');
insert into public.skills(id,family_id,slug,name)
values('f0940000-0000-4000-8000-000000000001','e0940000-0000-4000-8000-000000000001','phase6-skill-094','Synthetic Verified Skill');
-- A student trigger creates its candidate_profiles row; update it rather than inserting a duplicate.
update public.candidate_profiles set discoverable=true
where student_id='b0940000-0000-4000-8000-000000000001';
insert into public.skill_scores(student_id,skill_id,score,level,verified,share_ok,pending_review)
values('b0940000-0000-4000-8000-000000000001','f0940000-0000-4000-8000-000000000001',70,'Competent',true,true,false);
insert into public.match_results(id,job_id,student_id,alias,final_score,confidence,reasons,gaps)
values('00940000-0000-4000-8000-000000000001','d0940000-0000-4000-8000-000000000001','b0940000-0000-4000-8000-000000000001','Candidate ABC234',70,0.8,array['Verified skill'],array[]::text[]);

select has_function('public','create_access_request',array['uuid','uuid','text','text[]','integer'],'atomic access-request RPC exists');
select ok(has_function_privilege('service_role','public.create_access_request(uuid,uuid,text,text[],integer)','execute'),'service role can invoke atomic request creation');
select ok(not has_function_privilege('anon','public.create_access_request(uuid,uuid,text,text[],integer)','execute'),'anon cannot invoke atomic request creation');
select ok(not has_function_privilege('authenticated','public.create_access_request(uuid,uuid,text,text[],integer)','execute'),'authenticated cannot bypass Edge validation and rate limits');

select matches((public.create_access_request('a0940000-0000-4000-8000-000000000002','00940000-0000-4000-8000-000000000001','Synthetic role interest',array['profile','scorecard'],30))::text,'^[0-9a-f-]{36}$','atomic RPC returns request UUID');
select ok(exists(select 1 from public.access_requests where organization_id='c0940000-0000-4000-8000-000000000001' and student_id='b0940000-0000-4000-8000-000000000001' and job_id='d0940000-0000-4000-8000-000000000001' and status='pending' and granted_scope='{}' and requested_scope=array['profile','scorecard']),'request is pending with requested scopes but no grant');
select ok(exists(select 1 from public.notifications where user_id='a0940000-0000-4000-8000-000000000001' and kind='access_request') and not exists(select 1 from public.notifications where user_id='a0940000-0000-4000-8000-000000000001' and kind='access_request' and payload ?| array['student_id','email','full_name']),'student notification is created with identity-minimal payload');
select ok(exists(select 1 from public.audit_log where action='access_request_created' and target_type='access_request' and metadata ? 'job_id') and not exists(select 1 from public.audit_log where action='access_request_created' and metadata ?| array['email','student_email','full_name','message']),'request audit event is minimized');
select throws_ok($$select public.create_access_request('a0940000-0000-4000-8000-000000000002','00940000-0000-4000-8000-000000000001',null,array['profile'],30)$$,'23505',null,'a second active request is rejected');
update public.jobs set status='closed' where id='d0940000-0000-4000-8000-000000000001';
select throws_ok($$select public.create_access_request('a0940000-0000-4000-8000-000000000002','00940000-0000-4000-8000-000000000001',null,array['profile'],30)$$,'40001',null,'closed jobs cannot receive new consent requests');

select * from finish();
rollback;
