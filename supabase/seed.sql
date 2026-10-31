-- Fictional, deterministic local demo fixtures only. No real people, emails or media.
DO $$ BEGIN
 if exists(select 1 from public.app_config where key='APP_ENV' and value #>> '{}'='production') then
  raise exception 'Refusing to run AptoHire seed in production';
 end if;
END $$;

insert into public.app_config(key,value) values
 ('PASS_MARK','50'),('BORDERLINE','[40,60]'),('AGENT_MODE','"mock"'),('REQUIRE_VIDEO','true'),
 ('VIDEO_MAX_MB','50'),('VIDEO_MAX_SECONDS','190'),('AI_DAILY_CAP_PER_USER','5'),('AI_KILL_SWITCH','false'),
 ('SCORE_BLEND_N','1'),('GRANT_DURATIONS','[7,30,90]'),
 ('MATCH_COVERAGE_FLOOR','0.25'),('MATCH_LEVEL_FLOORS','{"Emerging":51,"Competent":51,"Proficient":70,"Advanced":85}') on conflict(key) do nothing;

insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,approved_at,reference)
values
 (md5('seed:uni:a')::uuid,'University A','Uni A',2,'public','Jaipur','Rajasthan','approved',array['unia.edu.test'],now(),'AH-2A2A2A'),
 (md5('seed:uni:b')::uuid,'University B','Uni B',3,'public','Ajmer','Rajasthan','approved','{}',now(),'AH-3B3B3B'),
 (md5('seed:uni:c')::uuid,'University C','Uni C',3,'public','Kota','Rajasthan','pending','{}',null,'AH-7K2Q9F')
on conflict(id) do update set name=excluded.name,short_name=excluded.short_name,tier=excluded.tier,kind=excluded.kind,city=excluded.city,state=excluded.state,status=excluded.status,email_domains=excluded.email_domains,approved_at=excluded.approved_at,reference=excluded.reference;

insert into public.organizations(id,name,kind,size,website,status,verified_at,subscription_status,reference)
values
 (md5('seed:org:a')::uuid,'Northwind Labs','corporate','mid-size','https://northwind.example.test','approved',now(),'active','AH-5A5A5A'),
 (md5('seed:org:b')::uuid,'Brightlane','startup','small','https://brightlane.example.test','approved',now(),'active','AH-6B6B6B'),
 (md5('seed:org:c')::uuid,'Orbit Analytics','corporate','small','https://orbit.example.test','pending',null,'inactive','AH-4M8Z2D'),
 (md5('seed:org:d')::uuid,'Cedar Works','startup','small','https://cedar.example.test','approved',now(),'inactive','AH-8D8D8D')
on conflict(id) do update set name=excluded.name,kind=excluded.kind,size=excluded.size,website=excluded.website,status=excluded.status,verified_at=excluded.verified_at,subscription_status=excluded.subscription_status,reference=excluded.reference;

insert into public.skill_families(id,slug,name) values
 (md5('seed:family:web')::uuid,'web-frontend','Web / Frontend'),
 (md5('seed:family:backend')::uuid,'backend','Backend'),
 (md5('seed:family:data')::uuid,'data','Data'),
 (md5('seed:family:management-commerce')::uuid,'management-commerce','Management / Commerce')
on conflict(id) do update set slug=excluded.slug,name=excluded.name;
insert into public.skills(id,family_id,slug,name)
select md5('seed:skill:'||x.slug)::uuid,md5('seed:family:'||x.family)::uuid,x.slug,x.name from (values
 ('web','html-css','HTML / CSS'),('web','javascript','JavaScript'),('web','react','React'),('web','typescript','TypeScript'),('web','accessibility','Accessibility'),('web','api-integration','API integration'),('web','testing','Testing'),
 ('backend','node-js','Node.js'),('backend','python','Python'),('backend','sql','SQL'),('backend','rest-design','REST design'),('backend','auth','Auth'),
 ('data','sql-analytics','SQL analytics'),('data','pandas','Python / Pandas'),('data','visualization','Visualization'),('data','ml-basics','ML basics'),
 ('management-commerce','market-analysis','Market analysis'),('management-commerce','financial-modelling','Financial modelling'),('management-commerce','project-planning','Project planning'),('management-commerce','communication','Communication')
) as x(family,slug,name) on conflict(id) do update set family_id=excluded.family_id,slug=excluded.slug,name=excluded.name;

insert into public.feedback_options(option_code,label) values
 ('strong_projects','Strong projects'),('needs_more_depth','Needs more depth'),('not_a_fit_now','Not a fit right now'),('great_communication','Great communication')
on conflict(option_code) do update set label=excluded.label;

-- Named lifecycle examples, plus a fictional roster population for dashboard cohorts.
insert into public.students(id,full_name,primary_email,headline,visibility)
values
 (md5('seed:student:aarav')::uuid,'Aarav Sharma','aarav@unia.edu.test','Frontend learner','{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:ajay')::uuid,'Ajay Verma','ajay@unia.edu.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:akshit')::uuid,'Akshit Mehta','akshit@unia.edu.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:aarti')::uuid,'Aarti Singh','aarti@unia.edu.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:avi')::uuid,'Avi Kumar','avi@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:naman')::uuid,'Naman Joshi','naman@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:naveen')::uuid,'Naveen Das','naveen@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:nikhil')::uuid,'Nikhil Demo','nikhil@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:neha')::uuid,'Neha Demo','neha@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:nita')::uuid,'Nita Demo','nita@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:niya')::uuid,'Niya Patel','niya@demo.aptohire.test',null,'{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'),
 (md5('seed:student:sohan')::uuid,'Sohan Mehta','sohan@demo.aptohire.test','Frontend developer at Northwind Labs','{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}')
on conflict(id) do update set full_name=excluded.full_name,primary_email=excluded.primary_email,headline=excluded.headline,visibility=excluded.visibility;

