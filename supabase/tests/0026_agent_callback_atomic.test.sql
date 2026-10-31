begin;
select plan(18);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('af430000-0000-4000-8000-000000000001','authenticated','authenticated','agent-callback-student@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values('af430000-0000-4000-8000-000000000001','student');
insert into public.students(id,user_id,full_name,primary_email)
values('af430000-0000-4000-8000-000000000002','af430000-0000-4000-8000-000000000001','Synthetic Callback Student','agent-callback-student@demo.aptohire.test');
insert into public.skill_families(id,slug,name) values('af430000-0000-4000-8000-000000000003','callback-test','Callback Test');
insert into public.skills(id,family_id,slug,name) values('af430000-0000-4000-8000-000000000004','af430000-0000-4000-8000-000000000003','callback-skill','Callback Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids) values
('af430000-0000-4000-8000-000000000010','af430000-0000-4000-8000-000000000002','Synthetic Callback Project','auditing',array['af430000-0000-4000-8000-000000000004'::uuid]),
('af430000-0000-4000-8000-000000000011','af430000-0000-4000-8000-000000000002','Synthetic Invalid Evidence Project','auditing',array['af430000-0000-4000-8000-000000000004'::uuid]);
insert into public.agent_runs(id,submission_id,user_id,stage,attempt,mode,status,evidence_manifest) values
('af430000-0000-4000-8000-000000000020','af430000-0000-4000-8000-000000000010','af430000-0000-4000-8000-000000000001','writing',1,'direct','running',array['repo:README.md#L1-L2']),
('af430000-0000-4000-8000-000000000021','af430000-0000-4000-8000-000000000011','af430000-0000-4000-8000-000000000001','writing',1,'n8n','running',array['repo:README.md#L1-L2']);
insert into public.app_config(key,value) values('PASS_MARK','50'::jsonb),('BORDERLINE','[40,60]'::jsonb),('AI_KILL_SWITCH','false'::jsonb)
on conflict(key) do update set value=excluded.value;

select has_column('public','agent_runs','evidence_manifest','agent run stores server-created evidence manifest');
select has_function('public','complete_agent_run',array['uuid','jsonb','text[]'],'atomic callback finalizer exists');
select ok(has_function_privilege('service_role','public.complete_agent_run(uuid,jsonb,text[])','execute'),'service role can finalize a validated callback');
select ok(not has_function_privilege('anon','public.complete_agent_run(uuid,jsonb,text[])','execute'),'anonymous callers cannot finalize agent runs');
set local role service_role;
select is((select status from public.complete_agent_run('af430000-0000-4000-8000-000000000020',
'{"rubric_version":"web-frontend@1","prompt_version":"test@1","overall_score":70,"confidence":0.8,"summary":"Synthetic callback output","prompt_injection_attempt":true,"criteria":[{"key":"functionality","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[{"evidence_ref":"repo:README.md#L1-L2"}]},{"key":"quality","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[]},{"key":"ui_accessibility","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[]},{"key":"testing","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[]},{"key":"documentation","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[]},{"key":"problem_solving","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[]},{"key":"communication","score":70,"confidence":0.8,"rationale":"Synthetic","evidence":[]}],"transcript":[],"visual_observations":[],"next_steps":[]}'::jsonb,
array['repo:README.md#L1-L2']::text[])),'completed','valid callback creates and completes an audit');
select is((select status from public.submissions where id='af430000-0000-4000-8000-000000000010'),'scored','configured scoring updates submission lifecycle');
select is((select status from public.agent_runs where id='af430000-0000-4000-8000-000000000020'),'completed','run is marked completed atomically');
select ok((select started_at is not null and finished_at is not null and started_at<=finished_at and latency_ms>=0 from public.agent_runs where id='af430000-0000-4000-8000-000000000020'),'callback completion records run timing in the same database transaction');
select is((select count(*)::int from public.audits where submission_id='af430000-0000-4000-8000-000000000010'),1,'callback inserts exactly one audit');
select ok((select evidence->0->>'ref'='repo:README.md#L1-L2' and evidence->0->>'kind'='repo' and evidence->0->>'label'='README.md' and evidence->0->>'pointer'='README.md#L1-L2' and not (evidence->0 ? 'evidence_ref') from public.audits where submission_id='af430000-0000-4000-8000-000000000010'),'stored callback evidence uses the frozen frontend EvidenceItem shape');
select is((select flags from public.audits where submission_id='af430000-0000-4000-8000-000000000010'),array['prompt_injection_attempt']::text[],'generic prompt-injection flag is persisted without source text');
select ok(exists(select 1 from public.skill_scores where student_id='af430000-0000-4000-8000-000000000002' and skill_id='af430000-0000-4000-8000-000000000004' and audit_id=(select id from public.audits where submission_id='af430000-0000-4000-8000-000000000010')),'aggregate score is tied to claimed skill and audit');
select throws_ok($$select * from public.complete_agent_run('af430000-0000-4000-8000-000000000020','{"criteria":[]}'::jsonb,'{}'::text[])$$,'40001',null,'completed callback cannot be replayed');
select throws_ok($$select * from public.complete_agent_run('af430000-0000-4000-8000-000000000021','{"rubric_version":"web-frontend@1","prompt_version":"test@1","overall_score":70,"confidence":0.8,"summary":"x","criteria":[{"key":"functionality","score":70,"confidence":0.8,"rationale":"x","evidence":[{"evidence_ref":"repo:secrets.md#L1-L2"}]},{"key":"quality","score":70,"confidence":0.8,"rationale":"x","evidence":[]},{"key":"ui_accessibility","score":70,"confidence":0.8,"rationale":"x","evidence":[]},{"key":"testing","score":70,"confidence":0.8,"rationale":"x","evidence":[]},{"key":"documentation","score":70,"confidence":0.8,"rationale":"x","evidence":[]},{"key":"problem_solving","score":70,"confidence":0.8,"rationale":"x","evidence":[]},{"key":"communication","score":70,"confidence":0.8,"rationale":"x","evidence":[]}],"transcript":[],"visual_observations":[],"next_steps":[]}'::jsonb,array['repo:secrets.md#L1-L2']::text[])$$,'22023',null,'callback cannot reference evidence outside the manifest');
select throws_ok($$select * from public.complete_agent_run('af430000-0000-4000-8000-000000000021','{"criteria":[]}'::jsonb,array['repo:../secrets.md#L1-L2']::text[])$$,'22023',null,'evidence locators reject path traversal');
select throws_ok($$select * from public.complete_agent_run('af430000-0000-4000-8000-000000000021','{"criteria":[]}'::jsonb,array['repo:README.md#L4-L2']::text[])$$,'22023',null,'evidence locators reject reversed line ranges');
reset role;
update public.app_config set value='true'::jsonb where key='AI_KILL_SWITCH';
set local role service_role;
select throws_ok($$select * from public.complete_agent_run('af430000-0000-4000-8000-000000000021','{"criteria":[]}'::jsonb,'{}'::text[])$$,'55000',null,'kill switch blocks callback finalization at the RPC boundary');
reset role;
update public.app_config set value='false'::jsonb where key='AI_KILL_SWITCH';
select is((select status from public.agent_runs where id='af430000-0000-4000-8000-000000000021'),'running','rejected callbacks leave the run recoverable');
select * from finish();
rollback;
