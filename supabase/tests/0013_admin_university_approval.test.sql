begin;
select plan(21);
insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('ad000000-0000-4000-8000-000000000001','authenticated','authenticated','uni-approval-admin@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ad000000-0000-4000-8000-000000000002','authenticated','authenticated','uni-approval-member@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ad000000-0000-4000-8000-000000000003','authenticated','authenticated','roster-student-one@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ad000000-0000-4000-8000-000000000004','authenticated','authenticated','roster-student-two@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
 ('ad000000-0000-4000-8000-000000000001','admin'),
 ('ad000000-0000-4000-8000-000000000002','university'),
 ('ad000000-0000-4000-8000-000000000003','student'),
 ('ad000000-0000-4000-8000-000000000004','student');
insert into public.universities(id,name,status,email_domains)
values
 ('ad000000-0000-4000-8000-000000000010','Fictional Pending University','pending',array['fictional-university.test']),
 ('ad000000-0000-4000-8000-000000000011','Fictional Previous University','approved',array['previous-university.test']),
 ('ad000000-0000-4000-8000-000000000012','Fictional Rejected University','pending',array['rejected-university.test']);
insert into public.university_members(university_id,user_id)
values
 ('ad000000-0000-4000-8000-000000000010','ad000000-0000-4000-8000-000000000002'),
 ('ad000000-0000-4000-8000-000000000012','ad000000-0000-4000-8000-000000000002');
insert into public.students(id,user_id,full_name,primary_email)
values
 ('ad000000-0000-4000-8000-000000000020','ad000000-0000-4000-8000-000000000003','Fictional Student One','roster-student-one@demo.aptohire.test'),
 ('ad000000-0000-4000-8000-000000000021','ad000000-0000-4000-8000-000000000004','Fictional Student Two','roster-student-two@demo.aptohire.test');
insert into public.affiliations(student_id,university_id,verification,program_level,year,status,is_current)
values('ad000000-0000-4000-8000-000000000020','ad000000-0000-4000-8000-000000000011','roster','Bachelors',2,'student',true);
insert into public.roster_entries(id,university_id,email,full_name,program_level,program,year,status)
values
 ('ad000000-0000-4000-8000-000000000030','ad000000-0000-4000-8000-000000000010','roster-student-one@demo.aptohire.test','Student One Roster','Bachelors','Computing',3,'student'),
 ('ad000000-0000-4000-8000-000000000031','ad000000-0000-4000-8000-000000000010','roster-student-two@demo.aptohire.test','Student Two Roster','Bachelors','Design',1,'student'),
 ('ad000000-0000-4000-8000-000000000032','ad000000-0000-4000-8000-000000000010','unmatched@demo.aptohire.test','Unmatched Roster Row','Bachelors','Computing',1,'student');
insert into public.applications(id,reference,type,subject_id,contact_name,contact_email,status)
values
 ('ad000000-0000-4000-8000-000000000040','AH-AD1234','university','ad000000-0000-4000-8000-000000000010','Fictional Contact','uni-approval-member@demo.aptohire.test','received'),
 ('ad000000-0000-4000-8000-000000000041','AH-AD5678','university','ad000000-0000-4000-8000-000000000012','Fictional Contact','uni-approval-member@demo.aptohire.test','received');

select has_function('public','admin_university_action',array['uuid','uuid','text','text'],'university approval RPC exists');
select ok(has_function_privilege('service_role','public.admin_university_action(uuid,uuid,text,text)','execute'),'service role can call university approval RPC');
select ok(not has_function_privilege('authenticated','public.admin_university_action(uuid,uuid,text,text)','execute'),'authenticated cannot call university approval RPC directly');
set local role service_role;
select is((select matched_existing from public.admin_university_action('ad000000-0000-4000-8000-000000000001','ad000000-0000-4000-8000-000000000010','approve',null)),2,'approval matches only existing confirmed-email students');
select is((select proposals_created from public.admin_university_action('ad000000-0000-4000-8000-000000000001','ad000000-0000-4000-8000-000000000010','approve',null)),0,'repeat approval creates no duplicate proposals');
select is((select status from public.universities where id='ad000000-0000-4000-8000-000000000010'),'approved','university is approved');
select ok((select approved_at is not null from public.universities where id='ad000000-0000-4000-8000-000000000010'),'approval timestamp is recorded');
select is((select count(*)::int from public.roster_entries where university_id='ad000000-0000-4000-8000-000000000010' and student_id is not null),2,'matched roster rows are linked without exposing identities in the response');
select ok(exists(select 1 from public.affiliations where student_id='ad000000-0000-4000-8000-000000000021' and university_id='ad000000-0000-4000-8000-000000000010' and verification='roster' and is_current),'student with no current affiliation receives verified roster affiliation');
select ok(exists(select 1 from public.affiliations where student_id='ad000000-0000-4000-8000-000000000020' and university_id='ad000000-0000-4000-8000-000000000011' and is_current),'existing current affiliation is never replaced');
select ok(exists(select 1 from public.affiliation_proposals where student_id='ad000000-0000-4000-8000-000000000020' and university_id='ad000000-0000-4000-8000-000000000010' and state='pending'),'student with a different affiliation receives a proposal');
select ok(exists(select 1 from public.notifications where user_id='ad000000-0000-4000-8000-000000000003' and kind='affiliation_proposal' and payload ? 'proposal_id'),'matched student is notified of the proposal');
select ok(exists(select 1 from public.notifications where user_id='ad000000-0000-4000-8000-000000000002' and kind='application_decided' and payload->>'status'='approved'),'university members receive application decision notification');
select ok(exists(select 1 from public.notifications where user_id='ad000000-0000-4000-8000-000000000002' and kind='roster_matched' and payload->>'matched_existing'='2'),'university receives count-only roster match notification');
select ok(not exists(select 1 from public.notifications where kind='application_decided' and payload ?| array['student_id','email','full_name']),'university decision notification has no student identity fields');
select is((select status::text from public.applications where reference='AH-AD1234'),'approved','related application is approved');
select ok(exists(select 1 from public.audit_log where actor_id='ad000000-0000-4000-8000-000000000001' and action='admin_university_decided' and metadata->>'matched_existing'='2'),'decision is audited using aggregate counts');
select is((select status||':'||matched_existing::text||':'||proposals_created::text from public.admin_university_action('ad000000-0000-4000-8000-000000000001','ad000000-0000-4000-8000-000000000012','reject','Please verify institutional details.')),'rejected:0:0','rejection returns no matched identity counts');
select is((select status_note from public.universities where id='ad000000-0000-4000-8000-000000000012'),'Please verify institutional details.','rejection note is stored for the applicant');
select is((select status::text from public.applications where reference='AH-AD5678'),'rejected','rejected decision updates the application');
select is((select count(*)::int from public.roster_entries where university_id='ad000000-0000-4000-8000-000000000012' and student_id is not null),0,'rejection does not trigger roster matching');
reset role;
select * from finish();
rollback;
