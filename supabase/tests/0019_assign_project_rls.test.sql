begin;
select plan(4);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a0190000-0000-4000-8000-000000000001','authenticated','authenticated','assign-a@demo.aptohire.test',now(),extensions.crypt('fictional-password',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now()),
('a0190000-0000-4000-8000-000000000002','authenticated','authenticated','assign-b@demo.aptohire.test',now(),extensions.crypt('fictional-password',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values
('a0190000-0000-4000-8000-000000000001','student'),
('a0190000-0000-4000-8000-000000000002','student');
insert into public.students(id,user_id,full_name,primary_email) values
('a0190000-0000-4000-8000-000000000003','a0190000-0000-4000-8000-000000000001','Fictional Student A','assign-a@demo.aptohire.test'),
('a0190000-0000-4000-8000-000000000004','a0190000-0000-4000-8000-000000000002','Fictional Student B','assign-b@demo.aptohire.test');
insert into public.project_assignments(id,student_id,status,brief) values
('a0190000-0000-4000-8000-000000000005','a0190000-0000-4000-8000-000000000004','assigned','{"title":"B private brief"}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0190000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select lives_ok($$insert into public.project_assignments(student_id,status,brief) values('a0190000-0000-4000-8000-000000000003','assigned','{"title":"A own brief"}'::jsonb)$$,'student may insert their own assignment using only granted columns');
select ok(exists(select 1 from public.project_assignments where student_id='a0190000-0000-4000-8000-000000000003' and brief->>'title'='A own brief'),'student can read own project assignment');
select ok(not exists(select 1 from public.project_assignments where student_id='a0190000-0000-4000-8000-000000000004'),'student cannot read another student assignment');
select throws_ok($$insert into public.project_assignments(student_id,status,brief) values('a0190000-0000-4000-8000-000000000004','assigned','{"title":"forbidden"}'::jsonb)$$,'42501',null,'student cannot create assignment for another student');
select * from finish();
rollback;
