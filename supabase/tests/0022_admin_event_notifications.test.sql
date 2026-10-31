begin;
select plan(18);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('af390000-0000-4000-8000-000000000001','authenticated','authenticated',
        'notification-admin@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),
        '{}'::jsonb,'{}'::jsonb,now(),now()),
 ('af390000-0000-4000-8000-000000000002','authenticated','authenticated',
        'notification-tpo@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),
        '{}'::jsonb,'{}'::jsonb,now(),now()),
 ('af390000-0000-4000-8000-000000000003','authenticated','authenticated',
        'notification-claim@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),
        '{}'::jsonb,'{}'::jsonb,now(),now()),
 ('af390000-0000-4000-8000-000000000004','authenticated','authenticated',
        'notification-audit-student@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),
        '{}'::jsonb,'{}'::jsonb,now(),now()),
 ('af390000-0000-4000-8000-000000000005','authenticated','authenticated',
        'notification-claim2@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),
        '{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role)
values ('af390000-0000-4000-8000-000000000001','admin'),
       ('af390000-0000-4000-8000-000000000002','university'),
       ('af390000-0000-4000-8000-000000000003','student'),
       ('af390000-0000-4000-8000-000000000004','student'),
       ('af390000-0000-4000-8000-000000000005','student');
insert into public.universities(id,name,status)
values ('af390000-0000-4000-8000-000000000030','Fictional Notification University','approved');
insert into public.university_members(university_id,user_id,member_role)
values ('af390000-0000-4000-8000-000000000030','af390000-0000-4000-8000-000000000002','tpo');

select has_function('private','notify_application_received',array[]::text[],'application notification trigger function exists');
select has_function('private','notify_agent_run_failed',array[]::text[],'failed-run notification trigger function exists');

insert into public.applications(id,reference,type,subject_id,contact_name,contact_role,contact_email,payload,status)
values ('af390000-0000-4000-8000-000000000010','AH-TEST39','university',null,
        'Fictional Applicant','TPO','applicant@fictional.test','{}'::jsonb,'received');
select ok(exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000001'
    and n.kind='application_received'
    and n.payload->>'application_id'='af390000-0000-4000-8000-000000000010'
    and n.payload->>'reference'='AH-TEST39'
    and n.payload->>'application_type'='university'
),'received application notifies admins with safe identifiers');
select ok(not exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000001'
    and n.kind='application_received'
    and (n.payload ? 'contact_email' or n.payload ? 'contact_name')
),'application notification omits applicant identity and contact data');

insert into public.agent_runs(id,stage,status,error_code)
values ('af390000-0000-4000-8000-000000000020','scoring','failed','PRIVATE_PROVIDER_ERROR_TEXT');
select ok(exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000001'
    and n.kind='run_failed'
    and n.payload->>'run_id'='af390000-0000-4000-8000-000000000020'
    and n.payload->>'stage'='scoring'
    and n.payload->>'status'='failed'
),'failed run notifies admins with run id and stage');
select ok(not exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000001'
    and n.kind='run_failed'
    and n.payload::text like '%PRIVATE_PROVIDER_ERROR_TEXT%'
),'failed-run notification excludes potentially sensitive error text');

insert into public.students(id,user_id,full_name,primary_email)
values ('af390000-0000-4000-8000-000000000040','af390000-0000-4000-8000-000000000003','Fictional Registered Student','registered@fictional.test'),
       ('af390000-0000-4000-8000-000000000041',null,'Fictional Claim Student','claim@fictional.test');
insert into public.affiliations(id,student_id,university_id,verification,is_current)
values ('af390000-0000-4000-8000-000000000050','af390000-0000-4000-8000-000000000040','af390000-0000-4000-8000-000000000030','roster',true),
       ('af390000-0000-4000-8000-000000000051','af390000-0000-4000-8000-000000000041','af390000-0000-4000-8000-000000000030','roster',true);
select ok(exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000002'
    and n.kind='student_registered'
    and n.payload->>'student_id'='af390000-0000-4000-8000-000000000040'
),'new linked student affiliation notifies only university members');
select ok(not exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000002'
    and n.kind='student_registered'
    and (n.payload ? 'full_name' or n.payload ? 'email')
),'student registration notification omits name and contact information');
select is((select count(*)::int from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000002'
    and n.kind='student_registered'
    and n.payload->>'student_id'='af390000-0000-4000-8000-000000000041'),0,
  'unlinked roster student does not trigger registration notification');
update public.students set user_id='af390000-0000-4000-8000-000000000005'
where id='af390000-0000-4000-8000-000000000041';
select is((select count(*)::int from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000002'
    and n.kind='student_registered'
    and n.payload->>'student_id'='af390000-0000-4000-8000-000000000041'),1,
  'claiming an existing verified affiliation triggers one registration notification');

