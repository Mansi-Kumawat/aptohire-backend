begin;
create function pg_temp.dml_row_count(p_sql text) returns integer
language plpgsql
as $$
declare
  affected_rows integer;
begin
  execute p_sql;
  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;
select plan(26);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a6160000-0000-4000-8000-000000000001','authenticated','authenticated','feedback-org@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
 ('a6160000-0000-4000-8000-000000000008','authenticated','authenticated','feedback-student@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.organizations(id,name,status,subscription_status)
values('a6160000-0000-4000-8000-000000000002','Fictional Feedback Org','approved','active'),
      ('a6160000-0000-4000-8000-000000000003','Fictional Other Org','approved','active');
insert into public.organization_members(organization_id,user_id)
values('a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000001');
insert into public.students(id,user_id,full_name)
values('a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000008','Fictional Feedback Student');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values('a6160000-0000-4000-8000-000000000005','a6160000-0000-4000-8000-000000000002','Fictional Job','Fixture','open','[]'::jsonb,1),
      ('a6160000-0000-4000-8000-000000000009','a6160000-0000-4000-8000-000000000002','Fictional Pending Job','Fixture','open','[]'::jsonb,1);
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,granted_scope,duration_days,status,responded_at,expires_at)
values('a6160000-0000-4000-8000-000000000006','a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000005',array['profile'],array['profile'],30,'accepted',now(),now()+interval '10 days'),
      ('a6160000-0000-4000-8000-000000000007','a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000009',array['profile'],'{}',30,'pending',null,null);
insert into public.feedback_options(option_code,label) values('great_communication','Great communication') on conflict(option_code) do update set label=excluded.label;

select ok(exists(
  select 1 from pg_policies
   where schemaname='public' and tablename='feedback'
     and policyname='feedback_org_insert' and cmd='INSERT'
     and 'authenticated'::name=any(roles)
     and with_check ilike '%feedback_request_allowed%'
),'feedback_org_insert is the authenticated insert gate and delegates consent checks');
select has_function('private','feedback_request_allowed',array['uuid','uuid','uuid','text[]'],'narrow feedback authorization helper exists');
select ok(has_function_privilege('authenticated','private.feedback_request_allowed(uuid,uuid,uuid,text[])','execute'),'authenticated policy role can evaluate the helper');
select ok(not has_function_privilege('anon','private.feedback_request_allowed(uuid,uuid,uuid,text[])','execute'),'anonymous cannot evaluate the private helper');
select ok(has_column_privilege('authenticated','public.access_requests','pipeline_stage','UPDATE'),'authenticated role has only the granted pipeline-stage update column');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='access_requests'
 and policyname='organization_pipeline_stage_update' and cmd='UPDATE'
 and with_check ilike '%expires_at%'),'organization pipeline update policy is limited to accepted unexpired requests');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='access_requests'
 and policyname='organization_pipeline_stage_read' and cmd='SELECT'
 and qual ilike '%status%' and qual ilike '%expires_at%' and qual ilike '%my_org_ids%'),
 'pipeline UPDATE has a matching accepted, unexpired organization-only row visibility policy');
select ok(not has_table_privilege('authenticated','public.access_requests','select'),'organization is not granted access to identity-bearing request rows');
select ok(has_column_privilege('authenticated','public.feedback','organization_id','insert') and has_column_privilege('authenticated','public.feedback','option_codes','insert'),'organization retains only the intended feedback insert path');
select ok(not has_table_privilege('authenticated','public.feedback','update') and not has_table_privilege('authenticated','public.feedback','delete'),'feedback is append-only for authenticated users');
select ok(has_table_privilege('authenticated','public.feedback_options','select'),'authenticated portals can read the feedback option catalog');
select ok(not has_table_privilege('anon','public.feedback_options','select'),'anonymous role cannot read the feedback option catalog');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='feedback_options'
 and policyname='feedback_options_authenticated_read' and cmd='SELECT' and 'authenticated'::name=any(roles)
 and qual='true'),'feedback option catalog uses its explicit authenticated read policy');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a6160000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.feedback_options where option_code='great_communication'),1,'organization member can read authenticated feedback options');
select is(pg_temp.dml_row_count($$update public.access_requests set pipeline_stage='interviewing' where id='a6160000-0000-4000-8000-000000000006'$$),1,'organization member can set pipeline stage for accepted unexpired request');
select set_config('request.jwt.claims','{"sub":"a6160000-0000-4000-8000-000000000008","role":"authenticated","aal":"aal1"}',true);
select is(pg_temp.dml_row_count($$update public.access_requests set pipeline_stage='offered' where id='a6160000-0000-4000-8000-000000000006'$$),0,'student cannot set organization pipeline stage');
select set_config('request.jwt.claims','{"sub":"a6160000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select ok(private.feedback_request_allowed('a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000006',array['great_communication']),'member may reference their accepted student request');
select ok(not private.feedback_request_allowed('a6160000-0000-4000-8000-000000000003','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000006',array['great_communication']),'member cannot act for a different organization');
select lives_ok($$insert into public.feedback(organization_id,student_id,request_id,option_codes,note) values('a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000006',array['great_communication'],'Fictional, job-related feedback.')$$,'valid consented feedback insert succeeds');
select throws_ok($$insert into public.feedback(organization_id,student_id,request_id,option_codes) values('a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000007',array['great_communication'])$$,'42501',null,'pending request cannot authorize feedback');
select throws_ok($$insert into public.feedback(organization_id,student_id,request_id,option_codes) values('a6160000-0000-4000-8000-000000000003','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000006',array['great_communication'])$$,'42501',null,'other organization cannot insert feedback');
select throws_ok($$insert into public.feedback(organization_id,student_id,request_id,option_codes) values('a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000006',array['unknown_code'])$$,'42501',null,'feedback option codes must be allowlisted');
select throws_ok($$insert into public.feedback(organization_id,student_id,request_id,option_codes,note) values('a6160000-0000-4000-8000-000000000002','a6160000-0000-4000-8000-000000000004','a6160000-0000-4000-8000-000000000006',array['great_communication'],repeat('x',281))$$,'42501',null,'feedback notes are limited to 280 characters');
reset role;
select is((select count(*) from public.feedback where request_id='a6160000-0000-4000-8000-000000000006'),1::bigint,'only the valid feedback row persists');
select ok(exists(select 1 from public.notifications where user_id='a6160000-0000-4000-8000-000000000008' and kind='feedback_received' and payload->>'feedback_id'=(select id::text from public.feedback where request_id='a6160000-0000-4000-8000-000000000006')),'valid feedback notifies its student recipient');
select ok(not exists(select 1 from public.notifications where kind='feedback_received' and payload ?| array['student_id','email','full_name']),'feedback notification omits student identity fields');
select * from finish();
rollback;
