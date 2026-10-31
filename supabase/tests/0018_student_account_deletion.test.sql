begin;
select plan(22);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('a0370000-0000-4000-8000-000000000001','authenticated','authenticated','delete-student@demo.aptohire.test',now(),extensions.crypt('fictional-password',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('a0370000-0000-4000-8000-000000000001','student');
insert into public.students(id,user_id,full_name,primary_email)
values('a0370000-0000-4000-8000-000000000002','a0370000-0000-4000-8000-000000000001','Fictional Deletion Student','delete-student@demo.aptohire.test');
insert into public.universities(id,name,status)
values('a0370000-0000-4000-8000-000000000003','Fictional Deletion University','approved');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,student_id,program_level,program,year,status)
values('a0370000-0000-4000-8000-000000000004','a0370000-0000-4000-8000-000000000003','synthetic-private-id-hash','delete-student@demo.aptohire.test','Fictional Deletion Student','a0370000-0000-4000-8000-000000000002','Bachelors','Computer Science',2,'student');
insert into public.organizations(id,name,status,subscription_status)
values('a0370000-0000-4000-8000-000000000005','Fictional Deletion Employer','approved','active');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('a0370000-0000-4000-8000-000000000006','a0370000-0000-4000-8000-000000000005','Synthetic Job','Fixture','open','[]'::jsonb,1);
insert into public.submissions(id,student_id,title,status)
values('a0370000-0000-4000-8000-000000000007','a0370000-0000-4000-8000-000000000002','Synthetic Submission','scored');
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,granted_scope,duration_days,status,expires_at,responded_at,message)
values('a0370000-0000-4000-8000-000000000008','a0370000-0000-4000-8000-000000000005','a0370000-0000-4000-8000-000000000002','a0370000-0000-4000-8000-000000000006',array['profile'],array['profile'],30,'accepted',now()+interval '10 days',now(),'Synthetic request message.');
insert into public.feedback_options(option_code,label) values('great_communication','Great communication') on conflict(option_code) do update set label=excluded.label;
insert into public.feedback(id,organization_id,student_id,request_id,option_codes,note)
values('a0370000-0000-4000-8000-000000000009','a0370000-0000-4000-8000-000000000005','a0370000-0000-4000-8000-000000000002','a0370000-0000-4000-8000-000000000008',array['great_communication'],'Synthetic feedback.');
insert into public.tickets(id,submission_id,student_id,reason,status)
values('a0370000-0000-4000-8000-000000000010','a0370000-0000-4000-8000-000000000007','a0370000-0000-4000-8000-000000000002','Synthetic ticket reason.','open');
insert into public.rubric_feedback_log(ticket_id,criterion,outcome,note)
values('a0370000-0000-4000-8000-000000000010','testing','adjusted','Synthetic rubric feedback.');
insert into public.placements(id,student_id,university_id,status,source)
values('a0370000-0000-4000-8000-000000000011','a0370000-0000-4000-8000-000000000002','a0370000-0000-4000-8000-000000000003','unknown','student');
insert into public.notifications(user_id,kind,payload)
values('a0370000-0000-4000-8000-000000000001','access_request','{"request_id":"a0370000-0000-4000-8000-000000000008"}'::jsonb);

select has_function('public','erase_student_account_data',array['uuid'],'data erasure RPC exists');
select has_function('public','finalize_student_account_deletion',array['uuid'],'deletion finalization RPC exists');
select ok(has_function_privilege('service_role','public.erase_student_account_data(uuid)','execute'),'service role can erase student data');
select ok(not has_function_privilege('authenticated','public.erase_student_account_data(uuid)','execute'),'authenticated cannot invoke data erasure RPC');
select ok(has_function_privilege('service_role','public.finalize_student_account_deletion(uuid)','execute'),'service role can finalize deletion');
select ok(not has_function_privilege('authenticated','public.finalize_student_account_deletion(uuid)','execute'),'authenticated cannot finalize deletion');
select ok(not (select attnotnull from pg_attribute where attrelid='public.access_requests'::regclass and attname='student_id' and not attisdropped),'anonymized requests can retain withdrawal history without student linkage');
select ok(exists(select 1 from pg_attribute where attrelid='public.roster_entries'::regclass and attname='anonymized_at' and not attisdropped),'roster can record anonymized entries');
select ok(not has_column_privilege('authenticated','public.roster_entries','anonymized_at','update'),'authenticated users cannot set roster anonymization state');

select is(public.erase_student_account_data('a0370000-0000-4000-8000-000000000001'),'a0370000-0000-4000-8000-000000000002'::uuid,'service-side deletion resolves and erases the student record');
select ok((select deletion_started_at is not null from public.profiles where id='a0370000-0000-4000-8000-000000000001'),'profile blocks app access while Auth soft deletion is finalized');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0370000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select ok(private.app_role() is null,'app role helper denies account once deletion starts');
select ok(private.my_student_id() is null,'student identity helper denies account once deletion starts');
reset role;
select ok(not exists(select 1 from public.students where id='a0370000-0000-4000-8000-000000000002'),'student profile row is removed');
select ok((select status='withdrawn' and student_id is null and granted_scope='{}'::text[] and message is null from public.access_requests where id='a0370000-0000-4000-8000-000000000008'),'accepted access request is withdrawn and anonymized');
select ok((select student_id is null and student_id_hash is null and email is null and full_name='Anonymized student' and anonymized_at is not null from public.roster_entries where id='a0370000-0000-4000-8000-000000000004'),'university roster row is irreversibly de-identified');
select ok(not exists(select 1 from public.feedback where id='a0370000-0000-4000-8000-000000000009'),'personal feedback row is removed');
select ok(not exists(select 1 from public.tickets where id='a0370000-0000-4000-8000-000000000010') and not exists(select 1 from public.rubric_feedback_log where ticket_id='a0370000-0000-4000-8000-000000000010'),'tickets and linked rubric notes are removed');
select ok(not exists(select 1 from public.placements where id='a0370000-0000-4000-8000-000000000011') and not exists(select 1 from public.notifications where user_id='a0370000-0000-4000-8000-000000000001'),'placement and notification rows are removed');
select ok(exists(select 1 from public.audit_log where actor_id='a0370000-0000-4000-8000-000000000001' and action='student_account_data_erased' and metadata ? 'data_subject_id'),'deletion is recorded with ids only');
select is(public.finalize_student_account_deletion('a0370000-0000-4000-8000-000000000001'),true,'profile is finalized after Auth soft deletion');
select ok(not exists(select 1 from public.profiles where id='a0370000-0000-4000-8000-000000000001'),'application role profile is removed');
select * from finish();
rollback;
