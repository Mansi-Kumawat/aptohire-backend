begin;
select plan(10);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('e0780000-0000-4000-8000-000000000001','authenticated','authenticated','transfer-learner@demo.aptohire.test',now(),extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.students(id,user_id,full_name,primary_email,credential_id)
values('e0780000-0000-4000-8000-000000000002','e0780000-0000-4000-8000-000000000001','Synthetic Transfer Learner','transfer-learner@demo.aptohire.test','CRED-IMMUTABLE-078');
insert into public.universities(id,name,status)
values
 ('e0780000-0000-4000-8000-000000000003','Former Synthetic University','approved'),
 ('e0780000-0000-4000-8000-000000000004','New Synthetic University','approved');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,year,status)
values('e0780000-0000-4000-8000-000000000005','e0780000-0000-4000-8000-000000000004',repeat('a',64),'transfer-learner@demo.aptohire.test','Synthetic Transfer Learner','Masters',1,'student');
insert into public.affiliations(student_id,university_id,verification,program_level,year,status,is_current)
values('e0780000-0000-4000-8000-000000000002','e0780000-0000-4000-8000-000000000003','roster','Bachelors',3,'student',true);
insert into public.affiliation_proposals(id,student_id,university_id,roster_entry_id,program_level,status,year,state)
values('e0780000-0000-4000-8000-000000000006','e0780000-0000-4000-8000-000000000002','e0780000-0000-4000-8000-000000000004','e0780000-0000-4000-8000-000000000005','Masters','student',1,'pending');
insert into public.skill_families(id,slug,name)
values('e0780000-0000-4000-8000-000000000007','affiliation-preserve-test','Affiliation Preserve Test');
insert into public.skills(id,family_id,slug,name)
values('e0780000-0000-4000-8000-000000000008','e0780000-0000-4000-8000-000000000007','affiliation-preserve-skill','Affiliation Preserve Skill');
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok)
values('e0780000-0000-4000-8000-000000000002','e0780000-0000-4000-8000-000000000008',81,'Proficient',true,false,true);
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
values('e0780000-0000-4000-8000-000000000009','e0780000-0000-4000-8000-000000000002','Existing synthetic work','scored',array['e0780000-0000-4000-8000-000000000008'::uuid]);

select is((public.confirm_affiliation('e0780000-0000-4000-8000-000000000002','e0780000-0000-4000-8000-000000000001','e0780000-0000-4000-8000-000000000006',null,null,null,null,null,null)->>'verification'),'roster','proposal confirmation derives verification from the confirmed Auth email');
select is((select count(*)::int from public.affiliations where student_id='e0780000-0000-4000-8000-000000000002' and is_current),1,'exactly one current affiliation remains');
select ok((select not is_current and ended_on is not null from public.affiliations where student_id='e0780000-0000-4000-8000-000000000002' and university_id='e0780000-0000-4000-8000-000000000003'),'former affiliation is closed with an end date');
select is((select university_id from public.affiliations where student_id='e0780000-0000-4000-8000-000000000002' and is_current),'e0780000-0000-4000-8000-000000000004'::uuid,'new verified affiliation is opened');
select is((select count(*)::int from public.students where user_id='e0780000-0000-4000-8000-000000000001'),1,'affiliation change does not create a second student');
select is((select credential_id from public.students where id='e0780000-0000-4000-8000-000000000002'),'CRED-IMMUTABLE-078','credential id remains unchanged');
select is((select score from public.skill_scores where student_id='e0780000-0000-4000-8000-000000000002' and skill_id='e0780000-0000-4000-8000-000000000008'),81::numeric,'skill scores remain unchanged');
select is((select status from public.submissions where id='e0780000-0000-4000-8000-000000000009'),'scored','submission status remains unchanged');
select is((select state from public.affiliation_proposals where id='e0780000-0000-4000-8000-000000000006'),'confirmed','proposal is confirmed atomically');
select is((select student_id from public.roster_entries where id='e0780000-0000-4000-8000-000000000005'),'e0780000-0000-4000-8000-000000000002'::uuid,'roster row is linked to the permanent student');

select * from finish();
rollback;