-- Fictional local-only login fixtures. This password must match DEMO_PASSWORD in .env.example;
-- it is intentionally public and must never be reused outside this local demo.
-- Populate the Auth columns and email identity required by current Supabase Auth.
with demo_accounts(email,full_name) as (values
 ('admin@demo.aptohire.test','Demo Admin'),
 ('reviewer2@demo.aptohire.test','Demo Reviewer Two'),
 ('reviewer3@demo.aptohire.test','Demo Reviewer Three'),
 ('aarav@unia.edu.test','Aarav Sharma'),
 ('naman@demo.aptohire.test','Naman Joshi'),
 ('avi@demo.aptohire.test','Avi Kumar'),
 ('niya@demo.aptohire.test','Niya Patel'),
 ('sohan@demo.aptohire.test','Sohan Mehta'),
 ('tpo@unia.edu.test','Uni A TPO'),
 ('tpo@unib.edu.test','Uni B TPO'),
 ('tpo@unic.edu.test','Uni C TPO'),
 ('recruiter@orga.demo.test','Org A Recruiter'),
 ('recruiter@orgb.demo.test','Org B Recruiter'),
 ('recruiter@orgc.demo.test','Orbit Analytics Recruiter'),
 ('recruiter@orgd.demo.test','Cedar Works Recruiter')
)
insert into auth.users(
  id,instance_id,aud,role,email,email_confirmed_at,encrypted_password,
  raw_app_meta_data,raw_user_meta_data,confirmation_token,recovery_token,
  email_change_token_new,email_change,phone_change,phone_change_token,
  email_change_token_current,reauthentication_token,created_at,updated_at
)
select
  md5('seed:auth:'||email)::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated','authenticated',email,now(),
  extensions.crypt('aptohire-demo-only',extensions.gen_salt('bf')),
  jsonb_build_object('provider','email','providers',jsonb_build_array('email')),
  jsonb_build_object('full_name',full_name),
  '','','','','','','','',now(),now()
from demo_accounts
on conflict(id) do update set
  instance_id=excluded.instance_id,
  aud=excluded.aud,
  role=excluded.role,
  email=excluded.email,
  email_confirmed_at=excluded.email_confirmed_at,
  encrypted_password=excluded.encrypted_password,
  raw_app_meta_data=excluded.raw_app_meta_data,
  raw_user_meta_data=excluded.raw_user_meta_data,
  confirmation_token=excluded.confirmation_token,
  recovery_token=excluded.recovery_token,
  email_change_token_new=excluded.email_change_token_new,
  email_change=excluded.email_change,
  phone_change=excluded.phone_change,
  phone_change_token=excluded.phone_change_token,
  email_change_token_current=excluded.email_change_token_current,
  reauthentication_token=excluded.reauthentication_token,
  updated_at=now();

with demo_accounts(email) as (values
 ('admin@demo.aptohire.test'),('reviewer2@demo.aptohire.test'),('reviewer3@demo.aptohire.test'),
 ('aarav@unia.edu.test'),('naman@demo.aptohire.test'),('avi@demo.aptohire.test'),
 ('niya@demo.aptohire.test'),('sohan@demo.aptohire.test'),
 ('tpo@unia.edu.test'),('tpo@unib.edu.test'),('tpo@unic.edu.test'),
 ('recruiter@orga.demo.test'),('recruiter@orgb.demo.test'),
 ('recruiter@orgc.demo.test'),('recruiter@orgd.demo.test')
)
update auth.identities i
set provider_id=u.id::text,
    identity_data=jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true,'phone_verified',false),
    updated_at=now()
from auth.users u
join demo_accounts d on lower(d.email)=lower(u.email)
where i.user_id=u.id and i.provider='email';

with demo_accounts(email) as (values
 ('admin@demo.aptohire.test'),('reviewer2@demo.aptohire.test'),('reviewer3@demo.aptohire.test'),
 ('aarav@unia.edu.test'),('naman@demo.aptohire.test'),('avi@demo.aptohire.test'),
 ('niya@demo.aptohire.test'),('sohan@demo.aptohire.test'),
 ('tpo@unia.edu.test'),('tpo@unib.edu.test'),('tpo@unic.edu.test'),
 ('recruiter@orga.demo.test'),('recruiter@orgb.demo.test'),
 ('recruiter@orgc.demo.test'),('recruiter@orgd.demo.test')
)
insert into auth.identities(
  id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at
)
select
  gen_random_uuid(),u.id,u.id::text,
  jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true,'phone_verified',false),
  'email',now(),now(),now()
from auth.users u
join demo_accounts d on lower(d.email)=lower(u.email)
where not exists (
  select 1 from auth.identities i where i.user_id=u.id and i.provider='email'
);

with demo_accounts(email,app_role) as (values
 ('admin@demo.aptohire.test','admin'),('reviewer2@demo.aptohire.test','admin'),('reviewer3@demo.aptohire.test','admin'),
 ('aarav@unia.edu.test','student'),('naman@demo.aptohire.test','student'),('avi@demo.aptohire.test','student'),('niya@demo.aptohire.test','student'),('sohan@demo.aptohire.test','student'),
 ('tpo@unia.edu.test','university'),('tpo@unib.edu.test','university'),('tpo@unic.edu.test','university'),
 ('recruiter@orga.demo.test','organization'),('recruiter@orgb.demo.test','organization'),('recruiter@orgc.demo.test','organization'),('recruiter@orgd.demo.test','organization')
)
insert into public.profiles(id,role)
select md5('seed:auth:'||email)::uuid,app_role from demo_accounts
on conflict(id) do update set role=excluded.role;

update public.students set user_id=md5('seed:auth:'||primary_email::text)::uuid
where primary_email in ('aarav@unia.edu.test','naman@demo.aptohire.test','avi@demo.aptohire.test','niya@demo.aptohire.test','sohan@demo.aptohire.test');
insert into public.profile_sources(id,student_id,source_type,auto_approve,consented_at,last_synced_at)
values(md5('seed:profile-source:sohan:linkedin')::uuid,md5('seed:student:sohan')::uuid,'linkedin_export',true,now()-interval '30 days',now()-interval '2 days')
on conflict(id) do update set auto_approve=true,consented_at=excluded.consented_at,revoked_at=null,last_synced_at=excluded.last_synced_at;
insert into public.profile_proposals(id,student_id,source_id,changes,state,created_at)
values(md5('seed:profile-proposal:sohan:headline')::uuid,md5('seed:student:sohan')::uuid,md5('seed:profile-source:sohan:linkedin')::uuid,
       '[{"field":"headline","action":"update","value":"Frontend developer at Northwind Labs","evidence":"Fictional consented profile-export fixture."}]'::jsonb,
       'approved',now()-interval '2 days')
