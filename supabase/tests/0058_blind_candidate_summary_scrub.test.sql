begin;
select plan(20);

insert into public.students(id,full_name,primary_email,visibility)
values('a0580000-0000-4000-8000-000000000001','Jane Example','jane.example@private.test','{"discoverable":true}'::jsonb);
insert into public.universities(id,name,short_name,city,state,status)
values('a0580000-0000-4000-8000-000000000002','Sample University','Sample U','Jaipur','Rajasthan','approved');
insert into public.organizations(id,name,kind,size,status,subscription_status)
values('a0580000-0000-4000-8000-000000000003','Secret Employer Labs','corporate','small','approved','active');
insert into public.affiliations(student_id,university_id,verification,is_current)
values('a0580000-0000-4000-8000-000000000001','a0580000-0000-4000-8000-000000000002','roster',true);
update public.candidate_profiles set discoverable=true,
  scrubbed_summary='Built a robust learner portal for Jane Example at Sample University in Jaipur with Secret Employer Labs. Contact jane.example@private.test or 9876543210; visit https://private.example/path and @janeexample. The project includes reliable testing.'
where student_id='a0580000-0000-4000-8000-000000000001';

select has_function('private','scrub_candidate_summary',array['text','uuid'],'blind summary scrubber is installed');
select ok(not has_function_privilege('authenticated','private.scrub_candidate_summary(text,uuid)','execute'),'browser roles cannot call the scrubber as an arbitrary lookup');
select ok(not has_table_privilege('authenticated','public.candidate_profiles','SELECT'),'authenticated users cannot read the raw blind projection table');
select ok(not has_table_privilege('authenticated','public.candidate_profiles','UPDATE'),'authenticated users cannot write the raw blind projection table');
select ok((select scrubbed_summary is not null from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'sanitizer keeps non-identifying summary text');
select ok((select scrubbed_summary not ilike '%Jane%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'roster name is removed');
select ok((select scrubbed_summary not ilike '%jane.example@private.test%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'email is removed');
select ok((select scrubbed_summary not ilike any(array['%Sample University%','%Jaipur%','%Rajasthan%']) from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'university and location terms are removed');
select ok((select scrubbed_summary not ilike '%Secret Employer Labs%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'organization name is removed');
select ok((select scrubbed_summary not like '%9876543210%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'phone number is removed');
select ok((select scrubbed_summary not ilike any(array['%https://%','%@janeexample%']) from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'URL and social handle are removed');
select ok((select scrubbed_summary ilike '%reliable testing%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'neutral work description remains useful');
update public.candidate_profiles set scrubbed_summary='Jane Example built this with Sample University and jane.example@private.test'
where student_id='a0580000-0000-4000-8000-000000000001';
select ok((select scrubbed_summary not ilike any(array['%Jane%','%Sample University%','%jane.example@private.test%']) from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'later writes pass through the same scrub trigger');
insert into public.submissions(id,student_id,title,status)
values('a0580000-0000-4000-8000-000000000004','a0580000-0000-4000-8000-000000000001','Synthetic project','scored');
insert into public.audits(id,submission_id,rubric_version,prompt_version,summary,review_status)
values('a0580000-0000-4000-8000-000000000005','a0580000-0000-4000-8000-000000000004','synthetic-rubric@1','synthetic-prompt@1','Jane Example built a secure project for Sample University.','complete');
select ok((select scrubbed_summary is not null and scrubbed_summary ilike '%secure project%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'completed scored audit summary automatically refreshes the blind projection');
select ok((select scrubbed_summary not ilike any(array['%Jane%','%Sample University%']) from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'audit-derived summary is scrubbed before employer visibility');
update public.audits set summary='Jane Example built a secure project for Sample University and Zyzzogeton Quasar Observatory.'
where id='a0580000-0000-4000-8000-000000000005';
select ok((select scrubbed_summary ilike '%Zyzzogeton Quasar Observatory%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'audit text is refreshed before the university dictionary changes');
update public.universities set name='Zyzzogeton Quasar Observatory' where id='a0580000-0000-4000-8000-000000000002';
select ok((select scrubbed_summary not ilike '%Zyzzogeton Quasar Observatory%' from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'university identity changes trigger a projection rescrub');
insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('a0580000-0000-4000-8000-000000000006','authenticated','authenticated','summary-recruiter@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values('a0580000-0000-4000-8000-000000000006','organization');
insert into public.organization_members(organization_id,user_id,member_role)
values('a0580000-0000-4000-8000-000000000003','a0580000-0000-4000-8000-000000000006','recruiter');
insert into public.skill_families(id,slug,name) values('a0580000-0000-4000-8000-000000000007','summary-test','Summary Test');
insert into public.skills(id,family_id,slug,name) values('a0580000-0000-4000-8000-000000000008','a0580000-0000-4000-8000-000000000007','summary-skill','Summary Skill');
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id)
values('a0580000-0000-4000-8000-000000000001','a0580000-0000-4000-8000-000000000008',82,'Proficient',true,false,true,'a0580000-0000-4000-8000-000000000005');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('a0580000-0000-4000-8000-000000000009','a0580000-0000-4000-8000-000000000003','Summary Safety Role','Fictional','open','[]'::jsonb,1);
insert into public.match_results(id,job_id,student_id,alias,final_score,confidence,reasons,gaps,structured_score,vector_score)
values('a0580000-0000-4000-8000-000000000010','a0580000-0000-4000-8000-000000000009','a0580000-0000-4000-8000-000000000001','Candidate S058',82,0.9,array['Verified Summary Skill'],array[]::text[],82,null);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0580000-0000-4000-8000-000000000006","role":"authenticated","aal":"aal1"}',true);
select ok(exists(select 1 from public.org_candidate_cards where candidate_ref='a0580000-0000-4000-8000-000000000010' and scrubbed_summary ilike '%secure project%'),'employer card receives useful audit-derived summary prose');
select ok(not exists(select 1 from public.org_candidate_cards c where c.candidate_ref='a0580000-0000-4000-8000-000000000010' and to_jsonb(c)::text ilike any(array['%Jane%','%jane.example@private.test%','%Zyzzogeton Quasar Observatory%','%Sample University%','%Jaipur%','%Rajasthan%','%Secret Employer Labs%'])),'employer-facing summary and card contain no known identity values');
reset role;
update public.students set visibility='{"discoverable":false}'::jsonb where id='a0580000-0000-4000-8000-000000000001';
select ok((select scrubbed_summary is null from public.candidate_profiles where student_id='a0580000-0000-4000-8000-000000000001'),'visibility opt-out clears the blind projection summary');

select * from finish();
rollback;
