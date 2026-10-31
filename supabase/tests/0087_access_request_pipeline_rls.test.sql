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
select plan(31);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0870000-0000-4000-8000-000000000001','authenticated','authenticated','pipeline-org-a@demo.aptohire.test',extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0870000-0000-4000-8000-000000000002','authenticated','authenticated','pipeline-org-b@demo.aptohire.test',extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0870000-0000-4000-8000-000000000003','authenticated','authenticated','pipeline-student@demo.aptohire.test',extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.organizations(id,name,status,subscription_status)
values
 ('a0870000-0000-4000-8000-000000000010','Synthetic Pipeline Org A','approved','active'),
 ('a0870000-0000-4000-8000-000000000011','Synthetic Pipeline Org B','approved','active');
insert into public.organization_members(organization_id,user_id,member_role)
values
 ('a0870000-0000-4000-8000-000000000010','a0870000-0000-4000-8000-000000000001','recruiter'),
 ('a0870000-0000-4000-8000-000000000011','a0870000-0000-4000-8000-000000000002','recruiter');
insert into public.students(id,full_name,primary_email)
values('a0870000-0000-4000-8000-000000000020','Synthetic Pipeline Student','pipeline-student@demo.aptohire.test');
insert into public.jobs(id,organization_id,title,description,status,required_skills,openings)
values
 ('a0870000-0000-4000-8000-000000000030','a0870000-0000-4000-8000-000000000010','Synthetic Pipeline Job A','Fixture','open','[]'::jsonb,1),
 ('a0870000-0000-4000-8000-000000000031','a0870000-0000-4000-8000-000000000011','Synthetic Pipeline Job B','Fixture','open','[]'::jsonb,1),
 ('a0870000-0000-4000-8000-000000000032','a0870000-0000-4000-8000-000000000010','Synthetic Pipeline Job A Pending','Fixture','open','[]'::jsonb,1),
 ('a0870000-0000-4000-8000-000000000033','a0870000-0000-4000-8000-000000000010','Synthetic Pipeline Job A Expired','Fixture','open','[]'::jsonb,1);
insert into public.access_requests(id,organization_id,student_id,job_id,requested_scope,granted_scope,duration_days,status,responded_at,expires_at)
values
 ('a0870000-0000-4000-8000-000000000040','a0870000-0000-4000-8000-000000000010','a0870000-0000-4000-8000-000000000020','a0870000-0000-4000-8000-000000000030',array['profile'],array['profile'],30,'accepted',now(),now()+interval '10 days'),
 ('a0870000-0000-4000-8000-000000000041','a0870000-0000-4000-8000-000000000010','a0870000-0000-4000-8000-000000000020','a0870000-0000-4000-8000-000000000032',array['profile'],'{}',30,'pending',null,null),
 ('a0870000-0000-4000-8000-000000000042','a0870000-0000-4000-8000-000000000010','a0870000-0000-4000-8000-000000000020','a0870000-0000-4000-8000-000000000033',array['profile'],array['profile'],30,'accepted',now(),now()-interval '1 day'),
 ('a0870000-0000-4000-8000-000000000043','a0870000-0000-4000-8000-000000000011','a0870000-0000-4000-8000-000000000020','a0870000-0000-4000-8000-000000000031',array['profile'],array['profile'],30,'accepted',now(),now()+interval '10 days');

select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='access_requests'
  and policyname='organization_pipeline_stage_read' and cmd='SELECT'
  and qual ilike '%organization_id%' and qual ilike '%status%' and qual ilike '%expires_at%'),
  'pipeline-stage read policy is organization-scoped to accepted, unexpired grants');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='access_requests'
  and policyname='organization_pipeline_stage_update' and cmd='UPDATE'
  and qual ilike '%organization_id%' and qual ilike '%status%' and qual ilike '%expires_at%'
  and with_check ilike '%organization_id%' and with_check ilike '%status%' and with_check ilike '%expires_at%'),
  'pipeline-stage update policy constrains both old and new row to an accepted, unexpired organization grant');
