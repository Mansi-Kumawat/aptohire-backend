begin;
select plan(8);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a0390000-0000-4000-8000-000000000001','authenticated','authenticated','recruiter-canary@demo.aptohire.test',now(),extensions.crypt('fictional-password',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('a0390000-0000-4000-8000-000000000001','organization');
insert into public.organizations(id,name,kind,size,website,status,verified_at,subscription_status)
values
('a0390000-0000-4000-8000-000000000002','Fictional Canary Employer','corporate','small','https://employer.example.test','approved',now(),'active'),
('a0390000-0000-4000-8000-000000000012','Fictional Other Employer','corporate','small','https://other-employer.example.test','approved',now(),'active');
insert into public.organization_members(organization_id,user_id,member_role)
values('a0390000-0000-4000-8000-000000000002','a0390000-0000-4000-8000-000000000001','member');
insert into public.universities(id,name,short_name,tier,kind,city,state,status)
values('a0390000-0000-4000-8000-000000000003','Hidden Campus Canary','HCC',2,'public','Jaipur','Rajasthan','approved');
insert into public.students(id,full_name,primary_email,visibility)
values('a0390000-0000-4000-8000-000000000004','UltraPrivate Student Name Canary','candidate-canary@privacy.test','{"discoverable":true}'::jsonb);
insert into public.affiliations(student_id,university_id,verification,program_level,is_current)
values('a0390000-0000-4000-8000-000000000004','a0390000-0000-4000-8000-000000000003','roster','Bachelors',true);
insert into public.skill_families(id,slug,name)
values('a0390000-0000-4000-8000-000000000005','canary-family','Fictional Canary Skills');
insert into public.skills(id,family_id,slug,name)
values('a0390000-0000-4000-8000-000000000006','a0390000-0000-4000-8000-000000000005','canary-skill','Fictional Canary Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
values('a0390000-0000-4000-8000-000000000007','a0390000-0000-4000-8000-000000000004','Fictional Public Project','scored',array['a0390000-0000-4000-8000-000000000006'::uuid]);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,review_status)
values('a0390000-0000-4000-8000-000000000008','a0390000-0000-4000-8000-000000000007','fixture@1','fixture@1',75,0.9,'complete');
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id)
values('a0390000-0000-4000-8000-000000000004','a0390000-0000-4000-8000-000000000006',75,'Proficient',true,false,true,'a0390000-0000-4000-8000-000000000008');
update public.candidate_profiles set discoverable=true,skills='[]'::jsonb,study_stage='Year 2',uni_category='Tier 2 · University',scrubbed_summary='Fictional verified skills summary; contains no identity data.'
where student_id='a0390000-0000-4000-8000-000000000004';
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values
('a0390000-0000-4000-8000-000000000009','a0390000-0000-4000-8000-000000000002','Fictional Canary Role','Fixture','open','[]'::jsonb,1),
('a0390000-0000-4000-8000-000000000019','a0390000-0000-4000-8000-000000000012','Other Fictional Role','Fixture','open','[]'::jsonb,1);
insert into public.match_results(id,job_id,student_id,alias,final_score,confidence,reasons,gaps,structured_score,vector_score)
values
('a0390000-0000-4000-8000-000000000010','a0390000-0000-4000-8000-000000000009','a0390000-0000-4000-8000-000000000004','Candidate C4N7',75,0.9,array['One verified fixture skill'],array[]::text[],75,null),
('a0390000-0000-4000-8000-000000000020','a0390000-0000-4000-8000-000000000019','a0390000-0000-4000-8000-000000000004','Other Candidate C4N8',70,0.8,array['Other fixture skill'],array[]::text[],70,null);
insert into public.access_requests(id,organization_id,student_id,job_id,match_result_id,message,requested_scope,granted_scope,duration_days,status)
values
('a0390000-0000-4000-8000-000000000011','a0390000-0000-4000-8000-000000000002','a0390000-0000-4000-8000-000000000004','a0390000-0000-4000-8000-000000000009','a0390000-0000-4000-8000-000000000010','We would like to discuss the project.','{profile}','{}',7,'pending'),
('a0390000-0000-4000-8000-000000000021','a0390000-0000-4000-8000-000000000012','a0390000-0000-4000-8000-000000000004','a0390000-0000-4000-8000-000000000019','a0390000-0000-4000-8000-000000000020','Other org request fixture.','{profile}','{}',7,'pending');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0390000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select ok(exists(select 1 from public.org_candidate_cards where job_id='a0390000-0000-4000-8000-000000000009' and alias='Candidate C4N7'),'authorized organization can see the blind candidate card');
select ok(not exists(select 1 from public.org_candidate_cards v where to_jsonb(v)::text ilike any(array['%UltraPrivate Student Name Canary%','%candidate-canary@privacy.test%','%Hidden Campus Canary%','%a0390000-0000-4000-8000-000000000004%'])),'candidate card values contain no student id, name, email, or university name');
select ok(exists(select 1 from public.org_access_requests_v where id='a0390000-0000-4000-8000-000000000011' and alias='Candidate C4N7'),'authorized organization can see its blind request row');
select ok(not exists(select 1 from public.org_access_requests_v where id='a0390000-0000-4000-8000-000000000021'),'organization request view hides another approved organization request');
select ok(not exists(select 1 from public.org_access_requests_v v where to_jsonb(v)::text ilike any(array['%UltraPrivate Student Name Canary%','%candidate-canary@privacy.test%','%Hidden Campus Canary%','%a0390000-0000-4000-8000-000000000004%'])),'organization request values contain no student identity');
select ok(not exists(select 1 from public.students where id='a0390000-0000-4000-8000-000000000004'),'organization cannot read the student base row');
select ok(not exists(select 1 from public.affiliations where student_id='a0390000-0000-4000-8000-000000000004'),'organization cannot read the affiliation base row');
select ok(not exists(select 1 from public.submissions where student_id='a0390000-0000-4000-8000-000000000004') and not exists(select 1 from public.skill_scores where student_id='a0390000-0000-4000-8000-000000000004'),'organization cannot directly read submissions or skill scores');
select * from finish();
rollback;
