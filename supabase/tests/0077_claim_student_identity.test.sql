begin;
select plan(10);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('e0770000-0000-4000-8000-000000000001','authenticated','authenticated','roster-claim@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('e0770000-0000-4000-8000-000000000002','authenticated','authenticated','already-owned@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('e0770000-0000-4000-8000-000000000003','authenticated','authenticated','email-claim@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('e0770000-0000-4000-8000-000000000004','authenticated','authenticated','new-student@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.students(id,user_id,full_name,primary_email)
values
 ('e0770000-0000-4000-8000-000000000005',null,'Unclaimed Roster Person','roster-claim@demo.aptohire.test'),
 ('e0770000-0000-4000-8000-000000000006','e0770000-0000-4000-8000-000000000002','Already Owned Person','already-owned@demo.aptohire.test'),
 ('e0770000-0000-4000-8000-000000000007',null,'Unclaimed Email Person','email-claim@demo.aptohire.test');
insert into public.universities(id,name,status)
values('e0770000-0000-4000-8000-000000000008','Approved Claim Test University','approved');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,year,status,student_id)
values
 ('e0770000-0000-4000-8000-000000000009','e0770000-0000-4000-8000-000000000008',repeat('e',64),'roster-claim@demo.aptohire.test','Unclaimed Roster Person','Bachelors',1,'student','e0770000-0000-4000-8000-000000000005'),
 ('e0770000-0000-4000-8000-000000000010','e0770000-0000-4000-8000-000000000008',repeat('f',64),'already-owned@demo.aptohire.test','Already Owned Person','Bachelors',1,'student','e0770000-0000-4000-8000-000000000006');
create temporary table identity_results(label text,id uuid,matched boolean);

select has_function('public','claim_student_identity',array['uuid','text','uuid','text'],'student identity claim RPC exists');
select ok(not has_function_privilege('authenticated','public.claim_student_identity(uuid,text,uuid,text)','execute'),'authenticated callers cannot invoke the privileged identity RPC');
insert into identity_results select 'roster',* from public.claim_student_identity('e0770000-0000-4000-8000-000000000001','roster-claim@demo.aptohire.test','e0770000-0000-4000-8000-000000000009','Roster Claim Learner');
select is((select id from identity_results where label='roster'),'e0770000-0000-4000-8000-000000000005'::uuid,'ID-linked roster resolves to the existing permanent student');
select is((select matched from identity_results where label='roster'),true,'existing roster person is marked as matched');
select is((select user_id from public.students where id='e0770000-0000-4000-8000-000000000005'),'e0770000-0000-4000-8000-000000000001'::uuid,'unclaimed roster person is claimed by the authenticated user');
insert into identity_results select 'retry',* from public.claim_student_identity('e0770000-0000-4000-8000-000000000001','roster-claim@demo.aptohire.test','e0770000-0000-4000-8000-000000000009','Roster Claim Learner');
select ok((select count(distinct id)=1 from identity_results where label in ('roster','retry')) and
  (select count(*)=1 from public.students where user_id='e0770000-0000-4000-8000-000000000001'),'same-user retry reuses the claimed person without creating another student');
select throws_ok($$select * from public.claim_student_identity('e0770000-0000-4000-8000-000000000001','roster-claim@demo.aptohire.test','e0770000-0000-4000-8000-000000000010','Roster Claim Learner')$$,'23505',null,'a roster row linked to another login cannot be taken over');
insert into identity_results select 'email',* from public.claim_student_identity('e0770000-0000-4000-8000-000000000003','email-claim@demo.aptohire.test',null,'Email Claim Learner');
select ok((select id='e0770000-0000-4000-8000-000000000007'::uuid and matched from identity_results where label='email') and
  (select user_id='e0770000-0000-4000-8000-000000000003'::uuid from public.students where id='e0770000-0000-4000-8000-000000000007'),'verified-email match claims the existing person');
select throws_ok($$select * from public.claim_student_identity('e0770000-0000-4000-8000-000000000001','someone-else@demo.aptohire.test',null,'No Takeover')$$,'42501',null,'caller cannot supply an email different from verified Auth email');
insert into identity_results select 'new',* from public.claim_student_identity('e0770000-0000-4000-8000-000000000004','new-student@demo.aptohire.test',null,'New Fictional Learner');
select ok((select not matched from identity_results where label='new') and
  (select count(*)=1 from public.students where user_id='e0770000-0000-4000-8000-000000000004'),'new Auth user receives one new permanent student record');

select * from finish();
rollback;
