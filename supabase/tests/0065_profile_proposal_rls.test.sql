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
select plan(9);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0650000-0000-4000-8000-000000000001','authenticated','authenticated','proposal-owner@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0650000-0000-4000-8000-000000000002','authenticated','authenticated','proposal-other@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0650000-0000-4000-8000-000000000001','student'),
 ('a0650000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
 ('a0650000-0000-4000-8000-000000000011','a0650000-0000-4000-8000-000000000001','Synthetic Proposal Owner','proposal-owner@demo.aptohire.test'),
 ('a0650000-0000-4000-8000-000000000012','a0650000-0000-4000-8000-000000000002','Synthetic Other Student','proposal-other@demo.aptohire.test');
insert into public.profile_proposals(id,student_id,changes,state) values
 ('a0650000-0000-4000-8000-000000000021','a0650000-0000-4000-8000-000000000011','{"headline":"Synthetic pending"}'::jsonb,'pending'),
 ('a0650000-0000-4000-8000-000000000022','a0650000-0000-4000-8000-000000000012','{"headline":"Other pending"}'::jsonb,'pending');

select is((select count(*)::int from pg_policies where schemaname='public' and tablename='profile_proposals'
  and 'authenticated'::name=any(roles) and ((policyname='profile_proposals_self_select' and cmd='SELECT')
  or (policyname='profile_proposals_self_update' and cmd='UPDATE'))),2,
  'profile proposal owner read/update policy definitions are present');
select ok(has_column_privilege('authenticated','public.profile_proposals','state','UPDATE')
  and not has_column_privilege('authenticated','public.profile_proposals','changes','UPDATE'),
  'students can update proposal state but cannot rewrite proposed content');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0650000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.profile_proposals where id='a0650000-0000-4000-8000-000000000021'),1,'student can read own profile proposal');
select is((select count(*)::int from public.profile_proposals where id='a0650000-0000-4000-8000-000000000022'),0,'student cannot read another student profile proposal');
select is(pg_temp.dml_row_count($$update public.profile_proposals set state='approved' where id='a0650000-0000-4000-8000-000000000021'$$),1,'student can approve own pending proposal');
select is(pg_temp.dml_row_count($$update public.profile_proposals set state='dismissed' where id='a0650000-0000-4000-8000-000000000022'$$),0,'student cannot update another student proposal');
select throws_ok($$update public.profile_proposals set state='pending' where id='a0650000-0000-4000-8000-000000000021'$$,'42501',null,'proposal update cannot retain pending state');
select throws_ok($$update public.profile_proposals set changes='{"headline":"tampered"}'::jsonb where id='a0650000-0000-4000-8000-000000000021'$$,'42501',null,'student cannot alter proposal contents');
reset role;
select is((select state from public.profile_proposals where id='a0650000-0000-4000-8000-000000000021'),'approved','owner decision persists');

select * from finish();
rollback;
