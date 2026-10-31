begin;
select plan(18);

select has_function('private','job_required_skills_are_valid',array['jsonb'],'private job requirement validator exists');
select has_trigger('public','jobs','jobs_validate_required_skills','job writes invoke strict requirement validation');
select ok(not has_function_privilege('authenticated','private.job_required_skills_are_valid(jsonb)','execute'),'authenticated clients cannot invoke the private validator');

insert into public.skill_families(id,slug,name)
values('a0800000-0000-4000-8000-000000000002','requirements-test','Requirements Test');
insert into public.skills(id,family_id,slug,name)
values('a0800000-0000-4000-8000-000000000010','a0800000-0000-4000-8000-000000000002','requirements-skill','Requirements Skill');
insert into public.organizations(id,name,kind,size,website,status)
values('a0800000-0000-4000-8000-000000000001','Synthetic Requirements Org','corporate','small','https://requirements.example.test','approved');

select lives_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Valid requirements','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"Competent","weight":1.25}]'::jsonb)$$,
'valid strict job requirements are accepted');
select lives_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Empty draft requirements','paused','[]'::jsonb)$$,
'empty requirements remain representable for an unconfigured job');
select lives_ok($$update public.jobs set required_skills='[]'::jsonb where title='Valid requirements'$$,
'job updates revalidate and accept an empty requirement array');
select throws_ok($$update public.jobs set required_skills='{}'::jsonb where title='Valid requirements'$$,
'23514',null,'job updates reject malformed requirements');

select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Scalar item','paused','[null]'::jsonb)$$,'23514',null,'non-object requirement items are rejected');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Extra property','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"Competent","weight":1,"candidate_name":"not allowed"}]'::jsonb)$$,'23514',null,'unknown requirement keys are rejected');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Bad identifier','paused',
'[{"skill_id":"not-a-uuid","min_level":"Competent","weight":1}]'::jsonb)$$,'23514',null,'skill ids must be UUID strings');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Unknown skill','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000099","min_level":"Competent","weight":1}]'::jsonb)$$,'23514',null,'skill ids must reference existing skills');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Bad level','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"expert","weight":1}]'::jsonb)$$,'23514',null,'minimum level is restricted to the frozen level set');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Text weight','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"Competent","weight":"1"}]'::jsonb)$$,'23514',null,'weight must be a JSON number rather than a string');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Low weight','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"Competent","weight":0.001}]'::jsonb)$$,'23514',null,'weight below 0.01 is rejected');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','High weight','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"Competent","weight":100.01}]'::jsonb)$$,'23514',null,'weight above 100 is rejected');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Duplicate case-normalized UUID','paused',
'[{"skill_id":"a0800000-0000-4000-8000-000000000010","min_level":"Competent","weight":1},{"skill_id":"A0800000-0000-4000-8000-000000000010","min_level":"Advanced","weight":1}]'::jsonb)$$,'23514',null,'duplicate skill ids are rejected independent of UUID casing');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Too many requirements','paused',
(select jsonb_agg(jsonb_build_object('skill_id',md5(i::text)::uuid,'min_level','Competent','weight',1) order by i) from generate_series(1,31) i))$$,
'23514',null,'requirement arrays are capped at thirty items');
select throws_ok($$insert into public.jobs(organization_id,title,status,required_skills)
values('a0800000-0000-4000-8000-000000000001','Non-array requirements','paused','{}'::jsonb)$$,'23514',null,'non-array requirement values are rejected');

select * from finish();
rollback;
