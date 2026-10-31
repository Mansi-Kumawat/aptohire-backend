begin;
select plan(6);

update public.app_config set value='2'::jsonb where key='SCORE_BLEND_N';
insert into public.students(id,full_name,primary_email)
values('e0740000-0000-4000-8000-000000000001','Synthetic Blend Student','score-blend@demo.aptohire.test');
insert into public.skill_families(id,slug,name)
values('e0740000-0000-4000-8000-000000000002','score-blend-test','Score Blend Test');
insert into public.skills(id,family_id,slug,name)
values('e0740000-0000-4000-8000-000000000003','e0740000-0000-4000-8000-000000000002','score-blend-skill','Score Blend Skill');
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
values
 ('e0740000-0000-4000-8000-000000000004','e0740000-0000-4000-8000-000000000001','Synthetic score 60','auditing',array['e0740000-0000-4000-8000-000000000003'::uuid]),
 ('e0740000-0000-4000-8000-000000000005','e0740000-0000-4000-8000-000000000001','Synthetic score 80','auditing',array['e0740000-0000-4000-8000-000000000003'::uuid]),
 ('e0740000-0000-4000-8000-000000000006','e0740000-0000-4000-8000-000000000001','Synthetic score 90','auditing',array['e0740000-0000-4000-8000-000000000003'::uuid]);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,review_status)
values
 ('e0740000-0000-4000-8000-000000000007','e0740000-0000-4000-8000-000000000004','web-frontend@1','blend-test@1',70,0.25,'Synthetic blend fixture',
  jsonb_build_array(jsonb_build_object('key','functionality','score',60,'insufficient_evidence',false,'evidence',jsonb_build_array(jsonb_build_object('evidence_ref','repo:README.md#L1-L2'))),
                    jsonb_build_object('key','skill_score','skill_id','e0740000-0000-4000-8000-000000000003','score',60,'insufficient_evidence',false,'evidence','[]'::jsonb)),'unreviewed'),
 ('e0740000-0000-4000-8000-000000000008','e0740000-0000-4000-8000-000000000005','web-frontend@1','blend-test@1',80,0.75,'Synthetic blend fixture',
  jsonb_build_array(jsonb_build_object('key','functionality','score',80,'insufficient_evidence',false,'evidence',jsonb_build_array(jsonb_build_object('evidence_ref','repo:README.md#L1-L2'))),
                    jsonb_build_object('key','skill_score','skill_id','e0740000-0000-4000-8000-000000000003','score',80,'insufficient_evidence',false,'evidence','[]'::jsonb)),'unreviewed'),
 ('e0740000-0000-4000-8000-000000000009','e0740000-0000-4000-8000-000000000006','web-frontend@1','blend-test@1',90,1.0,'Synthetic blend fixture',
  jsonb_build_array(jsonb_build_object('key','functionality','score',90,'insufficient_evidence',false,'evidence',jsonb_build_array(jsonb_build_object('evidence_ref','repo:README.md#L1-L2'))),
                    jsonb_build_object('key','skill_score','skill_id','e0740000-0000-4000-8000-000000000003','score',90,'insufficient_evidence',false,'evidence','[]'::jsonb)),'unreviewed');

select public.apply_audit('e0740000-0000-4000-8000-000000000007',50,40,60);
select public.apply_audit('e0740000-0000-4000-8000-000000000008',50,40,60);
select is((select score from public.skill_scores where student_id='e0740000-0000-4000-8000-000000000001' and skill_id='e0740000-0000-4000-8000-000000000003'),75.00::numeric,
  'last two final audits use a confidence-weighted blend');
select is((select level from public.skill_scores where student_id='e0740000-0000-4000-8000-000000000001' and skill_id='e0740000-0000-4000-8000-000000000003'),'Proficient',
  'the blended score determines the displayed level');
select ok((select verified and not pending_review and share_ok from public.skill_scores where student_id='e0740000-0000-4000-8000-000000000001' and skill_id='e0740000-0000-4000-8000-000000000003'),
  'final blended score applies pass and sharing state');
select is((select array_agg(score order by audit_id) from public.skill_score_history where student_id='e0740000-0000-4000-8000-000000000001'),array[60::numeric,80::numeric],
  'history preserves each audit-specific raw score');

update public.app_config set value='1'::jsonb where key='SCORE_BLEND_N';
select public.apply_audit('e0740000-0000-4000-8000-000000000009',50,40,60);
select is((select score from public.skill_scores where student_id='e0740000-0000-4000-8000-000000000001' and skill_id='e0740000-0000-4000-8000-000000000003'),90.00::numeric,
  'blend window of one uses only the latest final audit');
select is((select count(*)::int from public.skill_score_history where student_id='e0740000-0000-4000-8000-000000000001'),3,
  'one history record is retained per skill and audit');

select * from finish();
rollback;
