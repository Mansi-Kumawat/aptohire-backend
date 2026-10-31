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
select plan(40);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0530000-0000-4000-8000-000000000001','authenticated','authenticated','admin-catalog@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0530000-0000-4000-8000-000000000002','authenticated','authenticated','student-catalog@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0530000-0000-4000-8000-000000000001','admin'),
 ('a0530000-0000-4000-8000-000000000002','student');
insert into public.skill_families(id,slug,name) values ('a0530000-0000-4000-8000-000000000010','catalog-test','Catalog Test');
insert into public.skills(id,family_id,slug,name) values
 ('a0530000-0000-4000-8000-000000000011','a0530000-0000-4000-8000-000000000010','catalog-source','Source Skill'),
 ('a0530000-0000-4000-8000-000000000012','a0530000-0000-4000-8000-000000000010','catalog-target','Target Skill');
insert into public.project_templates(id,skill_id,level,title,brief,active)
values('a0530000-0000-4000-8000-000000000013','a0530000-0000-4000-8000-000000000011','Emerging','Active Student Template','{}'::jsonb,true);

select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='skills' and policyname='admin_skills_write'),'AAL2 admin skill write policy exists');
select ok(not has_table_privilege('anon','public.skill_families','select'),'anonymous role cannot read the skill-family taxonomy');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='skill_edges' and policyname='admin_skill_edges_manage'),'AAL2 admin skill-edge policy exists');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='project_templates' and policyname='admin_project_templates_manage'),'AAL2 admin template write policy exists');

select is(
  (select count(*)::int from pg_policies where schemaname='public' and 'authenticated'::name=any(roles)
    and ((tablename='project_templates' and policyname='student_templates_read' and cmd='SELECT')
      or (tablename='project_templates' and policyname='admin_project_templates_manage' and cmd='ALL')
      or (tablename='project_templates' and policyname='admin_project_templates_read_all' and cmd='SELECT')
      or (tablename='skills' and policyname='student_skills_read' and cmd='SELECT')
      or (tablename='skill_families' and policyname='student_skill_families_read' and cmd='SELECT'))),
  5,
  'catalog read/write behavior below maps to its five active named policies'
);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select throws_ok($$insert into public.skills(family_id,slug,name) values ('a0530000-0000-4000-8000-000000000010','blocked-aal1','Blocked')$$,'42501',null,'aal1 admin cannot write skills');
select throws_ok($$insert into public.skill_edges(from_skill_id,to_skill_id,relation) values ('a0530000-0000-4000-8000-000000000011','a0530000-0000-4000-8000-000000000012','requires')$$,'42501',null,'aal1 admin cannot write skill edges');
select throws_ok($$insert into public.project_templates(skill_id,level,title,brief,active) values ('a0530000-0000-4000-8000-000000000011','Competent','Blocked Template','{}'::jsonb,false)$$,'42501',null,'aal1 admin cannot write project templates');

