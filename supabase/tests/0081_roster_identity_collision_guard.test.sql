begin;
select plan(5);

insert into public.universities(id,name,status)
values
 ('00810000-0000-4000-8000-000000000001','Fictional Roster Guard University A','approved'),
 ('00810000-0000-4000-8000-000000000002','Fictional Roster Guard University B','approved');
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,status)
values('00810000-0000-4000-8000-000000000010','00810000-0000-4000-8000-000000000001',repeat('a',64),'shared@roster.example.test','Fictional Roster A','ug','enrolled');

select has_trigger('public','roster_entries','roster_identity_collision_guard','roster identity collision guard trigger exists');
select throws_ok($$insert into public.roster_entries(university_id,student_id_hash,email,full_name,program_level,status)
 values('00810000-0000-4000-8000-000000000001',repeat('b',64),'shared@roster.example.test','Fictional Duplicate Email','pg','incoming')$$,
 '23505',null,'same-university duplicate email is rejected');
select throws_ok($$insert into public.roster_entries(university_id,student_id_hash,email,full_name,program_level,status)
 values('00810000-0000-4000-8000-000000000001',repeat('a',64),'different@roster.example.test','Fictional Duplicate ID','pg','incoming')$$,
 '23505',null,'same-university duplicate ID hash is rejected');
select lives_ok($$insert into public.roster_entries(university_id,student_id_hash,email,full_name,program_level,status)
 values('00810000-0000-4000-8000-000000000002',repeat('a',64),'shared@roster.example.test','Fictional Transfer Roster','pg','incoming')$$,
 'same person may appear on a second university roster');
select ok(not has_function_privilege('service_role','private.guard_roster_identity_collisions()','execute'),
 'service role cannot invoke the trigger-only helper directly');

select * from finish();
rollback;