on conflict(id) do update set source_id=excluded.source_id,changes=excluded.changes,state='approved';
insert into public.university_members(university_id,user_id,member_role)
select md5('seed:uni:a')::uuid,md5('seed:auth:tpo@unia.edu.test')::uuid,'tpo'
union all select md5('seed:uni:b')::uuid,md5('seed:auth:tpo@unib.edu.test')::uuid,'tpo'
union all select md5('seed:uni:c')::uuid,md5('seed:auth:tpo@unic.edu.test')::uuid,'tpo'
on conflict(university_id,user_id) do update set member_role=excluded.member_role;
insert into public.organization_members(organization_id,user_id,member_role)
select md5('seed:org:a')::uuid,md5('seed:auth:recruiter@orga.demo.test')::uuid,'recruiter'
union all select md5('seed:org:b')::uuid,md5('seed:auth:recruiter@orgb.demo.test')::uuid,'recruiter'
union all select md5('seed:org:c')::uuid,md5('seed:auth:recruiter@orgc.demo.test')::uuid,'recruiter'
union all select md5('seed:org:d')::uuid,md5('seed:auth:recruiter@orgd.demo.test')::uuid,'recruiter'
on conflict(organization_id,user_id) do update set member_role=excluded.member_role;

-- Create referenced synthetic student rows before the roster FK insert.
insert into public.students(id,full_name,primary_email)
select md5('seed:unia:student:'||n)::uuid,'Synthetic Learner '||lpad(n::text,3,'0'),'learner.'||lpad(n::text,3,'0')||'@unia.edu.test'
from generate_series(7,59) n on conflict(id) do nothing;

insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,student_id,program_level,program,year,status)
select md5('seed:unia:roster:'||n)::uuid,md5('seed:uni:a')::uuid,
       encode(extensions.digest('fictional-roster-id:'||n,'sha256'),'hex'),
       case when n=3 then 'aarav@unia.edu.test' when n=2 then 'ajay@unia.edu.test' when n=4 then 'akshit@unia.edu.test' when n=5 then 'aarti@unia.edu.test' when n=6 then 'avi@demo.aptohire.test' else 'learner.'||lpad(n::text,3,'0')||'@unia.edu.test' end,
       case n when 1 then 'Aman Incoming' when 2 then 'Ajay Verma' when 3 then 'Aarav Sharma' when 4 then 'Akshit Mehta' when 5 then 'Aarti Singh' when 6 then 'Avi Kumar' else 'Synthetic Learner '||lpad(n::text,3,'0') end,
       case when n=1 then null when n=2 then md5('seed:student:ajay')::uuid when n=3 then md5('seed:student:aarav')::uuid when n=4 then md5('seed:student:akshit')::uuid when n=5 then md5('seed:student:aarti')::uuid when n=6 then md5('seed:student:avi')::uuid when n<=59 then md5('seed:unia:student:'||n)::uuid else null end,
       'ug',case when n%3=0 then 'Computer Science' when n%3=1 then 'Information Technology' else 'Electronics' end,
       ((n-1)%4)+1,case when n=1 then 'incoming'::public.life_status when n=5 then 'dropout'::public.life_status when n=6 then 'alumni'::public.life_status else 'enrolled'::public.life_status end
from generate_series(1,90) n
on conflict(id) do update set student_id_hash=excluded.student_id_hash,email=excluded.email,full_name=excluded.full_name,student_id=excluded.student_id,program_level=excluded.program_level,program=excluded.program,year=excluded.year,status=excluded.status;

insert into public.students(id,full_name,primary_email)
select md5('seed:unia:student:'||n)::uuid,'Synthetic Learner '||lpad(n::text,3,'0'),'learner.'||lpad(n::text,3,'0')||'@unia.edu.test'
from generate_series(7,59) n on conflict(id) do nothing;

-- Make reruns safe when the previous seed left these lifecycle fixtures at their final state.
-- Aarti is first replayed at Uni A, then moved to Uni B below; Niya is first replayed at Uni B,
-- then moved to the unverified University D below. Clear only those deterministic demo rows.
update public.affiliations
   set is_current=false, ended_on=current_date
 where (student_id=md5('seed:student:aarti')::uuid
        and id=md5('seed:unib:affiliation:aarti')::uuid)
    or (student_id=md5('seed:student:niya')::uuid
        and id=md5('seed:affiliation:niya:university-d')::uuid);

insert into public.affiliations(id,student_id,university_id,roster_entry_id,verification,program_level,year,status,is_current)
select md5('seed:unia:affiliation:'||n)::uuid,
       case n when 2 then md5('seed:student:ajay')::uuid when 3 then md5('seed:student:aarav')::uuid when 4 then md5('seed:student:akshit')::uuid when 5 then md5('seed:student:aarti')::uuid when 6 then md5('seed:student:avi')::uuid else md5('seed:unia:student:'||n)::uuid end,
       md5('seed:uni:a')::uuid,md5('seed:unia:roster:'||n)::uuid,'roster'::public.affiliation_verification,'ug',((n-1)%4)+1,
       case n when 5 then 'dropout'::public.life_status when 6 then 'alumni'::public.life_status else 'enrolled'::public.life_status end,true
from generate_series(2,59) n on conflict(id) do update set roster_entry_id=excluded.roster_entry_id,verification=excluded.verification,year=excluded.year,status=excluded.status,is_current=true;

insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,student_id,program_level,program,year,status)
select md5('seed:unib:roster:'||n)::uuid,md5('seed:uni:b')::uuid,encode(extensions.digest('fictional-unib-id:'||n,'sha256'),'hex'),
       'student.'||n||'@demo.aptohire.test',x.name,md5('seed:student:'||x.slug)::uuid,'ug','Computer Science',((n-1)%4)+1,'enrolled'
from (values (1,'Nikhil','nikhil'),(2,'Neha','neha'),(3,'Naman','naman'),(4,'Naveen','naveen'),(5,'Nita','nita'),(6,'Niya','niya')) x(n,name,slug)
on conflict(id) do update set full_name=excluded.full_name,student_id=excluded.student_id,year=excluded.year;
insert into public.students(id,full_name,primary_email)
select md5('seed:student:'||slug)::uuid,name,slug||'@demo.aptohire.test'
from (values ('Nikhil','nikhil'),('Neha','neha'),('Nita','nita'),('Niya','niya')) x(name,slug)
on conflict(id) do update set full_name=excluded.full_name,primary_email=excluded.primary_email;
insert into public.affiliations(id,student_id,university_id,roster_entry_id,verification,program_level,year,status,is_current)
select md5('seed:unib:affiliation:'||n)::uuid,md5('seed:student:'||slug)::uuid,md5('seed:uni:b')::uuid,md5('seed:unib:roster:'||n)::uuid,'roster'::public.affiliation_verification,'ug',((n-1)%4)+1,'enrolled',true
from (values (1,'nikhil'),(2,'neha'),(3,'naman'),(4,'naveen'),(5,'nita'),(6,'niya')) x(n,slug)
on conflict(id) do update set roster_entry_id=excluded.roster_entry_id,verification='roster'::public.affiliation_verification,is_current=true;

-- Fictional lifecycle cases: Aarti joins Uni B, Nita has no current affiliation, and Niya reports an unverified Uni D move.
update public.affiliations set is_current=false,ended_on=current_date
where id=md5('seed:unia:affiliation:5')::uuid;
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,student_id,program_level,program,year,status)
values(md5('seed:unib:roster:aarti')::uuid,md5('seed:uni:b')::uuid,
       encode(extensions.digest('fictional-unib-id:aarti','sha256'),'hex'),
       'aarti@unia.edu.test','Aarti Singh',md5('seed:student:aarti')::uuid,'ug','Computer Science',3,'enrolled')
on conflict(id) do update set email=excluded.email,full_name=excluded.full_name,student_id=excluded.student_id,
  program_level=excluded.program_level,program=excluded.program,year=excluded.year,status=excluded.status;
insert into public.affiliations(id,student_id,university_id,roster_entry_id,verification,program_level,year,status,is_current)
values(md5('seed:unib:affiliation:aarti')::uuid,md5('seed:student:aarti')::uuid,md5('seed:uni:b')::uuid,
       md5('seed:unib:roster:aarti')::uuid,'roster'::public.affiliation_verification,'ug',3,'enrolled',true)
on conflict(id) do update set roster_entry_id=excluded.roster_entry_id,verification='roster'::public.affiliation_verification,
  program_level=excluded.program_level,year=excluded.year,status=excluded.status,is_current=true,ended_on=null;
update public.affiliations set is_current=false,ended_on=current_date
where id=md5('seed:unib:affiliation:5')::uuid;
update public.affiliations set is_current=false,ended_on=current_date
where id=md5('seed:unib:affiliation:6')::uuid;
insert into public.affiliations(id,student_id,university_name_text,verification,program_level,year,status,is_current)
values(md5('seed:affiliation:niya:university-d')::uuid,md5('seed:student:niya')::uuid,'University D',
       'unverified'::public.affiliation_verification,'pg',1,'enrolled',true)
on conflict(id) do update set university_name_text='University D',verification='unverified'::public.affiliation_verification,
  program_level='pg',year=1,status='enrolled',is_current=true,ended_on=null;

-- Avi's contemplated masters move is a pending proposal; current affiliation and scores are unchanged.
insert into public.affiliation_proposals(id,student_id,university_id,program_level,status,year,state)
values(md5('seed:affiliation-proposal:avi:unib')::uuid,md5('seed:student:avi')::uuid,md5('seed:uni:b')::uuid,'pg','enrolled',1,'pending')
on conflict(id) do update set university_id=excluded.university_id,program_level=excluded.program_level,status=excluded.status,year=excluded.year,state='pending';

insert into public.roster_entries(id,university_id,student_id_hash,full_name,program_level,program,year,status)
select md5('seed:unic:roster:'||n)::uuid,md5('seed:uni:c')::uuid,encode(extensions.digest('fictional-unic-id:'||n,'sha256'),'hex'),x.name,'ug','Computer Science',((n-1)%4)+1,'enrolled'
from (values(1,'Sumit'),(2,'Sourav'),(3,'Sam'),(4,'Shiva'),(5,'Shruti'),(6,'Sohan')) x(n,name)
on conflict(id) do update set full_name=excluded.full_name,year=excluded.year;

insert into public.students(id,full_name,primary_email)
values(md5('seed:student:priya')::uuid,'Priya Demo','priya@demo.aptohire.test'),(md5('seed:student:adarsh')::uuid,'Adarsh Demo','adarsh@demo.aptohire.test')
on conflict(id) do update set full_name=excluded.full_name;
insert into public.affiliations(id,student_id,university_name_text,verification,program_level,year,status,is_current)
values(md5('seed:affiliation:priya')::uuid,md5('seed:student:priya')::uuid,'University D','unverified','ug',2,'enrolled',true),
      (md5('seed:affiliation:adarsh')::uuid,md5('seed:student:adarsh')::uuid,'University D','unverified','ug',3,'enrolled',true)
on conflict(id) do update set verification='unverified'::public.affiliation_verification,is_current=true;

