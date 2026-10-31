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
select plan(7);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('a0570000-0000-4000-8000-000000000001','authenticated','authenticated','admin-template-rubric@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values('a0570000-0000-4000-8000-000000000001','admin');

select ok(exists(select 1 from pg_trigger where tgrelid='public.project_templates'::regclass and tgname='project_templates_rubric_read_only' and not tgisinternal),'rubric immutability trigger exists');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0570000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',true);
select is(pg_temp.dml_row_count($$insert into public.project_templates(skill_id,level,title,brief,active) values (null,'Competent','Admin Template','{"objective":"Original objective","rubric_version":"web@1"}'::jsonb,true)$$),1,'aal2 admin can create template with rubric version reference but no rubric content');
select throws_ok($$insert into public.project_templates(skill_id,level,title,brief,active) values (null,'Competent','Rubric Authoring Blocked','{"objective":"Synthetic","rubric_preview":[{"criterion":"Functionality","weight":1}]}'::jsonb,true)$$,'42501',null,'admin cannot insert rubric definition into template brief');
select is(pg_temp.dml_row_count($$update public.project_templates set brief=brief||'{"objective":"Updated objective","deliverables":["Source"]}'::jsonb where title='Admin Template'$$),1,'admin can update non-rubric brief content');
select is((select brief->>'rubric_version' from public.project_templates where title='Admin Template'),'web@1','non-rubric edits preserve the original rubric version');
select throws_ok($$update public.project_templates set brief=brief||'{"rubric_preview":[{"criterion":"Changed","weight":1}]}'::jsonb where title='Admin Template'$$,'42501',null,'admin cannot change rubric preview');
select throws_ok($$update public.project_templates set brief=brief||'{"rubric_version":"web@2"}'::jsonb where title='Admin Template'$$,'42501',null,'admin cannot change rubric version on an existing template');

select * from finish();
rollback;