select ok(has_column_privilege('authenticated','public.access_requests','id','SELECT'), 'organization can select request id');
select ok(has_column_privilege('authenticated','public.access_requests','organization_id','SELECT'), 'organization can select its organization id');
select ok(has_column_privilege('authenticated','public.access_requests','status','SELECT'), 'organization can select request status');
select ok(has_column_privilege('authenticated','public.access_requests','expires_at','SELECT'), 'organization can select expiry');
select ok(has_column_privilege('authenticated','public.access_requests','pipeline_stage','SELECT'), 'organization can select the pipeline stage');
select ok(not has_column_privilege('authenticated','public.access_requests','student_id','SELECT'), 'organization cannot select student identity through the base request table');
select ok(not has_column_privilege('authenticated','public.access_requests','job_id','SELECT'), 'organization cannot select job identity through the base request table');
select ok(not has_column_privilege('authenticated','public.access_requests','requested_scope','SELECT'), 'organization cannot select the request scope through the base request table');
select ok(not has_column_privilege('authenticated','public.access_requests','granted_scope','SELECT'), 'organization cannot select granted scopes through the base request table');
select ok(has_column_privilege('authenticated','public.access_requests','pipeline_stage','UPDATE'), 'organization has the narrow pipeline-stage update grant');
select ok(not has_column_privilege('authenticated','public.access_requests','status','UPDATE'), 'organization cannot change request status');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0870000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000040'),1,'organization A can see its accepted unexpired request');
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000041'),0,'organization A cannot see a pending request');
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000042'),0,'organization A cannot see an expired accepted request');
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000043'),0,'organization A cannot see organization B request');
select throws_ok($$select student_id from public.access_requests where id='a0870000-0000-4000-8000-000000000040'$$,
  '42501',null,'direct student identity projection is denied by column grants');
select throws_ok($$select * from public.access_requests where id='a0870000-0000-4000-8000-000000000040'$$,
  '42501',null,'wildcard request selection is denied because identity-bearing columns are not granted');
select is(pg_temp.dml_row_count($$update public.access_requests set pipeline_stage='offered' where id='a0870000-0000-4000-8000-000000000040'$$),1,'organization A can update the stage of its accepted unexpired request');
select is(pg_temp.dml_row_count($$update public.access_requests set pipeline_stage='interviewing' where id='a0870000-0000-4000-8000-000000000041'$$),0,'organization A cannot update a pending request');
select is(pg_temp.dml_row_count($$update public.access_requests set pipeline_stage='closed' where id='a0870000-0000-4000-8000-000000000042'$$),0,'organization A cannot update an expired request');
select is(pg_temp.dml_row_count($$update public.access_requests set pipeline_stage='interviewing' where id='a0870000-0000-4000-8000-000000000043'$$),0,'organization A cannot update organization B request');
select throws_ok($$update public.access_requests set status='declined' where id='a0870000-0000-4000-8000-000000000040'$$,
  '42501',null,'organization cannot mutate request status through its pipeline-stage grant');

select set_config('request.jwt.claims','{"sub":"a0870000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000043'),1,'organization B can see its own accepted unexpired request');
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000040'),0,'organization B cannot see organization A request');
select set_config('request.jwt.claims','{"sub":"a0870000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(id)::integer from public.access_requests where id='a0870000-0000-4000-8000-000000000040'),0,'student without organization membership cannot read pipeline rows');

reset role;
select is((select pipeline_stage from public.access_requests where id='a0870000-0000-4000-8000-000000000040'),'offered','accepted row stores the authorized pipeline update');
select ok((select pipeline_stage is null from public.access_requests where id='a0870000-0000-4000-8000-000000000041'),'pending row remains unchanged after denied update');
select ok((select pipeline_stage is null from public.access_requests where id='a0870000-0000-4000-8000-000000000042'),'expired row remains unchanged after denied update');
select ok((select pipeline_stage is null from public.access_requests where id='a0870000-0000-4000-8000-000000000043'),'cross-organization row remains unchanged after denied update');

select * from finish();
rollback;