insert into public.project_templates(id,skill_id,level,title,brief,active)
values(md5('seed:template:react:competent')::uuid,md5('seed:skill:react')::uuid,'Competent','Accessible React dashboard',jsonb_build_object('title','Accessible {{domain}} dashboard','objective','Build a data dashboard for {{domain}} using {{dataset}}. Support {{constraint}} and include {{twist}}.','deliverables',jsonb_build_array('Source code','Tests'),'variation_slots',jsonb_build_object('domain',jsonb_build_array('a fictional community library','a fictional public garden','a fictional transit service'),'dataset',jsonb_build_array('synthetic book records','synthetic plant records','synthetic transit records'),'constraint',jsonb_build_array('keyboard-only navigation','low-bandwidth rendering','screen-reader support'),'twist',jsonb_build_array('an offline state','a data-quality warning','a printable summary')),'rubric_version','web-frontend@1','level','Competent'),true)
on conflict(id) do update set title=excluded.title,brief=excluded.brief,active=true;
insert into public.submissions(id,student_id,template_id,title,status,claimed_skill_ids,video_path,created_at,updated_at)
values(md5('seed:submission:aarav')::uuid,md5('seed:student:aarav')::uuid,md5('seed:template:react:competent')::uuid,'Accessible React dashboard','scored',array[md5('seed:skill:react')::uuid,md5('seed:skill:typescript')::uuid],null,now()-interval '20 days',now()-interval '10 days')
on conflict(id) do update set status='scored',claimed_skill_ids=excluded.claimed_skill_ids;
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,evidence,next_steps,review_status,created_at)
values(md5('seed:audit:aarav')::uuid,md5('seed:submission:aarav')::uuid,'web-frontend@1','audit@1',72,0.85,'Synthetic demo audit with fictional evidence.',
 '[{"key":"functionality","score":75},{"key":"quality","score":70},{"key":"ui_accessibility","score":72},{"key":"testing","score":68},{"key":"documentation","score":70},{"key":"problem_solving","score":74},{"key":"communication","score":70}]'::jsonb,
 '[{"criterion":"functionality","evidence_ref":"bundle:readme","excerpt":"Synthetic evidence excerpt."}]'::jsonb,array['Add keyboard tests','Document tradeoffs'], 'complete',now()-interval '10 days')
