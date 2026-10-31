begin;
select plan(10);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('33333333-3333-4333-8333-333333333333','authenticated','authenticated','roster-member@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.universities(id,name,status) values('44444444-4444-4444-8444-444444444444','Roster Test University','approved');
insert into public.university_members(university_id,user_id,member_role)
values('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333','member');

select has_function('public','process_roster_import',array['uuid','jsonb','boolean','boolean','uuid'],'atomic roster import RPC exists');
select ok(not has_function_privilege('authenticated','public.process_roster_import(uuid,jsonb,boolean,boolean,uuid)','execute'),'authenticated users cannot call service-only RPC');
select is((select r.created from public.process_roster_import(
 '44444444-4444-4444-8444-444444444444',
 '[{"student_id_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","email":"roster@demo.aptohire.test","full_name":"Fictional Learner","program":"Computing","program_level":"Bachelors","year":2,"status":"student"}]'::jsonb,
 false,true,'33333333-3333-4333-8333-333333333333') r),1,'dry run reports a new row');
select is((select count(*)::int from public.roster_entries where university_id='44444444-4444-4444-8444-444444444444'),0,'dry run makes no roster changes');
select is((select r.created from public.process_roster_import(
 '44444444-4444-4444-8444-444444444444',
 '[{"student_id_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","email":"roster@demo.aptohire.test","full_name":"Fictional Learner","program":"Computing","program_level":"Bachelors","year":2,"status":"student"}]'::jsonb,
 false,false,'33333333-3333-4333-8333-333333333333') r),1,'real import creates the roster row');
select is((select count(*)::int from public.roster_entries where university_id='44444444-4444-4444-8444-444444444444' and student_id_hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),1,'ID hash is stored on the roster row');
select is((select r.updated from public.process_roster_import(
 '44444444-4444-4444-8444-444444444444',
 '[{"student_id_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","email":"roster@demo.aptohire.test","full_name":"Fictional Learner Updated","program":"Computing","program_level":"Bachelors","year":3,"status":"student"}]'::jsonb,
 false,false,'33333333-3333-4333-8333-333333333333') r),1,'same row can be re-imported idempotently');
select is((select count(*)::int from public.roster_entries where university_id='44444444-4444-4444-8444-444444444444'),1,'re-import does not duplicate the row');
select throws_ok($$select * from public.process_roster_import('44444444-4444-4444-8444-444444444444','[]'::jsonb,false,true,'55555555-5555-4555-8555-555555555555')$$,'42501',null,'non-member actor is rejected');
select ok(exists(select 1 from public.audit_log where action='roster_import' and target_id='44444444-4444-4444-8444-444444444444' and actor_id='33333333-3333-4333-8333-333333333333'),'import writes an audit event');

select * from finish();
rollback;
