begin;
select plan(8);

insert into public.students(id, full_name, visibility)
values ('00000000-0000-0000-0000-000000006445', 'Projection Fixture', '{"discoverable":true}'::jsonb);

select ok(
  (select discoverable and skills='[]'::jsonb from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006445'),
  'inserting a discoverable student initializes an empty blind projection'
);

insert into public.skill_scores(student_id, skill_id, score, level, verified, pending_review, share_ok)
select '00000000-0000-0000-0000-000000006445', id, 82, 'Proficient', true, false, true
from public.skills where slug='react';

select ok(
  (select jsonb_array_length(skills)=1 and skills->0->>'name'='React'
    and skills->0->>'score'='82' and skills->0->>'verified'='true'
   from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006445'),
  'inserted verified, shareable skill is projected automatically'
);

update public.skill_scores set pending_review=true
where student_id='00000000-0000-0000-0000-000000006445';
select is(
  (select skills from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006445'),
  '[]'::jsonb,
  'pending-review scores are removed from the projection'
);

update public.skill_scores set pending_review=false
where student_id='00000000-0000-0000-0000-000000006445';
update public.candidate_profiles set study_stage='Y2', uni_category='Tier 2', scrubbed_summary='synthetic summary'
where student_id='00000000-0000-0000-0000-000000006445';
update public.students set visibility='{"discoverable":false}'::jsonb
where id='00000000-0000-0000-0000-000000006445';
select ok(
  (select not discoverable and skills='[]'::jsonb and study_stage is null and uni_category is null and scrubbed_summary is null
   from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006445'),
  'opting out clears every shareable projection field'
);

update public.students set visibility='{"discoverable":true}'::jsonb
where id='00000000-0000-0000-0000-000000006445';
select ok(
  (select discoverable and jsonb_array_length(skills)=1
   from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006445'),
  'opting back in rebuilds current verified skill facts'
);

delete from public.skill_scores where student_id='00000000-0000-0000-0000-000000006445';
select is(
  (select skills from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006445'),
  '[]'::jsonb,
  'deleting a score removes it from the projection'
);

select has_function('private', 'refresh_candidate_profile', array['uuid'], 'projection refresh helper exists in the private schema');
select ok(
  not has_function_privilege('anon','private.refresh_candidate_profile(uuid)','execute')
  and not has_function_privilege('authenticated','private.refresh_candidate_profile(uuid)','execute'),
  'projection helper is not directly executable by client roles'
);

select * from finish();
rollback;