on conflict(id) do update set overall_score=excluded.overall_score,confidence=excluded.confidence,summary=excluded.summary,rubric=excluded.rubric,evidence=excluded.evidence,next_steps=excluded.next_steps;
insert into public.skill_scores(id,student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
values(md5('seed:score:aarav:react')::uuid,md5('seed:student:aarav')::uuid,md5('seed:skill:react')::uuid,72,'Proficient',true,false,true,md5('seed:audit:aarav')::uuid,now()-interval '10 days'),
      (md5('seed:score:aarav:typescript')::uuid,md5('seed:student:aarav')::uuid,md5('seed:skill:typescript')::uuid,58,'Competent',true,false,true,md5('seed:audit:aarav')::uuid,now()-interval '10 days'),
      (md5('seed:score:naveen:react')::uuid,md5('seed:student:naveen')::uuid,md5('seed:skill:react')::uuid,52,'Competent',true,true,false,null,now()-interval '2 days')
on conflict(id) do update set score=excluded.score,level=excluded.level,verified=excluded.verified,pending_review=excluded.pending_review,share_ok=excluded.share_ok,audit_id=excluded.audit_id;

insert into public.jobs(id,organization_id,title,description,mode,location,status,required_skills,openings)
values
 (md5('seed:job:frontend')::uuid,md5('seed:org:a')::uuid,'Frontend Developer (React)','Build accessible product interfaces.','hybrid','Jaipur','open',jsonb_build_array(jsonb_build_object('skill_id',md5('seed:skill:react')::uuid,'min_level','Competent','weight',1)),2),
 (md5('seed:job:frontend-intern')::uuid,md5('seed:org:a')::uuid,'Frontend Intern (React)','Support component delivery.','remote','India','open',jsonb_build_array(jsonb_build_object('skill_id',md5('seed:skill:react')::uuid,'min_level','Emerging','weight',1)),3),
 (md5('seed:job:fullstack')::uuid,md5('seed:org:b')::uuid,'Junior Full-stack Intern','Build API-connected interfaces.','hybrid','Jaipur','open',jsonb_build_array(jsonb_build_object('skill_id',md5('seed:skill:javascript')::uuid,'min_level','Emerging','weight',1)),2),
 (md5('seed:job:data-viz')::uuid,md5('seed:org:b')::uuid,'Data Visualization Analyst','Create clear data visualizations.','remote','India','open',jsonb_build_array(jsonb_build_object('skill_id',md5('seed:skill:visualization')::uuid,'min_level','Competent','weight',1)),1),
 (md5('seed:job:node-a')::uuid,md5('seed:org:a')::uuid,'Node.js Backend Developer','Build reliable Node.js services.','hybrid','Jaipur','open',jsonb_build_array(jsonb_build_object('skill_id',md5('seed:skill:node-js')::uuid,'min_level','Competent','weight',1)),2),
 (md5('seed:job:node-b')::uuid,md5('seed:org:b')::uuid,'Node.js Intern','Support API development.','remote','India','open',jsonb_build_array(jsonb_build_object('skill_id',md5('seed:skill:node-js')::uuid,'min_level','Emerging','weight',1)),1)
on conflict(id) do update set title=excluded.title,description=excluded.description,status=excluded.status,required_skills=excluded.required_skills,openings=excluded.openings;

insert into public.candidate_profiles(student_id,discoverable,alias_data,skills,study_stage,uni_category,scrubbed_summary)
values(md5('seed:student:aarav')::uuid,true,'{}','[{"name":"React","level":"Proficient","score":72,"verified":true}]','Year 2','Tier 2 · University','Fictional frontend learner with verified React work.')
on conflict(student_id) do update set discoverable=true,skills=excluded.skills,study_stage=excluded.study_stage,uni_category=excluded.uni_category,scrubbed_summary=excluded.scrubbed_summary;
insert into public.match_results(id,job_id,student_id,alias,final_score,confidence,reasons,gaps,structured_score,vector_score)
values(md5('seed:match:aarav:frontend')::uuid,md5('seed:job:frontend')::uuid,md5('seed:student:aarav')::uuid,'Candidate A7K2',72,0.82,array['Verified React, Proficient (72)'],array['More test coverage'],75,65)
on conflict(job_id,student_id) do update set alias=excluded.alias,final_score=excluded.final_score,confidence=excluded.confidence,reasons=excluded.reasons,gaps=excluded.gaps,structured_score=excluded.structured_score,vector_score=excluded.vector_score;
insert into public.access_requests(id,organization_id,student_id,job_id,match_result_id,message,requested_scope,granted_scope,duration_days,status,expires_at,created_at,responded_at)
values(md5('seed:request:aarav:pending')::uuid,md5('seed:org:a')::uuid,md5('seed:student:aarav')::uuid,md5('seed:job:frontend')::uuid,md5('seed:match:aarav:frontend')::uuid,'We would like to learn more about your project.',array['profile','scorecard'],array[]::text[],30,'pending',null,now()-interval '1 day',null),
      (md5('seed:request:aarav:accepted')::uuid,md5('seed:org:b')::uuid,md5('seed:student:aarav')::uuid,md5('seed:job:fullstack')::uuid,null,'Your portfolio matches the internship.',array['profile','scorecard'],array['profile','scorecard'],30,'accepted',now()+interval '20 days',now()-interval '10 days',now()-interval '9 days')
on conflict(id) do update set status=excluded.status,granted_scope=excluded.granted_scope,expires_at=excluded.expires_at,responded_at=excluded.responded_at;
insert into public.demand_signals(id,job_id,university_id,reason_counts,skill_slugs)
values
 (md5('seed:demand:data-viz')::uuid,md5('seed:job:data-viz')::uuid,md5('seed:uni:a')::uuid,'{"no_eligible":3,"incomplete_assessments":4,"insufficient_evidence":2,"skills_mismatch":12,"opted_out":3,"not_assessed":8}'::jsonb,array['visualization']),
 (md5('seed:demand:node-a')::uuid,md5('seed:job:node-a')::uuid,md5('seed:uni:a')::uuid,'{"no_eligible":2,"incomplete_assessments":4,"insufficient_evidence":2,"skills_mismatch":9,"opted_out":1,"not_assessed":5}'::jsonb,array['node-js']),
 (md5('seed:demand:node-b')::uuid,md5('seed:job:node-b')::uuid,md5('seed:uni:a')::uuid,'{"no_eligible":1,"incomplete_assessments":2,"insufficient_evidence":1,"skills_mismatch":4,"opted_out":2,"not_assessed":7}'::jsonb,array['node-js'])
on conflict(id) do update set reason_counts=excluded.reason_counts,skill_slugs=excluded.skill_slugs;
insert into public.placements(id,student_id,university_id,status,organization_name_text,role_text,source)
values(md5('seed:placement:aarav')::uuid,md5('seed:student:aarav')::uuid,md5('seed:uni:a')::uuid,'unknown',null,null,'student')
on conflict(id) do update set status=excluded.status;

-- Initial fictional demo applications; no Auth accounts are created by seed.sql.
insert into public.applications(id,reference,type,subject_id,contact_name,contact_role,contact_email,contact_phone,payload,status)
values(md5('seed:application:uni-c')::uuid,'AH-7K2Q9F','university',md5('seed:uni:c')::uuid,'Demo Contact','TPO','tpo@unic.edu.test',null,'{"name":"University C"}'::jsonb,'received'),
      (md5('seed:application:org-c')::uuid,'AH-4M8Z2D','organization',md5('seed:org:c')::uuid,'Demo Recruiter','Recruiter','recruiter@orgc.demo.test',null,'{"name":"Orbit Analytics"}'::jsonb,'received')
on conflict(reference) do update set subject_id=excluded.subject_id,payload=excluded.payload,status=excluded.status;

-- TODO(decision): These are fictional applications with synthetic free-mail-style .test domains.
-- They exercise review queues only; they are not deliverable demo logins.
insert into public.universities(id,name,short_name,tier,kind,city,state,status,email_domains,reference,status_note)
values(md5('seed:application:riverbend')::uuid,'Riverbend College','Riverbend',3,'private','Ajmer','Rajasthan','pending',array['gmail.test'],'AH-8R2V3D',null),
      (md5('seed:application:rejected-uni')::uuid,'Fictional Rejected Institute','Rejected Institute',3,'private','Jaipur','Rajasthan','rejected',array['rejected.example.test'],'AH-5D8F2K','Fictional demo rejection note; submit a corrected application.')
on conflict(id) do update set status=excluded.status,email_domains=excluded.email_domains,reference=excluded.reference,status_note=excluded.status_note;
insert into public.organizations(id,name,kind,size,website,status,verified_at,subscription_status,reference,status_note)
values(md5('seed:application:quick-hire')::uuid,'Quick Hire Co','corporate','small','https://quickhire.example.test','pending',null,'inactive','AH-9Q3W4C',null)
on conflict(id) do update set name=excluded.name,website=excluded.website,status=excluded.status,subscription_status=excluded.subscription_status,reference=excluded.reference,status_note=excluded.status_note;
insert into public.applications(id,reference,type,subject_id,contact_name,contact_role,contact_email,contact_phone,payload,status)
values(md5('seed:application:riverbend')::uuid,'AH-8R2V3D','university',md5('seed:application:riverbend')::uuid,'Fictional Contact','TPO','contact@gmail.test',null,'{"name":"Riverbend College","email_domains":["gmail.test"]}'::jsonb,'received'),
      (md5('seed:application:quick-hire')::uuid,'AH-9Q3W4C','organization',md5('seed:application:quick-hire')::uuid,'Fictional Recruiter','Recruiter','recruiter@personal.test',null,'{"name":"Quick Hire Co","website":"https://quickhire.example.test"}'::jsonb,'received'),
      (md5('seed:application:rejected-uni')::uuid,'AH-5D8F2K','university',md5('seed:application:rejected-uni')::uuid,'Fictional Contact','TPO','contact@rejected.example.test',null,'{"name":"Fictional Rejected Institute"}'::jsonb,'rejected')
on conflict(reference) do update set subject_id=excluded.subject_id,payload=excluded.payload,status=excluded.status;

-- Five synthetic borderline audits; one is at least ten days old for overdue-queue demos.
insert into public.submissions(id,student_id,title,status,claimed_skill_ids,created_at,updated_at)
select md5('seed:submission:borderline:'||n)::uuid,
       case n when 1 then md5('seed:student:nikhil')::uuid when 2 then md5('seed:student:neha')::uuid when 3 then md5('seed:student:naman')::uuid when 4 then md5('seed:student:nita')::uuid else md5('seed:student:niya')::uuid end,
       'Synthetic borderline review '||n,'needs_review',array[md5('seed:skill:react')::uuid],
       now()-case when n=1 then interval '11 days' else interval '2 days' end,
       now()-case when n=1 then interval '11 days' else interval '2 days' end
from generate_series(1,5) n
on conflict(id) do update set status='needs_review',claimed_skill_ids=excluded.claimed_skill_ids,updated_at=excluded.updated_at;
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,review_status,created_at)
select md5('seed:audit:borderline:'||n)::uuid,
       md5('seed:submission:borderline:'||n)::uuid,'web-frontend@1','audit@1',40+n*3,0.65,
       'Synthetic pending borderline audit; fictional review fixture.',
       jsonb_build_array(jsonb_build_object('key','functionality','score',40+n*3)),
       'pending',now()-case when n=1 then interval '11 days' else interval '2 days' end
