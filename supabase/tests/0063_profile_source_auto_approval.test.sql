begin;
create function pg_temp.dml_row_count(p_sql text) returns integer
language plpgsql
as $$
declare
  affected_rows integer;
begin
  execute p_sql;
  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;
select plan(33);

insert into public.students(id,full_name,primary_email) values
 ('b0820000-0000-4000-8000-000000000001','Synthetic Auto Headline',null),
 ('b0820000-0000-4000-8000-000000000002','Synthetic Auto Skills',null),
 ('b0820000-0000-4000-8000-000000000003','Synthetic Unsupported Field',null),
 ('b0820000-0000-4000-8000-000000000004','Synthetic Manual Source',null),
 ('b0820000-0000-4000-8000-000000000005','Synthetic Unsafe Headline',null),
 ('b0820000-0000-4000-8000-000000000006','Synthetic Unconsented Source',null),
 ('b0820000-0000-4000-8000-000000000007','Synthetic Social Handle Headline',null),
 ('b0820000-0000-4000-8000-000000000008','Synthetic Bare Domain Headline',null),
 ('b0820000-0000-4000-8000-000000000009','Synthetic Uncommon Domain Headline',null),
 ('b0820000-0000-4000-8000-000000000010','Synthetic Atomic Batch Fallback',null);
insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok)
select 'b0820000-0000-4000-8000-000000000002',id,84,'Advanced',true,false,true
from public.skills where slug='react';
insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('a0820000-0000-4000-8000-000000000201','authenticated','authenticated','auto-owner@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0820000-0000-4000-8000-000000000202','authenticated','authenticated','auto-other@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0820000-0000-4000-8000-000000000201','student'),
 ('a0820000-0000-4000-8000-000000000202','student');
update public.students set user_id='a0820000-0000-4000-8000-000000000201'
 where id='b0820000-0000-4000-8000-000000000001';
update public.students set user_id='a0820000-0000-4000-8000-000000000202'
 where id='b0820000-0000-4000-8000-000000000002';
insert into public.profile_sources(id,student_id,source_type,auto_approve,consented_at,revoked_at) values
 ('b0820000-0000-4000-8000-000000000101','b0820000-0000-4000-8000-000000000001','github',false,now(),null),
 ('b0820000-0000-4000-8000-000000000102','b0820000-0000-4000-8000-000000000002','github',true,now(),null),
 ('b0820000-0000-4000-8000-000000000103','b0820000-0000-4000-8000-000000000003','github',true,now(),null),
 ('b0820000-0000-4000-8000-000000000104','b0820000-0000-4000-8000-000000000004','github',false,now(),null),
 ('b0820000-0000-4000-8000-000000000105','b0820000-0000-4000-8000-000000000005','github',true,now(),null),
 ('b0820000-0000-4000-8000-000000000106','b0820000-0000-4000-8000-000000000006','github',true,null,null),
 ('b0820000-0000-4000-8000-000000000107','b0820000-0000-4000-8000-000000000001','github',false,now(),now()),
 ('b0820000-0000-4000-8000-000000000108','b0820000-0000-4000-8000-000000000007','github',true,now(),null),
 ('b0820000-0000-4000-8000-000000000109','b0820000-0000-4000-8000-000000000008','github',true,now(),null),
 ('b0820000-0000-4000-8000-000000000110','b0820000-0000-4000-8000-000000000009','github',true,now(),null),
 ('b0820000-0000-4000-8000-000000000111','b0820000-0000-4000-8000-000000000010','github',true,now(),null);

select ok(exists(
  select 1 from pg_policies
   where schemaname='public' and tablename='profile_sources'
     and policyname='profile_sources_self_auto_approve' and cmd='UPDATE'
     and 'authenticated'::name=any(roles)
     and qual ilike '%revoked_at%'
     and with_check ilike '%revoked_at%'
),'profile_sources_self_auto_approve enforces active-source ownership in USING and WITH CHECK');
select ok(
  has_column_privilege('authenticated','public.profile_sources','auto_approve','UPDATE')
  and not has_column_privilege('authenticated','public.profile_sources','token_secret_id','UPDATE'),
  'authenticated can update only the auto-approval preference, not the Vault reference'
);
select ok(
  not has_column_privilege('anon','public.profile_sources','auto_approve','UPDATE'),
  'anonymous role cannot change source auto-approval'
);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0820000-0000-4000-8000-000000000201","role":"authenticated","aal":"aal1"}',true);
select is(pg_temp.dml_row_count($$update public.profile_sources set auto_approve=true where id='b0820000-0000-4000-8000-000000000101'$$),1,'student can change auto-approval on own active source');
select is(pg_temp.dml_row_count($$update public.profile_sources set auto_approve=true where id='b0820000-0000-4000-8000-000000000102'$$),0,'student cannot change another student source preference');
select is(pg_temp.dml_row_count($$update public.profile_sources set auto_approve=true where id='b0820000-0000-4000-8000-000000000107'$$),0,'student cannot change a revoked source preference');
reset role;

