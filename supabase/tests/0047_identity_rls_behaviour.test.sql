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
select plan(43);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0470000-0000-4000-8000-000000000001','authenticated','authenticated','rls-student-a@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0470000-0000-4000-8000-000000000002','authenticated','authenticated','rls-student-b@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0470000-0000-4000-8000-000000000003','authenticated','authenticated','rls-admin@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0470000-0000-4000-8000-000000000001','student'),
 ('a0470000-0000-4000-8000-000000000002','student'),
 ('a0470000-0000-4000-8000-000000000003','admin');
insert into public.students(id,user_id,full_name,primary_email) values
 ('a0470000-0000-4000-8000-000000000011','a0470000-0000-4000-8000-000000000001','Synthetic RLS Student A','rls-student-a@demo.aptohire.test'),
 ('a0470000-0000-4000-8000-000000000012','a0470000-0000-4000-8000-000000000002','Synthetic RLS Student B','rls-student-b@demo.aptohire.test');
insert into public.universities(id,name,status) values
 ('a0470000-0000-4000-8000-000000000020','Synthetic Identity RLS University','approved');
insert into public.affiliations(id,student_id,university_id,verification,status,is_current)
values
 ('a0470000-0000-4000-8000-000000000021','a0470000-0000-4000-8000-000000000011','a0470000-0000-4000-8000-000000000020','unverified','student',true),
 ('a0470000-0000-4000-8000-000000000022','a0470000-0000-4000-8000-000000000012','a0470000-0000-4000-8000-000000000020','unverified','student',true);
insert into public.affiliation_proposals(id,student_id,university_id,status,state)
values
 ('a0470000-0000-4000-8000-000000000031','a0470000-0000-4000-8000-000000000011','a0470000-0000-4000-8000-000000000020','student','pending'),
 ('a0470000-0000-4000-8000-000000000032','a0470000-0000-4000-8000-000000000012','a0470000-0000-4000-8000-000000000020','student','pending');
insert into public.profile_sources(id,student_id,source_type)
values
 ('a0470000-0000-4000-8000-000000000041','a0470000-0000-4000-8000-000000000011','github'),
 ('a0470000-0000-4000-8000-000000000042','a0470000-0000-4000-8000-000000000012','github');

select is(
  (select count(*)::int from pg_policies
    where schemaname='public' and 'authenticated'::name=any(roles)
      and ( (tablename='profiles' and policyname='profiles_self_read' and cmd='SELECT')
         or (tablename='students' and policyname='students_self_read' and cmd='SELECT')
         or (tablename='students' and policyname='students_self_update' and cmd='UPDATE')
         or (tablename='affiliations' and policyname='affiliations_self_read' and cmd='SELECT')
         or (tablename='affiliation_proposals' and policyname='proposals_self_read' and cmd='SELECT')
         or (tablename='profile_sources' and policyname='sources_self_read' and cmd='SELECT') )),
  6,
  'the six identity policy definitions exercised below remain present for authenticated access'
);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0470000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.profiles where id='a0470000-0000-4000-8000-000000000001'),1,'student A can read own profile');
select is((select count(*)::int from public.profiles where id='a0470000-0000-4000-8000-000000000002'),0,'student A cannot read student B profile');
select is((select count(*)::int from public.students where id='a0470000-0000-4000-8000-000000000011'),1,'student A can read own student row');
select is((select count(*)::int from public.students where id='a0470000-0000-4000-8000-000000000012'),0,'student A cannot read student B row');
select is((select count(*)::int from public.affiliations where id='a0470000-0000-4000-8000-000000000021'),1,'student A can read own affiliation');
select is((select count(*)::int from public.affiliations where id='a0470000-0000-4000-8000-000000000022'),0,'student A cannot read student B affiliation');
select is((select count(*)::int from public.affiliation_proposals where id='a0470000-0000-4000-8000-000000000031'),1,'student A can read own affiliation proposal');
select is((select count(*)::int from public.affiliation_proposals where id='a0470000-0000-4000-8000-000000000032'),0,'student A cannot read student B affiliation proposal');
select is((select count(*)::int from public.profile_sources where id='a0470000-0000-4000-8000-000000000041'),1,'student A can read own profile source');
select is((select count(*)::int from public.profile_sources where id='a0470000-0000-4000-8000-000000000042'),0,'student A cannot read student B profile source');
select is(pg_temp.dml_row_count($$update public.students set full_name='Synthetic RLS Student A Updated' where id='a0470000-0000-4000-8000-000000000011'$$),1,'student A can update own permitted profile fields');
select is(pg_temp.dml_row_count($$update public.students set full_name='Unauthorized Change' where id='a0470000-0000-4000-8000-000000000012'$$),0,'student A cannot update student B');
select ok(not has_table_privilege('authenticated','public.profiles','UPDATE'),'authenticated cannot update profile rows or roles');
select ok(not has_column_privilege('authenticated','public.profiles','role','UPDATE'),'authenticated cannot update the role column');

