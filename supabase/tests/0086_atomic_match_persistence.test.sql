begin;
select plan(20);

select has_function('public','persist_job_matches',array['uuid','uuid','jsonb'],'atomic job-match persistence RPC exists');
select ok(has_function_privilege('service_role','public.persist_job_matches(uuid,uuid,jsonb)','execute')
  and not has_function_privilege('authenticated','public.persist_job_matches(uuid,uuid,jsonb)','execute'),
  'only service_role can persist matches and emit new-match notifications');

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0990000-0000-4000-8000-000000000001','authenticated','authenticated','match-rpc-member@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0990000-0000-4000-8000-000000000002','authenticated','authenticated','match-rpc-outsider@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0990000-0000-4000-8000-000000000001','organization'),
 ('a0990000-0000-4000-8000-000000000002','organization');
insert into public.organizations(id,name,kind,size,website,status,subscription_status)
values
 ('a0990000-0000-4000-8000-000000000010','Synthetic Match RPC Org','corporate','small','https://match-rpc.example.test','approved','active'),
 ('a0990000-0000-4000-8000-000000000011','Synthetic Other Match Org','corporate','small','https://other-match-rpc.example.test','approved','active');
insert into public.organization_members(organization_id,user_id,member_role) values
 ('a0990000-0000-4000-8000-000000000010','a0990000-0000-4000-8000-000000000001','recruiter'),
 ('a0990000-0000-4000-8000-000000000011','a0990000-0000-4000-8000-000000000002','recruiter');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000010','Synthetic Match RPC Job','Fixture','open','[]'::jsonb,1);
insert into public.students(id,full_name,primary_email)
values('a0990000-0000-4000-8000-000000000030','Synthetic Match RPC Student','match-rpc-student@demo.aptohire.test');

set local role service_role;
update public.organizations set subscription_status='inactive' where id='a0990000-0000-4000-8000-000000000010';
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001','[]'::jsonb)$$,
  '42501',null,'RPC rejects organization members while the organization subscription is inactive');
update public.organizations set subscription_status='active' where id='a0990000-0000-4000-8000-000000000010';
update public.jobs set status='closed' where id='a0990000-0000-4000-8000-000000000020';
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001','[]'::jsonb)$$,
  '42501',null,'RPC rejects a job that is no longer open');
update public.jobs set status='open' where id='a0990000-0000-4000-8000-000000000020';

select is(
  (select array[candidate_count,new_match_count]::integer[] from public.persist_job_matches(
    'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
    jsonb_build_array(jsonb_build_object(
      'job_id','a0990000-0000-4000-8000-000000000020'::uuid,
      'student_id','a0990000-0000-4000-8000-000000000030'::uuid,
      'alias','Candidate ABC234','final_score',80,'confidence',0.9,
      'reasons',array['Verified Synthetic Skill — Advanced (90)'],'gaps',array[]::text[],
      'structured_score',80,'vector_score',null
    )))),
  array[1,1]::integer[],
  'first persistence commits one match and reports one genuinely new candidate'
);
select ok(exists(select 1 from public.notifications where user_id='a0990000-0000-4000-8000-000000000001' and kind='new_match'),
  'first match persistence notifies the organization member');
select is((select count(*)::integer from public.notifications where user_id='a0990000-0000-4000-8000-000000000002' and kind='new_match'),0,
  'new-match notification is not sent to a member of another organization');
select is((select payload from public.notifications where user_id='a0990000-0000-4000-8000-000000000001' and kind='new_match'),
  jsonb_build_object('job_id','a0990000-0000-4000-8000-000000000020','new_match_count',1),
  'new-match notification contains only job id and new-candidate count');
select ok(exists(select 1 from public.audit_log where actor_id='a0990000-0000-4000-8000-000000000001'
  and action='match_job_computed' and target_id='a0990000-0000-4000-8000-000000000020'),
  'match persistence writes its audit event in the same transaction');

