begin;
select plan(15);

select has_function('public','persist_profile_proposal',array['uuid','uuid','text','jsonb'],'atomic active-source proposal sync RPC exists');
select ok(has_function_privilege('service_role','public.persist_profile_proposal(uuid,uuid,text,jsonb)','execute'),'server service role can persist sync proposals');
select ok(not has_function_privilege('authenticated','public.persist_profile_proposal(uuid,uuid,text,jsonb)','execute'),'browser roles cannot bypass the proposal sync RPC');

insert into public.students(id,full_name,primary_email)
values('a0590000-0000-4000-8000-000000000001','Synthetic Sync Student','sync-student@demo.aptohire.test');
insert into public.profile_sources(id,student_id,source_type,auto_approve,consented_at)
values('a0590000-0000-4000-8000-000000000002','a0590000-0000-4000-8000-000000000001','github',false,now());

set local role service_role;
select ok(public.persist_profile_proposal(
  'a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github',
  '[{"field":"headline","action":"update","value":"Safe proposal","evidence":"Public profile bio"}]'::jsonb
) is not null,'active consent creates a pending profile proposal');
select is((select state from public.profile_proposals where source_id='a0590000-0000-4000-8000-000000000002'),'pending','persisted proposal awaits student approval');
select ok((select last_synced_at is not null from public.profile_sources where id='a0590000-0000-4000-8000-000000000002'),'sync receipt updates source timestamp atomically');
select is(public.persist_profile_proposal(
  'a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github','[]'::jsonb
),null::uuid,'empty proposal set still records successful sync without creating a proposal');
select is((select count(*)::int from public.profile_proposals where source_id='a0590000-0000-4000-8000-000000000002'),1,'empty sync does not duplicate or create proposal rows');
select throws_ok($$select public.persist_profile_proposal('a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','linkedin_export','[]'::jsonb)$$,'P0002',null,'source type must match the active consent record');
select throws_ok($$select public.persist_profile_proposal('a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github','[{"field":"name","action":"update","value":"x","evidence":"bad field"}]'::jsonb)$$,'22023',null,'proposal field is allowlisted at the database boundary');
select throws_ok($$select public.persist_profile_proposal('a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github','{}'::jsonb)$$,'22023',null,'proposal batch must be a JSON array');
select throws_ok($$select public.persist_profile_proposal('a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github',(select jsonb_agg(jsonb_build_object('field','headline','action','update','value','x','evidence','bounded')) from generate_series(1,31)))$$,'22023',null,'proposal batch is capped at thirty items');
select throws_ok($$select public.persist_profile_proposal('a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github','[{"field":"headline","action":"update","value":"x","evidence":""}]'::jsonb)$$,'22023',null,'proposal evidence must be nonempty');
update public.profile_sources set revoked_at=now() where id='a0590000-0000-4000-8000-000000000002';
select throws_ok($$select public.persist_profile_proposal('a0590000-0000-4000-8000-000000000001','a0590000-0000-4000-8000-000000000002','github','[{"field":"headline","action":"update","value":"late","evidence":"late sync"}]'::jsonb)$$,'P0002',null,'revoked source cannot persist a late proposal');
select is((select count(*)::int from public.profile_proposals where source_id='a0590000-0000-4000-8000-000000000002'),1,'late proposal is absent after revocation');

reset role;
select * from finish();
rollback;