from generate_series(1,5) n
on conflict(id) do update set overall_score=excluded.overall_score,confidence=excluded.confidence,summary=excluded.summary,rubric=excluded.rubric,review_status='pending',created_at=excluded.created_at;
insert into public.skill_scores(id,student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
select md5('seed:score:borderline:'||n)::uuid,
       case n when 1 then md5('seed:student:nikhil')::uuid when 2 then md5('seed:student:neha')::uuid when 3 then md5('seed:student:naman')::uuid when 4 then md5('seed:student:nita')::uuid else md5('seed:student:niya')::uuid end,md5('seed:skill:react')::uuid,40+n*3,
       case when 40+n*3<=50 then 'Emerging' else 'Competent' end,false,true,false,
       md5('seed:audit:borderline:'||n)::uuid,now()-case when n=1 then interval '11 days' else interval '2 days' end
from generate_series(1,5) n
on conflict(id) do update set score=excluded.score,level=excluded.level,verified=false,pending_review=true,share_ok=false,audit_id=excluded.audit_id,updated_at=excluded.updated_at;

-- Synthetic operations telemetry for admin dashboards; actor ids are intentionally absent.
insert into public.agent_runs(id,submission_id,user_id,stage,attempt,mode,status,latency_ms,token_estimate,error_code,created_at)
select md5('seed:agent-run:'||n)::uuid,md5('seed:submission:aarav')::uuid,null,
       case when n%4=0 then 'received' when n%4=1 then 'scoring' when n%4=2 then 'writing' else 'done' end,
       1,case when n%3=0 then 'direct' when n%3=1 then 'mock' else 'n8n' end,
       case when n%7=0 then 'failed' when n%5=0 then 'queued' when n%4=0 then 'running' else 'completed' end,
       case when n%5=0 then null else 450+n*19 end,
       case when n%5=0 then null else 120+n*3 end,
       case when n%7=0 then 'SYNTHETIC_FAILURE' else null end,
       now()-make_interval(mins=>n*29)
from generate_series(1,120) n
on conflict(id) do update set stage=excluded.stage,mode=excluded.mode,status=excluded.status,latency_ms=excluded.latency_ms,token_estimate=excluded.token_estimate,error_code=excluded.error_code,created_at=excluded.created_at;
insert into public.audit_log(id,actor_id,action,target_type,target_id,metadata,created_at)
select md5('seed:audit-log:'||n)::uuid,null,
       case when n%4=0 then 'demo_config_review' when n%4=1 then 'demo_run_observed' when n%4=2 then 'demo_review_queue_opened' else 'demo_application_viewed' end,
       case when n%4=0 then 'config' when n%4=1 then 'agent_run' when n%4=2 then 'audit' else 'application' end,
       case when n%4=1 then md5('seed:agent-run:'||((n%120)+1))::uuid else md5('seed:submission:aarav')::uuid end,
       jsonb_build_object('source','fictional_seed','sequence',n),
       now()-make_interval(days=>n%30)
from generate_series(1,200) n
on conflict(id) do nothing;

-- Synthetic human-review outcomes for the admin agreement dashboard (local demo only).
insert into public.submissions(id,student_id,title,status,claimed_skill_ids,created_at,updated_at)
select md5('seed:human-review:submission:'||n)::uuid,
       case when n=1 then md5('seed:student:avi')::uuid
            when n=2 then md5('seed:student:akshit')::uuid
            else md5('seed:unia:student:'||(n+4))::uuid end,
       'Synthetic reviewed project '||n,'scored',
       case when n=1 then array[md5('seed:skill:sql')::uuid]
            when n=2 then array[md5('seed:skill:typescript')::uuid]
            else array[md5('seed:skill:react')::uuid] end,
       now()-make_interval(days=>n%25),now()-make_interval(days=>n%25)
from generate_series(1,30) n
on conflict(id) do update set student_id=excluded.student_id,status='scored',claimed_skill_ids=excluded.claimed_skill_ids,updated_at=excluded.updated_at;
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,evidence,next_steps,review_status,reviewed_by,reviewed_score,review_note,created_at)
select md5('seed:human-review:audit:'||n)::uuid,md5('seed:human-review:submission:'||n)::uuid,
       'web-frontend@1','audit@1',case when n=1 then 90 when n=2 then 58 else 60+(n%31) end,0.78,
       'Synthetic AI score and human review fixture; no real student work.',
       jsonb_build_array(jsonb_build_object('key','functionality','score',case when n=1 then 90 when n=2 then 58 else 60+(n%31) end)),
       '[]'::jsonb,array['Review test coverage','Explain one tradeoff'],
       'complete',md5('seed:auth:reviewer2@demo.aptohire.test')::uuid,
       case when n=1 then 90 when n=2 then 58 else 60+(n%31) end,
       'Synthetic demo human decision; review against fictional evidence only.',now()-make_interval(days=>n%25)
