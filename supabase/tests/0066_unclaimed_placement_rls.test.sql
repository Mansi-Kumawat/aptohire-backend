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
 ('a0660000-0000-4000-8000-000000000001','authenticated','authenticated','placement-uni-a@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0660000-0000-4000-8000-000000000002','authenticated','authenticated','placement-uni-b@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0660000-0000-4000-8000-000000000001','university'),
 ('a0660000-0000-4000-8000-000000000002','university');
insert into public.universities(id,name,status) values
 ('a0660000-0000-4000-8000-000000000011','Synthetic Placement University A','approved'),
 ('a0660000-0000-4000-8000-000000000012','Synthetic Placement University B','approved');
insert into public.university_members(university_id,user_id,member_role) values
 ('a0660000-0000-4000-8000-000000000011','a0660000-0000-4000-8000-000000000001','tpo'),
 ('a0660000-0000-4000-8000-000000000012','a0660000-0000-4000-8000-000000000002','tpo');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,program,year,status,student_id)
values
 ('a0660000-0000-4000-8000-000000000021','a0660000-0000-4000-8000-000000000011',repeat('a',64),'a@place.test','Synthetic Unclaimed A','Bachelors','Computing',1,'student',null),
 ('a0660000-0000-4000-8000-000000000022','a0660000-0000-4000-8000-000000000012',repeat('b',64),'b@place.test','Synthetic Unclaimed B','Bachelors','Computing',1,'student',null);
insert into public.placements(id,university_id,roster_entry_id,status,organization_name_text,role_text,source)
values ('a0660000-0000-4000-8000-000000000031','a0660000-0000-4000-8000-000000000011','a0660000-0000-4000-8000-000000000021','unknown',null,null,'university');

select is((select count(*)::int from pg_policies where schemaname='public' and tablename='placements'
 and 'authenticated'::name=any(roles) and ((policyname='placement_unclaimed_university_insert' and cmd='INSERT')
 or (policyname='placement_unclaimed_university_update' and cmd='UPDATE')
 or (policyname='placement_university_read' and cmd='SELECT'))),3,
 'placement read/insert/update policies are present for the behavior checks below');
select ok(has_column_privilege('authenticated','public.placements','roster_entry_id','INSERT')
 and has_column_privilege('authenticated','public.placements','status','UPDATE')
 and not has_column_privilege('authenticated','public.placements','student_id','INSERT'),
 'university callers have only the intended unclaimed placement write columns');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0660000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.placements where id='a0660000-0000-4000-8000-000000000031'),1,'university A can read its placement record');
select is((select count(*)::int from public.placements where university_id='a0660000-0000-4000-8000-000000000012'),0,'university A cannot read university B placement records');
select is(pg_temp.dml_row_count($$insert into public.placements(university_id,roster_entry_id,status,source)
 values('a0660000-0000-4000-8000-000000000011','a0660000-0000-4000-8000-000000000021','placed','university')$$),1,'university A can add a placement for its own unclaimed roster entry');
select throws_ok($$insert into public.placements(university_id,roster_entry_id,status,source)
 values('a0660000-0000-4000-8000-000000000012','a0660000-0000-4000-8000-000000000022','placed','university')$$,'42501',null,'university A cannot add a placement for university B roster');
select is(pg_temp.dml_row_count($$update public.placements set status='placed'
 where id='a0660000-0000-4000-8000-000000000031'$$),1,'university A can update its own unclaimed placement');
select is(pg_temp.dml_row_count($$update public.placements set status='not_placed'
 where university_id='a0660000-0000-4000-8000-000000000012'$$),0,'university A cannot update university B placements');
select throws_ok($$insert into public.placements(student_id,university_id,status,source)
 values('a0660000-0000-4000-8000-000000000099','a0660000-0000-4000-8000-000000000011','placed','student')$$,'42501',null,'university cannot create a placement with fabricated student identity');

select * from finish();
rollback;
