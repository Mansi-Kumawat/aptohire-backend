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
select plan(18);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0700000-0000-4000-8000-000000000001','authenticated','authenticated','assessment-owner@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0700000-0000-4000-8000-000000000002','authenticated','authenticated','assessment-other@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values ('a0700000-0000-4000-8000-000000000001','student'),('a0700000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
 ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000001','Synthetic Assessment Owner','assessment-owner@demo.aptohire.test'),
 ('a0700000-0000-4000-8000-000000000012','a0700000-0000-4000-8000-000000000002','Synthetic Other Student','assessment-other@demo.aptohire.test');
insert into public.skill_families(id,slug,name) values ('a0700000-0000-4000-8000-000000000020','assessment-test','Assessment Test');
insert into public.skills(id,family_id,slug,name) values ('a0700000-0000-4000-8000-000000000021','a0700000-0000-4000-8000-000000000020','assessment-skill','Assessment Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids) values
 ('a0700000-0000-4000-8000-000000000031','a0700000-0000-4000-8000-000000000011','Synthetic Owner Scored','scored',array['a0700000-0000-4000-8000-000000000021'::uuid]),
 ('a0700000-0000-4000-8000-000000000032','a0700000-0000-4000-8000-000000000012','Synthetic Other Scored','scored',array['a0700000-0000-4000-8000-000000000021'::uuid]),
 ('a0700000-0000-4000-8000-000000000033','a0700000-0000-4000-8000-000000000011','Synthetic Owner Draft','draft','{}'::uuid[]),
 ('a0700000-0000-4000-8000-000000000034','a0700000-0000-4000-8000-000000000011','Synthetic Owner Ticketable','scored',array['a0700000-0000-4000-8000-000000000021'::uuid]);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,rubric)
values ('a0700000-0000-4000-8000-000000000041','a0700000-0000-4000-8000-000000000031','fixture@1','fixture@1',70,0.8,'[]'),
 ('a0700000-0000-4000-8000-000000000042','a0700000-0000-4000-8000-000000000032','fixture@1','fixture@1',60,0.8,'[]');
insert into public.skill_scores(student_id,skill_id,score,level,verified,audit_id) values
 ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000021',70,'Proficient',true,'a0700000-0000-4000-8000-000000000041'),
 ('a0700000-0000-4000-8000-000000000012','a0700000-0000-4000-8000-000000000021',60,'Competent',true,'a0700000-0000-4000-8000-000000000042');
insert into public.skill_score_history(student_id,skill_id,score,level,verified,audit_id) values
 ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000021',70,'Proficient',true,'a0700000-0000-4000-8000-000000000041'),
 ('a0700000-0000-4000-8000-000000000012','a0700000-0000-4000-8000-000000000021',60,'Competent',true,'a0700000-0000-4000-8000-000000000042');
insert into public.tickets(id,submission_id,student_id,reason) values
 ('a0700000-0000-4000-8000-000000000051','a0700000-0000-4000-8000-000000000031','a0700000-0000-4000-8000-000000000011','Synthetic owner ticket'),
 ('a0700000-0000-4000-8000-000000000052','a0700000-0000-4000-8000-000000000032','a0700000-0000-4000-8000-000000000012','Synthetic other ticket');

select is((select count(*)::int from pg_policies where schemaname='public' and 'authenticated'::name=any(roles)
 and ((tablename='submissions' and policyname='submission_owner_select' and cmd='SELECT')
 or (tablename='submissions' and policyname='submission_draft_insert' and cmd='INSERT')
 or (tablename='submissions' and policyname='submission_draft_update' and cmd='UPDATE')
 or (tablename='submissions' and policyname='submission_draft_delete' and cmd='DELETE')
 or (tablename='audits' and policyname='audit_owner_select' and cmd='SELECT')
 or (tablename='skill_scores' and policyname='score_owner_select' and cmd='SELECT')
 or (tablename='skill_score_history' and policyname='history_owner_select' and cmd='SELECT')
 or (tablename='tickets' and policyname='ticket_owner_select' and cmd='SELECT')
 or (tablename='tickets' and policyname='ticket_owner_insert' and cmd='INSERT'))),9,'student assessment policies are present');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0700000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.submissions where id='a0700000-0000-4000-8000-000000000031'),1,'student can read own submission');
select is((select count(*)::int from public.submissions where id='a0700000-0000-4000-8000-000000000032'),0,'student cannot read another submission');
select is(pg_temp.dml_row_count($$update public.submissions set title='Updated Synthetic Draft' where id='a0700000-0000-4000-8000-000000000033'$$),1,'student can update own draft');
select is(pg_temp.dml_row_count($$insert into public.submissions(student_id,title,status) values('a0700000-0000-4000-8000-000000000011','New Synthetic Draft','draft')$$),1,'student can insert own draft');
select throws_ok($$insert into public.submissions(student_id,title,status) values('a0700000-0000-4000-8000-000000000012','Foreign Draft','draft')$$,'42501',null,'student cannot insert another student draft');
select is(pg_temp.dml_row_count($$delete from public.submissions where id='a0700000-0000-4000-8000-000000000033'$$),1,'student can delete own draft');
select is((select count(*)::int from public.audits where id='a0700000-0000-4000-8000-000000000041'),1,'student can read audit for own submission');
select is((select count(*)::int from public.audits where id='a0700000-0000-4000-8000-000000000042'),0,'student cannot read audit for another submission');
select is((select count(*)::int from public.skill_scores where student_id='a0700000-0000-4000-8000-000000000011'),1,'student can read own skill score');
select is((select count(*)::int from public.skill_scores where student_id='a0700000-0000-4000-8000-000000000012'),0,'student cannot read another skill score');
select is((select count(*)::int from public.skill_score_history where student_id='a0700000-0000-4000-8000-000000000011'),1,'student can read own score history');
select is((select count(*)::int from public.skill_score_history where student_id='a0700000-0000-4000-8000-000000000012'),0,'student cannot read another score history');
select is((select count(*)::int from public.tickets where id='a0700000-0000-4000-8000-000000000051'),1,'student can read own ticket');
select is((select count(*)::int from public.tickets where id='a0700000-0000-4000-8000-000000000052'),0,'student cannot read another ticket');
select ok(private.student_can_open_ticket('a0700000-0000-4000-8000-000000000034','a0700000-0000-4000-8000-000000000011'),'ticket authorization helper recognizes the current owner and scored submission');
select is(pg_temp.dml_row_count($$insert into public.tickets(submission_id,student_id,reason) values('a0700000-0000-4000-8000-000000000034','a0700000-0000-4000-8000-000000000011','Synthetic appeal')$$),1,'student can open ticket on own scored submission');
select throws_ok($$insert into public.tickets(submission_id,student_id,reason) values('a0700000-0000-4000-8000-000000000032','a0700000-0000-4000-8000-000000000012','Foreign appeal')$$,'42501',null,'student cannot open ticket on another student submission');
select * from finish();
rollback;
