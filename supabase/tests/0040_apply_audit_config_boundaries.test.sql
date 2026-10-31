begin;
select plan(5);

insert into public.students(id,full_name,primary_email)
values('e0400000-0000-4000-8000-000000000001','Synthetic Scoring Boundary Student','scoring-boundaries@demo.aptohire.test');
insert into public.skill_families(id,slug,name)
values('e0400000-0000-4000-8000-000000000002','scoring-boundary-test','Scoring Boundary Test');
insert into public.skills(id,family_id,slug,name)
select md5('e040:skill:'||score)::uuid,'e0400000-0000-4000-8000-000000000002',
       'score-'||score,'Score '||score
from (values(0),(40),(50),(51),(60),(61),(69),(70),(84),(85),(100)) as scores(score);
insert into public.submissions(id,student_id,title,status,claimed_skill_ids)
select md5('e040:submission:'||score)::uuid,'e0400000-0000-4000-8000-000000000001',
       'Boundary '||score,'auditing',array[md5('e040:skill:'||score)::uuid]
from (values(0),(40),(50),(51),(60),(61),(69),(70),(84),(85),(100)) as scores(score);
insert into public.audits(id,submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,review_status)
select md5('e040:audit:'||score)::uuid,md5('e040:submission:'||score)::uuid,
       'web-frontend@1','boundary-test@1',score,0.9,'Synthetic boundary fixture',
       jsonb_build_array(
         jsonb_build_object('key','functionality','score',score,'insufficient_evidence',false,
           'evidence',jsonb_build_array(jsonb_build_object('evidence_ref','repo:README.md#L1-L2'))),
         jsonb_build_object('key','skill_score','skill_id',md5('e040:skill:'||score)::uuid,
           'score',score,'insufficient_evidence',false,'evidence','[]'::jsonb)
       ),'unreviewed'
from (values(0),(40),(50),(51),(60),(61),(69),(70),(84),(85),(100)) as scores(score);

select public.apply_audit(a.id,50,40,60)
from public.audits a
where a.id in (select md5('e040:audit:'||score)::uuid from (values(0),(40),(50),(51),(60),(61),(69),(70),(84),(85),(100)) as scores(score));

select is((select count(*)::int from public.skill_scores where student_id='e0400000-0000-4000-8000-000000000001'),11,'each scorable configured boundary produces one skill score');
select is((select array_agg(level order by score) from public.skill_scores where student_id='e0400000-0000-4000-8000-000000000001'),
  array['Emerging','Emerging','Emerging','Competent','Competent','Competent','Competent','Proficient','Proficient','Advanced','Advanced']::text[],
  'score-to-level boundaries are deterministic at 0,40,50,51,60,61,69,70,84,85,100');
select ok((select not verified from public.skill_scores where skill_id=md5('e040:skill:50')::uuid)
  and (select verified from public.skill_scores where skill_id=md5('e040:skill:51')::uuid),
  'verification threshold uses configured pass mark and is exclusive');
select ok((select pending_review and not share_ok from public.skill_scores where skill_id=md5('e040:skill:60')::uuid)
  and (select not pending_review and share_ok from public.skill_scores where skill_id=md5('e040:skill:61')::uuid),
  'configured borderline upper bound is inclusive and suppresses sharing');
select is((select count(*)::int from public.skill_score_history where student_id='e0400000-0000-4000-8000-000000000001'),11,'one history row is recorded for each applied scorable score');
select * from finish();
rollback;