insert into public.organizations(id,name,status,subscription_status)
values ('af390000-0000-4000-8000-000000000060','Fictional Demand Org','approved','active');
insert into public.jobs(id,organization_id,title,description,status)
values ('af390000-0000-4000-8000-000000000061','af390000-0000-4000-8000-000000000060','Fictional Demand Job','Synthetic','open');
insert into public.demand_signals(id,job_id,university_id,reason_counts,skill_slugs)
values ('af390000-0000-4000-8000-000000000062','af390000-0000-4000-8000-000000000061','af390000-0000-4000-8000-000000000030','{"not_assessed":4}'::jsonb,array['react']);
select ok(exists(
  select 1 from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000002'
    and n.kind='demand_alert'
    and n.payload->>'university_id'='af390000-0000-4000-8000-000000000030'
    and n.payload->>'job_id'='af390000-0000-4000-8000-000000000061'
    and n.payload->'reason_counts'='{"not_assessed":4}'::jsonb
    and n.payload->'skill_slugs'='["react"]'::jsonb
    and not (n.payload ? 'student_id') and not (n.payload ? 'email')
),'demand alert contains aggregates only and is scoped to university members');
update public.demand_signals set reason_counts='{"not_assessed":5}'::jsonb where id='af390000-0000-4000-8000-000000000062';
update public.demand_signals set reason_counts='{"not_assessed":5}'::jsonb where id='af390000-0000-4000-8000-000000000062';
select is((select count(*)::int from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000002'
    and n.kind='demand_alert'
    and n.payload->>'job_id'='af390000-0000-4000-8000-000000000061'),2,
  'demand changes notify once; unchanged repeated update does not duplicate');

insert into public.students(id,user_id,full_name,primary_email)
values ('af390000-0000-4000-8000-000000000070','af390000-0000-4000-8000-000000000004','Fictional Audit Student','audit-student@fictional.test');
insert into public.submissions(id,student_id,title,status)
values ('af390000-0000-4000-8000-000000000071','af390000-0000-4000-8000-000000000070','Fictional Ready Submission','auditing'),
       ('af390000-0000-4000-8000-000000000074','af390000-0000-4000-8000-000000000070','Fictional Review Submission','needs_review');
insert into public.audits(id,submission_id,rubric_version,prompt_version,review_status)
values ('af390000-0000-4000-8000-000000000072','af390000-0000-4000-8000-000000000071','test@1','audit@1','unreviewed'),
       ('af390000-0000-4000-8000-000000000073','af390000-0000-4000-8000-000000000074','test@1','audit@1','pending');
update public.audits set review_status='complete' where id='af390000-0000-4000-8000-000000000072';
select ok(exists(
  select 1 from public.notifications n where n.user_id='af390000-0000-4000-8000-000000000004'
    and n.kind='audit_ready' and n.payload->>'audit_id'='af390000-0000-4000-8000-000000000072'
),'initial completed audit notifies its student');
select ok(exists(
  select 1 from public.notifications n where n.user_id='af390000-0000-4000-8000-000000000001'
    and n.kind='review_needed' and n.payload->>'audit_id'='af390000-0000-4000-8000-000000000073'
),'pending audit notifies admins');
select ok(exists(
  select 1 from public.notifications n where n.user_id='af390000-0000-4000-8000-000000000004'
    and n.kind='review_needed' and n.payload->>'audit_id'='af390000-0000-4000-8000-000000000073'
    and not (n.payload ? 'full_name') and not (n.payload ? 'email')
),'pending audit notifies its student with ids only');
insert into public.profile_proposals(id,student_id,source_id,changes,state)
values ('af390000-0000-4000-8000-000000000075','af390000-0000-4000-8000-000000000070',null,'{"headline":"Synthetic suggested change"}'::jsonb,'pending');
select ok(exists(
  select 1 from public.notifications n where n.user_id='af390000-0000-4000-8000-000000000004'
    and n.kind='source_proposals' and n.payload->>'proposal_id'='af390000-0000-4000-8000-000000000075'
    and not (n.payload ? 'changes')
),'source proposal notification omits proposed profile content');
update public.profile_proposals set state='pending' where id='af390000-0000-4000-8000-000000000075';
select is((select count(*)::int from public.notifications n where n.user_id='af390000-0000-4000-8000-000000000004'
  and n.kind='source_proposals' and n.payload->>'proposal_id'='af390000-0000-4000-8000-000000000075'),1,
  'unchanged source proposal state does not duplicate notifications');

update public.agent_runs set status='failed',error_code='CHANGED' where id='af390000-0000-4000-8000-000000000020';
select is((select count(*)::int from public.notifications n
  where n.user_id='af390000-0000-4000-8000-000000000001'
    and n.kind='run_failed'
    and n.payload->>'run_id'='af390000-0000-4000-8000-000000000020'),1,
  'unchanged failed status does not create duplicate notifications');

select * from finish();
rollback;