select set_config('request.jwt.claims','{"sub":"a0470000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.profiles where id='a0470000-0000-4000-8000-000000000002'),1,'student B can read own profile');
select is((select count(*)::int from public.students where id='a0470000-0000-4000-8000-000000000012'),1,'student B can read own student row');
select is((select count(*)::int from public.students where id='a0470000-0000-4000-8000-000000000011'),0,'student B cannot read student A row');
select is((select count(*)::int from public.affiliations where id='a0470000-0000-4000-8000-000000000022'),1,'student B can read own affiliation');
select is((select count(*)::int from public.affiliations where id='a0470000-0000-4000-8000-000000000021'),0,'student B cannot read student A affiliation');
select is((select count(*)::int from public.affiliation_proposals where id='a0470000-0000-4000-8000-000000000032'),1,'student B can read own affiliation proposal');
select is((select count(*)::int from public.affiliation_proposals where id='a0470000-0000-4000-8000-000000000031'),0,'student B cannot read student A affiliation proposal');
select is((select count(*)::int from public.profile_sources where id='a0470000-0000-4000-8000-000000000042'),1,'student B can read own profile source');
select is((select count(*)::int from public.profile_sources where id='a0470000-0000-4000-8000-000000000041'),0,'student B cannot read student A profile source');

select set_config('request.jwt.claims','{"sub":"a0470000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select ok(not private.is_admin(),'aal1 admin fails the database admin gate');
select is((select count(*)::int from public.admin_users_v where user_id='a0470000-0000-4000-8000-000000000003'),0,'aal1 admin cannot read gated admin users view');
select is((select count(*)::int from public.admin_counts_v),0,'aal1 admin cannot read gated admin counts view');
select is((select count(*)::int from public.admin_agent_stats_v),0,'aal1 admin cannot read agent statistics view');
select is((select count(*)::int from public.admin_agreement_v),0,'aal1 admin cannot read audit-agreement view');
select is((select count(*)::int from public.admin_audit_log_v),0,'aal1 admin cannot read audit-log view');
select is((select count(*)::int from public.admin_borderline_v),0,'aal1 admin cannot read borderline queue view');
select is((select count(*)::int from public.admin_tickets_v),0,'aal1 admin cannot read tickets view');
select is((select count(*)::int from public.admin_app_config_v),0,'aal1 admin cannot read admin config view');
select is((select count(*)::int from public.affiliations where id in ('a0470000-0000-4000-8000-000000000021','a0470000-0000-4000-8000-000000000022')),0,'aal1 admin cannot read affiliation rows');
select is((select count(*)::int from public.affiliation_proposals where id in ('a0470000-0000-4000-8000-000000000031','a0470000-0000-4000-8000-000000000032')),0,'aal1 admin cannot read affiliation proposal rows');
select is((select count(*)::int from public.profile_sources where id in ('a0470000-0000-4000-8000-000000000041','a0470000-0000-4000-8000-000000000042')),0,'aal1 admin cannot read profile source rows');

select set_config('request.jwt.claims','{"sub":"a0470000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
select ok(private.is_admin(),'aal2 admin passes the database admin gate');
select is((select count(*)::int from public.admin_users_v where user_id='a0470000-0000-4000-8000-000000000003'),1,'aal2 admin can read gated admin user row');
select is((select count(*)::int from public.profiles where id in ('a0470000-0000-4000-8000-000000000001','a0470000-0000-4000-8000-000000000002','a0470000-0000-4000-8000-000000000003')),3,'aal2 admin can read the authorized profile set');
select is((select count(*)::int from public.students where id in ('a0470000-0000-4000-8000-000000000011','a0470000-0000-4000-8000-000000000012')),2,'aal2 admin can read the authorized student set');
select is((select count(*)::int from public.affiliations where id in ('a0470000-0000-4000-8000-000000000021','a0470000-0000-4000-8000-000000000022')),2,'aal2 admin can read affiliation rows');
select is((select count(*)::int from public.affiliation_proposals where id in ('a0470000-0000-4000-8000-000000000031','a0470000-0000-4000-8000-000000000032')),2,'aal2 admin can read affiliation proposal rows');
select is((select count(*)::int from public.profile_sources where id in ('a0470000-0000-4000-8000-000000000041','a0470000-0000-4000-8000-000000000042')),2,'aal2 admin can read profile source rows');

select * from finish();
rollback;
