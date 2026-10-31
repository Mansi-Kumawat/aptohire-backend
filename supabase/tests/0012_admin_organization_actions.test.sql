begin;
select plan(19);
insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('ac000000-0000-4000-8000-000000000001','authenticated','authenticated','org-action-admin@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ac000000-0000-4000-8000-000000000002','authenticated','authenticated','org-action-member@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ac000000-0000-4000-8000-000000000003','authenticated','authenticated','org-action-student@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
 ('ac000000-0000-4000-8000-000000000001','admin'),
 ('ac000000-0000-4000-8000-000000000002','organization'),
 ('ac000000-0000-4000-8000-000000000003','student');
insert into public.organizations(id,name,status,subscription_status)
values
 ('ac000000-0000-4000-8000-000000000010','Fictional Pending Employer','pending','inactive'),
 ('ac000000-0000-4000-8000-000000000011','Fictional Rejected Employer','pending','inactive');
insert into public.organization_members(organization_id,user_id)
values
 ('ac000000-0000-4000-8000-000000000010','ac000000-0000-4000-8000-000000000002'),
 ('ac000000-0000-4000-8000-000000000011','ac000000-0000-4000-8000-000000000002');
insert into public.applications(id,reference,type,subject_id,contact_name,contact_email,status)
values
 ('ac000000-0000-4000-8000-000000000020','AH-AC1234','organization','ac000000-0000-4000-8000-000000000010','Fictional Contact','fictional-contact@demo.aptohire.test','received'),
 ('ac000000-0000-4000-8000-000000000021','AH-AC5678','organization','ac000000-0000-4000-8000-000000000011','Fictional Contact','fictional-contact2@demo.aptohire.test','received');

select has_function('public','admin_organization_action',array['uuid','uuid','text','text','text'],'organization action RPC exists');
select ok(has_function_privilege('service_role','public.admin_organization_action(uuid,uuid,text,text,text)','execute'),'service role can call organization action RPC');
select ok(not has_function_privilege('authenticated','public.admin_organization_action(uuid,uuid,text,text,text)','execute'),'authenticated cannot call organization action RPC directly');
set local role service_role;
select is((select status from public.admin_organization_action('ac000000-0000-4000-8000-000000000001','ac000000-0000-4000-8000-000000000010','approve_org','approve',null)),'approved','admin approval accepts the approved decision');
select is((select status from public.organizations where id='ac000000-0000-4000-8000-000000000010'),'approved','organization status becomes approved');
select ok((select verified_at is not null from public.organizations where id='ac000000-0000-4000-8000-000000000010'),'approval records verification time');
select is((select status::text from public.applications where reference='AH-AC1234'),'approved','related application is decided');
select ok(exists(select 1 from public.notifications where user_id='ac000000-0000-4000-8000-000000000002' and kind='application_decided' and payload->>'organization_id'='ac000000-0000-4000-8000-000000000010'),'organization member receives a decision notification');
select ok(not exists(select 1 from public.notifications where kind='application_decided' and payload ?| array['student_id','email','full_name','contact_name']),'decision notification has no identity fields');
select ok(exists(select 1 from public.audit_log where actor_id='ac000000-0000-4000-8000-000000000001' and action='admin_org_decided' and target_id='ac000000-0000-4000-8000-000000000010'),'approval is audited');
select is((select subscription_status from public.admin_organization_action('ac000000-0000-4000-8000-000000000001','ac000000-0000-4000-8000-000000000010','set_subscription','inactive',null)),'inactive','subscription action accepts inactive status');
select is((select subscription_status from public.organizations where id='ac000000-0000-4000-8000-000000000010'),'inactive','subscription status is persisted');
select ok(exists(select 1 from public.notifications where user_id='ac000000-0000-4000-8000-000000000002' and kind='subscription_changed' and payload->>'subscription_status'='inactive'),'subscription change notification is emitted');
select is((select status from public.admin_organization_action('ac000000-0000-4000-8000-000000000001','ac000000-0000-4000-8000-000000000011','approve_org','reject','Please update the company website.')),'rejected','admin rejection is supported');
select is((select status from public.organizations where id='ac000000-0000-4000-8000-000000000011'),'rejected','rejection persists status');
select is((select status_note from public.organizations where id='ac000000-0000-4000-8000-000000000011'),'Please update the company website.','rejection note is stored');
select is((select status::text from public.applications where reference='AH-AC5678'),'rejected','related application is rejected');
select throws_ok($$select * from public.admin_organization_action('ac000000-0000-4000-8000-000000000001','ac000000-0000-4000-8000-000000000010','approve_org','pending',null)$$,'22023',null,'invalid organization decision is rejected');
select throws_ok($$select * from public.admin_organization_action('ac000000-0000-4000-8000-000000000003','ac000000-0000-4000-8000-000000000010','approve_org','reject',null)$$,'42501',null,'non-admin actor is rejected');
reset role;
select * from finish();
rollback;
