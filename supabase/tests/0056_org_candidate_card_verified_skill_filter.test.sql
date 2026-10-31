begin;
select plan(7);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('a0560000-0000-4000-8000-000000000001','authenticated','authenticated','recruiter-verified-card@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values('a0560000-0000-4000-8000-000000000001','organization');
insert into public.organizations(id,name,kind,size,status,subscription_status)
values('a0560000-0000-4000-8000-000000000002','Synthetic Approved Card Co','corporate','small','approved','active');
insert into public.organization_members(organization_id,user_id,member_role)
values('a0560000-0000-4000-8000-000000000002','a0560000-0000-4000-8000-000000000001','recruiter');
insert into public.students(id,full_name,primary_email,visibility)
values
 ('a0560000-0000-4000-8000-000000000003','Synthetic Verified Candidate','verified-card@demo.aptohire.test','{"discoverable":true}'::jsonb),
 ('a0560000-0000-4000-8000-000000000004','Synthetic Unverified Candidate','unverified-card@demo.aptohire.test','{"discoverable":true}'::jsonb);
insert into public.skill_families(id,slug,name) values('a0560000-0000-4000-8000-000000000005','card-test','Card Test');
insert into public.skills(id,family_id,slug,name) values
 ('a0560000-0000-4000-8000-000000000006','a0560000-0000-4000-8000-000000000005','verified-card-skill','Verified Card Skill'),
 ('a0560000-0000-4000-8000-000000000007','a0560000-0000-4000-8000-000000000005','unverified-card-skill','Unverified Card Skill');
insert into public.skill_scores(id,student_id,skill_id,score,level,verified,pending_review,share_ok)
values
 ('a0560000-0000-4000-8000-000000000008','a0560000-0000-4000-8000-000000000003','a0560000-0000-4000-8000-000000000006',82,'Proficient',true,false,true),
 ('a0560000-0000-4000-8000-000000000009','a0560000-0000-4000-8000-000000000004','a0560000-0000-4000-8000-000000000007',99,'Advanced',false,false,true);
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('a0560000-0000-4000-8000-000000000010','a0560000-0000-4000-8000-000000000002','Synthetic Card Role','Fictional','open','[]'::jsonb,1);
insert into public.match_results(id,job_id,student_id,alias,final_score,confidence,reasons,gaps,structured_score,vector_score)
values
 ('a0560000-0000-4000-8000-000000000011','a0560000-0000-4000-8000-000000000010','a0560000-0000-4000-8000-000000000003','Candidate VERIFIED1',82,0.9,array['Verified skill'],array[]::text[],82,null),
 ('a0560000-0000-4000-8000-000000000012','a0560000-0000-4000-8000-000000000010','a0560000-0000-4000-8000-000000000004','Candidate UNVERIFIED1',99,0.9,array['Unverified skill'],array[]::text[],99,null);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0560000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.org_candidate_cards where candidate_ref='a0560000-0000-4000-8000-000000000011'),1,'organization sees a card with a verified skill');
select is((select jsonb_array_length(skills) from public.org_candidate_cards where candidate_ref='a0560000-0000-4000-8000-000000000011'),1,'card skill list contains only verified shareable skills');
select ok((select bool_and((item->>'verified')::boolean) from public.org_candidate_cards c cross join lateral jsonb_array_elements(c.skills) item where c.candidate_ref='a0560000-0000-4000-8000-000000000011'),'every returned skill is explicitly verified');
select is((select count(*)::int from public.org_candidate_cards where candidate_ref='a0560000-0000-4000-8000-000000000012'),0,'candidate with only unverified shareable skills is omitted');
select ok(not exists(select 1 from public.org_candidate_cards c where to_jsonb(c)::text ilike any(array['%Synthetic Verified Candidate%','%verified-card@demo.aptohire.test%','%a0560000-0000-4000-8000-000000000003%','%Synthetic Unverified Candidate%','%unverified-card@demo.aptohire.test%','%a0560000-0000-4000-8000-000000000004%'])),'blind cards still contain no student identity values');
select is((select count(*)::int from public.skill_scores where student_id in ('a0560000-0000-4000-8000-000000000003','a0560000-0000-4000-8000-000000000004')),0,'organization cannot directly read underlying skill scores');
select is((select count(*)::int from public.students where id in ('a0560000-0000-4000-8000-000000000003','a0560000-0000-4000-8000-000000000004')),0,'organization cannot directly read student rows');

select * from finish();
rollback;
