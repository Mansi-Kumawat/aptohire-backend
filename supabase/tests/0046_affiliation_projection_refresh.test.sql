begin;
select plan(10);

insert into public.students(id, full_name, visibility)
values ('00000000-0000-0000-0000-000000006446', 'Affiliation Projection Fixture', '{"discoverable":true}'::jsonb);
insert into public.affiliations(student_id, university_id, verification, program_level, year, status, is_current)
select '00000000-0000-0000-0000-000000006446', id, 'roster', 'bachelor', 2, 'student', true
from public.universities where name='University A';

select is(
  (select study_stage from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  'Year 2'::text,
  'current verified affiliation initializes the bucketed study stage'
);
select is(
  (select uni_category from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  'Tier 2 · University'::text,
  'approved university tier is projected without university identity'
);

update public.affiliations set year=4
where student_id='00000000-0000-0000-0000-000000006446' and is_current;
select is(
  (select study_stage from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  'Year 4+'::text,
  'year updates refresh a coarse study-stage bucket'
);

update public.affiliations set verification='unverified'
where student_id='00000000-0000-0000-0000-000000006446' and is_current;
select ok(
  (select study_stage='Year 4+' and uni_category is null
   from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  'unverified affiliation retains only a coarse self-reported stage, not a university category'
);

update public.affiliations set verification='roster'
where student_id='00000000-0000-0000-0000-000000006446' and is_current;
update public.universities set status='pending' where name='University A';
select is(
  (select uni_category from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  null::text,
  'university approval changes immediately remove a now-ineligible category'
);
update public.universities set status='approved' where name='University A';
select is(
  (select uni_category from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  'Tier 2 · University'::text,
  'university approval refresh immediately restores the verified tier bucket'
);

delete from public.affiliations
where student_id='00000000-0000-0000-0000-000000006446';
select ok(
  (select study_stage is null and uni_category is null
   from public.candidate_profiles where student_id='00000000-0000-0000-0000-000000006446'),
  'deleting the current affiliation clears affiliation-derived buckets'
);

select has_function('private', 'refresh_candidate_profile_from_affiliation', array[]::text[], 'affiliation trigger helper exists');
select has_function('private', 'refresh_candidate_profiles_from_university', array[]::text[], 'university-change refresh helper exists');
select ok(
  not has_function_privilege('anon','private.refresh_candidate_profile_from_affiliation()','execute')
  and not has_function_privilege('authenticated','private.refresh_candidate_profile_from_affiliation()','execute')
  and not has_function_privilege('anon','private.refresh_candidate_profiles_from_university()','execute')
  and not has_function_privilege('authenticated','private.refresh_candidate_profiles_from_university()','execute'),
  'projection trigger helpers are not directly executable by client roles'
);
select * from finish();
rollback;
