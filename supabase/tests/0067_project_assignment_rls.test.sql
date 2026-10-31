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
select plan(12);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0670000-0000-4000-8000-000000000001','authenticated','authenticated','assignment-owner@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0670000-0000-4000-8000-000000000002','authenticated','authenticated','assignment-other@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0670000-0000-4000-8000-000000000001','student'),
 ('a0670000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
 ('a0670000-0000-4000-8000-000000000011','a0670000-0000-4000-8000-000000000001','Synthetic Assignment Owner','assignment-owner@demo.aptohire.test'),
 ('a0670000-0000-4000-8000-000000000012','a0670000-0000-4000-8000-000000000002','Synthetic Other Student','assignment-other@demo.aptohire.test');
insert into public.project_assignments(id,student_id,status,brief) values
 ('a0670000-0000-4000-8000-000000000021','a0670000-0000-4000-8000-000000000011','assigned','{"title":"Synthetic assignment"}'::jsonb),
 ('a0670000-0000-4000-8000-000000000022','a0670000-0000-4000-8000-000000000012','assigned','{"title":"Other assignment"}'::jsonb);

select is((select count(*)::int from pg_policies where schemaname='public' and tablename='project_assignments'
 and 'authenticated'::name=any(roles) and ((policyname='assignment_owner_select' and cmd='SELECT')
 or (policyname='assignment_owner_insert' and cmd='INSERT') or (policyname='assignment_in_progress' and cmd='UPDATE'))),3,
 'assignment owner policies are present for the behavior cases below');
select ok(has_column_privilege('authenticated','public.project_assignments','status','UPDATE')
 and not has_column_privilege('authenticated','public.project_assignments','student_id','UPDATE'),
 'students can update assignment status but cannot transfer ownership');
select ok(has_column_privilege('authenticated','public.project_assignments','variation_fingerprint','INSERT')
 and not has_column_privilege('authenticated','public.project_assignments','variation_fingerprint','UPDATE'),
 'assignment endpoint may insert a variation fingerprint but students cannot later change it');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0670000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.project_assignments where id='a0670000-0000-4000-8000-000000000021'),1,'student can read own assignment');
select is((select count(*)::int from public.project_assignments where id='a0670000-0000-4000-8000-000000000022'),0,'student cannot read another student assignment');
select is(pg_temp.dml_row_count($$insert into public.project_assignments(student_id,status,brief,variation_fingerprint)
 values('a0670000-0000-4000-8000-000000000011','assigned','{"title":"New synthetic task"}'::jsonb,repeat('a',64))$$),1,'student can create own assignment with the server-derived fingerprint');
select is((select variation_fingerprint from public.project_assignments where student_id='a0670000-0000-4000-8000-000000000011' and brief->>'title'='New synthetic task'),repeat('a',64),'valid fingerprint is stored');
select throws_ok($$insert into public.project_assignments(student_id,status,brief,variation_fingerprint)
 values('a0670000-0000-4000-8000-000000000011','assigned','{}'::jsonb,'not-a-hmac')$$,'23514',null,'invalid fingerprint format is rejected');
select throws_ok($$insert into public.project_assignments(student_id,status,brief)
 values('a0670000-0000-4000-8000-000000000012','assigned','{}'::jsonb)$$,'42501',null,'student cannot create another student assignment');
select is(pg_temp.dml_row_count($$update public.project_assignments set status='in_progress'
 where id='a0670000-0000-4000-8000-000000000021'$$),1,'student can move own assignment into progress');
select throws_ok($$update public.project_assignments set status='completed'
 where id='a0670000-0000-4000-8000-000000000021'$$,'42501',null,'student cannot set an assignment status outside the permitted state');
select is(pg_temp.dml_row_count($$update public.project_assignments set status='in_progress'
 where id='a0670000-0000-4000-8000-000000000022'$$),0,'student cannot update another student assignment');

select * from finish();
rollback;