select is(
  (select array[candidate_count,new_match_count]::integer[] from public.persist_job_matches(
    'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
    jsonb_build_array(jsonb_build_object(
      'job_id','a0990000-0000-4000-8000-000000000020'::uuid,
      'student_id','a0990000-0000-4000-8000-000000000030'::uuid,
      'alias','Candidate ABC234','final_score',81,'confidence',0.9,
      'reasons',array['Verified Synthetic Skill — Advanced (90)'],'gaps',array[]::text[],
      'structured_score',81,'vector_score',null
    )))),
  array[1,0]::integer[],
  'rerun updates the existing match but does not report it as a new candidate'
);
select is((select count(*)::integer from public.notifications where user_id='a0990000-0000-4000-8000-000000000001' and kind='new_match'),1,
  'rerun does not duplicate the new-match notification');
select is((select final_score from public.match_results where job_id='a0990000-0000-4000-8000-000000000020' and student_id='a0990000-0000-4000-8000-000000000030'),81::numeric,
  'rerun updates the stored match score');
select is(
  (select array[candidate_count,new_match_count]::integer[] from public.persist_job_matches(
    'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001','[]'::jsonb)),
  array[0,0]::integer[],
  'empty result batch returns zero counts without deleting prior results'
);

select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
  '[{"job_id":"a0990000-0000-4000-8000-000000000020","student_id":"a0990000-0000-4000-8000-000000000030","alias":"Candidate ABC234","final_score":80,"confidence":0.9,"reasons":[],"gaps":[],"structured_score":80,"vector_score":null,"student_email":"private"}]'::jsonb)$$,
  '22023',null,'RPC rejects unexpected identity fields in match rows');
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
  '[{"job_id":"a0990000-0000-4000-8000-000000000020","student_id":"a0990000-0000-4000-8000-000000000030","alias":"Candidate private","final_score":80,"confidence":0.9,"reasons":[],"gaps":[],"structured_score":80,"vector_score":null}]'::jsonb)$$,
  '22023',null,'RPC rejects an alias outside the blind alias contract');
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
  '[{"job_id":"a0990000-0000-4000-8000-000000000020","student_id":"a0990000-0000-4000-8000-000000000030","alias":"Candidate ABC234","final_score":80,"confidence":0.9,"reasons":[7],"gaps":[],"structured_score":80,"vector_score":null}]'::jsonb)$$,
  '22023',null,'RPC rejects non-string reason values before casting result rows');
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001','{}'::jsonb)$$,
  '22023',null,'RPC rejects non-array match batches with a controlled validation error');
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
  '[{"job_id":"a0990000-0000-4000-8000-000000000020","student_id":"a0990000-0000-4000-8000-000000000030","alias":"Candidate ABC234","final_score":80,"confidence":0.9,"reasons":[],"gaps":[],"structured_score":80,"vector_score":null},{"job_id":"a0990000-0000-4000-8000-000000000020","student_id":"a0990000-0000-4000-8000-000000000030","alias":"Candidate ABC234","final_score":80,"confidence":0.9,"reasons":[],"gaps":[],"structured_score":80,"vector_score":null}]'::jsonb)$$,
  '22023',null,'RPC rejects duplicate student rows in a batch');
update public.students set visibility=jsonb_set(visibility,'{discoverable}','false'::jsonb)
where id='a0990000-0000-4000-8000-000000000030';
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000001',
  '[{"job_id":"a0990000-0000-4000-8000-000000000020","student_id":"a0990000-0000-4000-8000-000000000030","alias":"Candidate ABC234","final_score":80,"confidence":0.9,"reasons":[],"gaps":[],"structured_score":80,"vector_score":null}]'::jsonb)$$,
  '42501',null,'RPC rechecks live discoverability and rejects a student who opted out after candidate retrieval');
update public.students set visibility=jsonb_set(visibility,'{discoverable}','true'::jsonb)
where id='a0990000-0000-4000-8000-000000000030';
select throws_ok($$select * from public.persist_job_matches(
  'a0990000-0000-4000-8000-000000000020','a0990000-0000-4000-8000-000000000002','[]'::jsonb)$$,
  '42501',null,'RPC rejects actors who are not members of the job organization');

reset role;
select * from finish();
rollback;