from generate_series(1,30) n
on conflict(id) do update set overall_score=excluded.overall_score,confidence=excluded.confidence,summary=excluded.summary,rubric=excluded.rubric,review_status='complete',reviewed_by=excluded.reviewed_by,reviewed_score=excluded.reviewed_score,review_note=excluded.review_note,created_at=excluded.created_at;
insert into public.skill_scores(id,student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
select md5('seed:human-review:score:'||n)::uuid,
       case when n=1 then md5('seed:student:avi')::uuid
            when n=2 then md5('seed:student:akshit')::uuid
            else md5('seed:unia:student:'||(n+4))::uuid end,
       case when n=1 then md5('seed:skill:sql')::uuid
            when n=2 then md5('seed:skill:typescript')::uuid
            else md5('seed:skill:react')::uuid end,
       case when n=1 then 90 when n=2 then 58 else 60+(n%31) end,
       case when n=1 then 'Advanced' when n=2 then 'Competent'
            when 60+(n%31)>=85 then 'Advanced' when 60+(n%31)>=70 then 'Proficient' else 'Competent' end,
       true,false,true,md5('seed:human-review:audit:'||n)::uuid,now()-make_interval(days=>n%25)
from generate_series(1,18) n
on conflict(id) do update set student_id=excluded.student_id,skill_id=excluded.skill_id,score=excluded.score,level=excluded.level,verified=true,pending_review=false,share_ok=true,audit_id=excluded.audit_id,updated_at=excluded.updated_at;
insert into public.skill_score_history(id,student_id,skill_id,score,level,verified,audit_id,created_at)
select md5('seed:human-review:score-history:'||n)::uuid,
       case when n=1 then md5('seed:student:avi')::uuid
            when n=2 then md5('seed:student:akshit')::uuid
            else md5('seed:unia:student:'||(n+4))::uuid end,
       case when n=1 then md5('seed:skill:sql')::uuid
            when n=2 then md5('seed:skill:typescript')::uuid
            else md5('seed:skill:react')::uuid end,
       case when n=1 then 90 when n=2 then 58 else 60+(n%31) end,
       case when n=1 then 'Advanced' when n=2 then 'Competent'
            when 60+(n%31)>=85 then 'Advanced' when 60+(n%31)>=70 then 'Proficient' else 'Competent' end,
       true,md5('seed:human-review:audit:'||n)::uuid,now()-make_interval(days=>n%25)
from generate_series(1,18) n
on conflict(id) do nothing;
insert into public.audit_log(id,actor_id,action,target_type,target_id,metadata,created_at)
select md5('seed:human-review:log:'||n)::uuid,md5('seed:auth:reviewer2@demo.aptohire.test')::uuid,
       'admin_audit_reviewed','audit',md5('seed:human-review:audit:'||n)::uuid,
       jsonb_build_object('decision','confirm','source','fictional_seed'),now()-make_interval(days=>n%25)
from generate_series(1,30) n on conflict(id) do nothing;

-- One resolved fictional appeal: reviewer3 confirms reviewer2's original decision.
update public.audits set reviewed_by=md5('seed:auth:reviewer2@demo.aptohire.test')::uuid,
  reviewed_score=overall_score,review_note='Synthetic initial reviewer decision for the demo ticket.'
where id=md5('seed:audit:aarav')::uuid;
insert into public.tickets(id,submission_id,student_id,reason,status,assigned_to,decision,original_reviewer_id,resolved_at)
values(md5('seed:ticket:aarav:confirmed')::uuid,md5('seed:submission:aarav')::uuid,md5('seed:student:aarav')::uuid,
       'Synthetic appeal fixture for the admin review demo.','open',null,null,md5('seed:auth:reviewer2@demo.aptohire.test')::uuid,null)
on conflict(id) do nothing;
update public.audits set reviewed_by=md5('seed:auth:reviewer3@demo.aptohire.test')::uuid,
  reviewed_score=overall_score,review_note='Synthetic second reviewer confirmed the original decision.'
where id=md5('seed:audit:aarav')::uuid;
update public.tickets set status='closed',assigned_to=md5('seed:auth:reviewer3@demo.aptohire.test')::uuid,
  decision='upheld',resolved_at=now(),original_reviewer_id=md5('seed:auth:reviewer2@demo.aptohire.test')::uuid
where id=md5('seed:ticket:aarav:confirmed')::uuid;
update public.submissions set status='scored',updated_at=now() where id=md5('seed:submission:aarav')::uuid;
insert into public.rubric_feedback_log(ticket_id,criterion,outcome,note)
select md5('seed:ticket:aarav:confirmed')::uuid,'general','upheld','Synthetic second reviewer confirmed the original decision.'
where not exists(select 1 from public.rubric_feedback_log where ticket_id=md5('seed:ticket:aarav:confirmed')::uuid and criterion='general');
insert into public.notifications(user_id,kind,payload)
select md5('seed:auth:aarav@unia.edu.test')::uuid,'appeal_update',jsonb_build_object('ticket_id',md5('seed:ticket:aarav:confirmed')::uuid,'status','closed','decision','upheld')
where not exists(select 1 from public.notifications where user_id=md5('seed:auth:aarav@unia.edu.test')::uuid and kind='appeal_update' and payload->>'ticket_id'=md5('seed:ticket:aarav:confirmed')::uuid::text);
insert into public.audit_log(id,actor_id,action,target_type,target_id,metadata,created_at)
values(md5('seed:human-review:ticket-decision-log')::uuid,md5('seed:auth:reviewer3@demo.aptohire.test')::uuid,
       'admin_ticket_decided','ticket',md5('seed:ticket:aarav:confirmed')::uuid,
       jsonb_build_object('decision','upheld','source','fictional_seed'),now())
on conflict(id) do nothing;