select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000001','b0820000-0000-4000-8000-000000000101','github',
    '[{"field":"headline","action":"update","value":"Frontend developer","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'consented auto-approval applies a bounded headline proposal'
);
select is(
  (select headline from public.students where id='b0820000-0000-4000-8000-000000000001'),
  'Frontend developer',
  'approved headline is atomically applied to the student profile'
);
select is(
  (select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000101'),
  'approved',
  'safe auto-applied proposal is recorded as approved'
);
select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000002','b0820000-0000-4000-8000-000000000102','github',
    '[{"field":"skills_interest","action":"update","value":["react","typescript"],"evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'consented auto-approval resolves skill-interest slugs to catalog ids'
);
select ok(
  (select target_skill_ids @> array[(select id from public.skills where slug='react'),(select id from public.skills where slug='typescript')]
     from public.students where id='b0820000-0000-4000-8000-000000000002'),
  'auto-applied interests resolve only requested catalog skill ids'
);
select ok(
  (select score=84 and verified and not pending_review from public.skill_scores
   where student_id='b0820000-0000-4000-8000-000000000002'
     and skill_id=(select id from public.skills where slug='react')),
  'profile auto-approval leaves the existing verified score unchanged'
);
select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000003','b0820000-0000-4000-8000-000000000103','github',
    '[{"field":"experience","action":"add","value":"Fictional experience","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'unsupported fields remain reviewable instead of being auto-applied'
);
select is(
  (select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000103'),
  'pending',
  'unsupported auto-approval proposal remains pending'
);
select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000004','b0820000-0000-4000-8000-000000000104','github',
    '[{"field":"headline","action":"update","value":"Manual review headline","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'source without auto-approval still records a pending proposal'
);
select is(
  (select headline from public.students where id='b0820000-0000-4000-8000-000000000004'),
  null::text,
  'non-auto-approved proposal does not alter student profile content'
);
select is(
  (select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000104'),
  'pending',
  'ordinary consented source proposal remains pending review'
);
select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000005','b0820000-0000-4000-8000-000000000105','github',
    '[{"field":"headline","action":"update","value":"Contact me at sam@example.test","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'unsafe contact-containing headline is retained for review, not auto-applied'
);
select is(
  (select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000105'),
  'pending',
  'contact-containing headline proposal remains pending'
);
select is(
  (select headline from public.students where id='b0820000-0000-4000-8000-000000000005'),
  null::text,
  'unsafe auto-approval content does not change the student profile'
);
select throws_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000006','b0820000-0000-4000-8000-000000000106','github',
    '[{"field":"headline","action":"update","value":"No consent","evidence":"Fictional source"}]'::jsonb
  )$$,
  'P0002',
  'active consented profile source not found',
  'unconsented source cannot persist or auto-apply a proposal'
);

select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000007','b0820000-0000-4000-8000-000000000108','github',
    '[{"field":"headline","action":"update","value":"@sohan_dev","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'social-handle headline is retained as a pending proposal'
);
select is((select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000108'),'pending','social-handle headline is not auto-approved');
select is((select headline from public.students where id='b0820000-0000-4000-8000-000000000007'),null::text,'social handle does not enter the profile headline');
select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000008','b0820000-0000-4000-8000-000000000109','github',
    '[{"field":"headline","action":"update","value":"linkedin.com/in/sohan","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'bare-domain headline is retained as a pending proposal'
);
select is((select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000109'),'pending','bare-domain headline is not auto-approved');
select is((select headline from public.students where id='b0820000-0000-4000-8000-000000000008'),null::text,'bare domain does not enter the profile headline');

select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000009','b0820000-0000-4000-8000-000000000110','github',
    '[{"field":"headline","action":"update","value":"myportfolio.xyz","evidence":"Fictional consented source"}]'::jsonb
  )$$,
  'bare domain with an uncommon TLD remains pending'
);
select is((select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000110'),'pending','uncommon-TLD domain is not auto-approved');
select is((select headline from public.students where id='b0820000-0000-4000-8000-000000000009'),null::text,'uncommon-TLD domain does not enter the profile headline');

select lives_ok(
  $$select public.persist_profile_proposal(
    'b0820000-0000-4000-8000-000000000010','b0820000-0000-4000-8000-000000000111','github',
    '[{"field":"headline","action":"update","value":"Safe headline must not partially apply","evidence":"Fictional source"},{"field":"experience","action":"add","value":"Unsupported mapping","evidence":"Fictional source"}]'::jsonb
  )$$,
  'mixed safe and unsupported proposals are retained as one pending batch'
);
select is((select state from public.profile_proposals where source_id='b0820000-0000-4000-8000-000000000111'),'pending','mixed batch is pending as a whole');
select is((select headline from public.students where id='b0820000-0000-4000-8000-000000000010'),null::text,'safe headline is not partially applied from a mixed batch');

select * from finish();
rollback;
