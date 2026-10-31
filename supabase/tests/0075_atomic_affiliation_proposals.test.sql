begin;
select plan(7);

insert into auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('e0750000-0000-4000-8000-000000000001','authenticated','authenticated','proposal-owner@demo.aptohire.test',extensions.crypt('not-used',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.students(id,user_id,full_name,primary_email)
values('e0750000-0000-4000-8000-000000000002','e0750000-0000-4000-8000-000000000001','Synthetic Proposal Owner','proposal-owner@demo.aptohire.test');
insert into public.universities(id,name,status)
values
 ('e0750000-0000-4000-8000-000000000003','Current Synthetic University','approved'),
 ('e0750000-0000-4000-8000-000000000004','Proposed Synthetic University','approved');
insert into public.affiliations(student_id,university_id,verification,program_level,status,is_current)
values('e0750000-0000-4000-8000-000000000002','e0750000-0000-4000-8000-000000000003','roster','Bachelors','student',true);
insert into public.roster_entries(id,university_id,student_id_hash,email,full_name,program_level,year,status)
values('e0750000-0000-4000-8000-000000000005','e0750000-0000-4000-8000-000000000004',repeat('d',64),'proposal-owner@demo.aptohire.test','Synthetic Proposal Owner','Masters',1,'student');
create temporary table proposal_call_ids(id uuid);

select has_function('public','ensure_affiliation_proposal',array['uuid','uuid','uuid','uuid','text','public.life_status','integer'],'atomic proposal RPC exists');
select ok(not has_function_privilege('authenticated','public.ensure_affiliation_proposal(uuid,uuid,uuid,uuid,text,public.life_status,integer)','execute'),'authenticated callers cannot create proposals through the privileged RPC');
insert into proposal_call_ids select public.ensure_affiliation_proposal(
 'e0750000-0000-4000-8000-000000000002','e0750000-0000-4000-8000-000000000001',
 'e0750000-0000-4000-8000-000000000004','e0750000-0000-4000-8000-000000000005','Masters','student'::public.life_status,1);
insert into proposal_call_ids select public.ensure_affiliation_proposal(
 'e0750000-0000-4000-8000-000000000002','e0750000-0000-4000-8000-000000000001',
 'e0750000-0000-4000-8000-000000000004','e0750000-0000-4000-8000-000000000005','Masters','student'::public.life_status,1);
select is((select count(distinct id)::int from proposal_call_ids),1,'repeated requests return the same pending proposal');
select is((select count(*)::int from public.affiliation_proposals where student_id='e0750000-0000-4000-8000-000000000002' and university_id='e0750000-0000-4000-8000-000000000004' and state='pending'),1,'only one pending proposal exists per student and university');
select is((select count(*)::int from public.notifications where user_id='e0750000-0000-4000-8000-000000000001' and kind='affiliation_proposal'),1,'proposal notification is emitted exactly once');
select ok(not exists(select 1 from public.notifications n where n.user_id='e0750000-0000-4000-8000-000000000001' and n.kind='affiliation_proposal' and (n.payload ? 'student_name' or n.payload ? 'email' or n.payload ? 'student_id')),'proposal notification omits student identity and raw ID');
select throws_ok($$select public.ensure_affiliation_proposal('e0750000-0000-4000-8000-000000000002','e0750000-0000-4000-8000-000000000006','e0750000-0000-4000-8000-000000000004','e0750000-0000-4000-8000-000000000005','Masters','student'::public.life_status,1)$$,'42501',null,'a different user cannot create a proposal for this student');

select * from finish();
rollback;