select set_config('request.jwt.claims','{"sub":"a0530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is(pg_temp.dml_row_count($$insert into public.skills(family_id,slug,name) values ('a0530000-0000-4000-8000-000000000010','catalog-new','New Skill')$$),1,'aal2 admin can insert a skill');
select is(pg_temp.dml_row_count($$insert into public.skill_edges(from_skill_id,to_skill_id,relation) values ('a0530000-0000-4000-8000-000000000011','a0530000-0000-4000-8000-000000000012','requires')$$),1,'aal2 admin can insert a skill edge');
select is(pg_temp.dml_row_count($$insert into public.project_templates(skill_id,level,title,brief,active) values ('a0530000-0000-4000-8000-000000000011','Competent','Inactive Template','{}'::jsonb,false)$$),1,'aal2 admin can create an inactive project template');
select is(pg_temp.dml_row_count($$update public.project_templates set title='Updated Template' where title='Inactive Template'$$),1,'aal2 admin can update a project template');
select is((select count(*)::int from public.project_templates where title='Updated Template' and not active),1,'aal2 admin can read inactive templates');
select is(pg_temp.dml_row_count($$update public.skills set name='Updated Skill' where slug='catalog-new'$$),1,'aal2 admin can update a skill catalog row');
select is(pg_temp.dml_row_count($$update public.skill_edges set relation='requires' where from_skill_id='a0530000-0000-4000-8000-000000000011' and to_skill_id='a0530000-0000-4000-8000-000000000012'$$),1,'aal2 admin can update a skill edge');

select set_config('request.jwt.claims','{"sub":"a0530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is(pg_temp.dml_row_count($$update public.skills set name='AAL1 Unauthorized Update' where slug='catalog-new'$$),0,'aal1 admin cannot update skills');
select is(pg_temp.dml_row_count($$delete from public.skills where slug='catalog-new'$$),0,'aal1 admin cannot delete skills');
select is(pg_temp.dml_row_count($$update public.skill_edges set relation='requires' where from_skill_id='a0530000-0000-4000-8000-000000000011' and to_skill_id='a0530000-0000-4000-8000-000000000012'$$),0,'aal1 admin cannot update skill edges');
select is(pg_temp.dml_row_count($$delete from public.skill_edges where from_skill_id='a0530000-0000-4000-8000-000000000011' and to_skill_id='a0530000-0000-4000-8000-000000000012'$$),0,'aal1 admin cannot delete skill edges');
select is(pg_temp.dml_row_count($$update public.project_templates set title='AAL1 Unauthorized Update' where title='Updated Template'$$),0,'aal1 admin cannot update templates');
select is(pg_temp.dml_row_count($$delete from public.project_templates where title='Updated Template'$$),0,'aal1 admin cannot delete templates');
select is((select count(*)::int from public.project_templates where title='Active Student Template'),1,'aal1 admin can read active template through the student policy');
select is((select count(*)::int from public.project_templates where title='Updated Template'),0,'aal1 admin cannot read inactive templates reserved for aal2');
select is((select count(*)::int from public.skill_edges),0,'aal1 admin cannot read skill edges reserved for aal2');

select set_config('request.jwt.claims','{"sub":"a0530000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.skills where slug='catalog-new'),1,'students retain read access to the safe skill catalog');
select is((select count(*)::int from public.skill_families where slug='catalog-test'),1,'students can read the skill-family taxonomy');
select is((select count(*)::int from public.skill_edges),0,'students cannot read admin-only skill edges');
select is((select count(*)::int from public.project_templates where title='Active Student Template'),1,'students can read active project templates');
select is((select count(*)::int from public.project_templates where title='Updated Template'),0,'students cannot read inactive project templates');
select is(pg_temp.dml_row_count($$update public.skills set name='Student Unauthorized Update' where slug='catalog-new'$$),0,'students cannot update skills');
select is(pg_temp.dml_row_count($$delete from public.skills where slug='catalog-new'$$),0,'students cannot delete skills');
select is(pg_temp.dml_row_count($$update public.skill_edges set relation='requires' where from_skill_id='a0530000-0000-4000-8000-000000000011' and to_skill_id='a0530000-0000-4000-8000-000000000012'$$),0,'students cannot update skill edges');
select is(pg_temp.dml_row_count($$delete from public.skill_edges where from_skill_id='a0530000-0000-4000-8000-000000000011' and to_skill_id='a0530000-0000-4000-8000-000000000012'$$),0,'students cannot delete skill edges');
select is(pg_temp.dml_row_count($$update public.project_templates set title='Student Unauthorized Update' where title='Active Student Template'$$),0,'students cannot update active templates');
select is(pg_temp.dml_row_count($$delete from public.project_templates where title='Active Student Template'$$),0,'students cannot delete active templates');
select throws_ok($$insert into public.skills(family_id,slug,name) values ('a0530000-0000-4000-8000-000000000010','student-blocked','Blocked')$$,'42501',null,'student cannot write skills');

select set_config('request.jwt.claims','{"sub":"a0530000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is(pg_temp.dml_row_count($$delete from public.skills where slug='catalog-new'$$),1,'aal2 admin can delete a skill catalog row');
select is(pg_temp.dml_row_count($$delete from public.skill_edges where from_skill_id='a0530000-0000-4000-8000-000000000011' and to_skill_id='a0530000-0000-4000-8000-000000000012'$$),1,'aal2 admin can delete a skill edge');
select is(pg_temp.dml_row_count($$delete from public.project_templates where title='Updated Template'$$),1,'aal2 admin can delete a project template');
select is((select count(*)::int from public.audit_log where actor_id='a0530000-0000-4000-8000-000000000001' and action in ('admin_skills_insert','admin_skill_edges_insert','admin_project_templates_insert','admin_project_templates_update','admin_skills_update','admin_skill_edges_update','admin_skills_delete','admin_skill_edges_delete','admin_project_templates_delete')),9,'catalog create/update/delete operations are audited with the aal2 actor');

select * from finish();
rollback;
