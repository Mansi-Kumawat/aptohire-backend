begin;
select plan(9);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('66666666-6666-4666-8666-666666666666','authenticated','authenticated','affiliation-member@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.students(id,user_id,full_name,primary_email)
values('77777777-7777-4777-8777-777777777777','66666666-6666-4666-8666-666666666666','Fictional Learner','affiliation-member@demo.aptohire.test');
insert into public.universities(id,name,status)
values('88888888-8888-4888-8888-888888888888','Affiliation Test University','approved');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,year,status)
values('99999999-9999-4999-8999-999999999999','88888888-8888-4888-8888-888888888888',repeat('b',64),'affiliation-member@demo.aptohire.test','Fictional Learner','Bachelors',2,'student');

select has_function('public','confirm_affiliation',array['uuid','uuid','uuid','uuid','text','text','text','integer','public.life_status'],'confirmation RPC exists');
select ok(not has_function_privilege('authenticated','public.confirm_affiliation(uuid,uuid,uuid,uuid,text,text,text,integer,public.life_status)','execute'),'authenticated cannot call service-only RPC');
select is((public.confirm_affiliation(
 '77777777-7777-4777-8777-777777777777','66666666-6666-4666-8666-666666666666',null,
 '88888888-8888-4888-8888-888888888888',null,repeat('b',64),'Bachelors',2,'student'::public.life_status)->>'verification'),
 'student_id','matching roster ID creates verified affiliation');
select is((select count(*)::int from public.affiliations where student_id='77777777-7777-4777-8777-777777777777' and is_current),1,'one current affiliation exists');
select is((select student_id from public.roster_entries where id='99999999-9999-4999-8999-999999999999'),'77777777-7777-4777-8777-777777777777'::uuid,'matching roster entry is linked to the existing person');
select throws_ok($$select public.confirm_affiliation('77777777-7777-4777-8777-777777777777','66666666-6666-4666-8666-666666666666',null,null,'Unverified Institute',null,'Bachelors',2,'student'::public.life_status)$$,'42501',null,'a verified affiliation cannot be downgraded by self-edit');
select throws_ok($$select public.confirm_affiliation('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555',null,null,'Other Institute',null,'Bachelors',2,'student'::public.life_status)$$,'42501',null,'a different actor cannot change the student affiliation');
select ok(exists(select 1 from public.audit_log where actor_id='66666666-6666-4666-8666-666666666666' and action='affiliation_confirmed'),'confirmation is audit logged');
update public.roster_entries set year=3 where id='99999999-9999-4999-8999-999999999999';
select is((select year from public.affiliations where student_id='77777777-7777-4777-8777-777777777777' and is_current),3,'university roster updates sync to the linked platform affiliation');

select * from finish();
rollback;
