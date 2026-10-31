begin;
select plan(11);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('e0760000-0000-4000-8000-000000000001','authenticated','authenticated','university-applicant@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('e0760000-0000-4000-8000-000000000002','authenticated','authenticated','organization-applicant@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('e0760000-0000-4000-8000-000000000007','authenticated','authenticated','unconfirmed-applicant@demo.aptohire.test',null,extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.universities(id,name,status)
values('e0760000-0000-4000-8000-000000000003','Pending Synthetic University','pending');
insert into public.organizations(id,name,status)
values('e0760000-0000-4000-8000-000000000004','Pending Synthetic Organization','pending');
insert into public.applications(id,reference,type,subject_id,contact_name,contact_email,status)
values
 ('e0760000-0000-4000-8000-000000000005','AH-T076U1','university','e0760000-0000-4000-8000-000000000003','Synthetic Contact','university-applicant@demo.aptohire.test','received'),
 ('e0760000-0000-4000-8000-000000000006','AH-T076O2','organization','e0760000-0000-4000-8000-000000000004','Synthetic Contact','organization-applicant@demo.aptohire.test','received');

select has_function('public','claim_signup_application',array['uuid','uuid','text','text'],'atomic signup application claim RPC exists');
select ok(not has_function_privilege('authenticated','public.claim_signup_application(uuid,uuid,text,text)','execute'),'authenticated users cannot invoke privileged application claim');
select is(public.claim_signup_application('e0760000-0000-4000-8000-000000000005','e0760000-0000-4000-8000-000000000001','university','university-applicant@demo.aptohire.test'),true,'verified university applicant is attached atomically');
select is((select claimed_user_id from public.applications where id='e0760000-0000-4000-8000-000000000005'),'e0760000-0000-4000-8000-000000000001'::uuid,'application records the claiming user');
select is((select member_role from public.university_members where university_id='e0760000-0000-4000-8000-000000000003' and user_id='e0760000-0000-4000-8000-000000000001'),'applicant','university member receives applicant role');
select ok(public.claim_signup_application('e0760000-0000-4000-8000-000000000005','e0760000-0000-4000-8000-000000000001','university','university-applicant@demo.aptohire.test')
  and (select count(*)=1 from public.university_members where university_id='e0760000-0000-4000-8000-000000000003' and user_id='e0760000-0000-4000-8000-000000000001'),'same-user retry is idempotent');
select is(public.claim_signup_application('e0760000-0000-4000-8000-000000000006','e0760000-0000-4000-8000-000000000002','organization','organization-applicant@demo.aptohire.test'),true,'verified organization applicant is attached atomically');
select is((select member_role from public.organization_members where organization_id='e0760000-0000-4000-8000-000000000004' and user_id='e0760000-0000-4000-8000-000000000002'),'applicant','organization member receives applicant role');
select is(public.claim_signup_application('e0760000-0000-4000-8000-000000000005','e0760000-0000-4000-8000-000000000002','university','organization-applicant@demo.aptohire.test'),false,'mismatched email cannot claim another application');
select is(public.claim_signup_application('e0760000-0000-4000-8000-000000000005','e0760000-0000-4000-8000-000000000007','university','university-applicant@demo.aptohire.test'),false,'unconfirmed account cannot claim an application even with a supplied matching address');
update public.universities set status='approved' where id='e0760000-0000-4000-8000-000000000003';
select is(public.claim_signup_application('e0760000-0000-4000-8000-000000000005','e0760000-0000-4000-8000-000000000001','university','university-applicant@demo.aptohire.test'),false,'approved subject cannot be claimed through pending-application signup flow');

select * from finish();
rollback;
