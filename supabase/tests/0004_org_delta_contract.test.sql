begin;
select plan(13);
select has_view('public','my_organization_v','organization member view exists');
select has_column('public','my_organization_v','status_note','organization rejection note visible via member view');
select has_column('public','org_candidate_cards','structured_score','blind card has structured score');
select has_column('public','org_candidate_cards','vector_score','blind card has vector score');
select has_column('public','org_candidate_cards','scrubbed_summary','blind card has scrubbed summary');
select has_column('public','org_access_requests_v','job_title','blind access request view has job title');
select has_column('public','org_access_requests_v','responded_at','blind access request view has response timestamp');
select hasnt_column('public','org_candidate_cards','student_id','blind candidate cards omit student id');
select hasnt_column('public','org_access_requests_v','student_id','blind access requests omit student id');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='my_organization_v'),
  array['id','name','kind','size','website','status','subscription_status','verified_at','reference','status_note']::text[],
  'my_organization_v preserves the exact frozen member-view column order'
);
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='org_candidate_cards'),
  array['candidate_ref','job_id','alias','final_score','confidence','reasons','gaps','uni_category','skills','study_stage','project_count','request_status','structured_score','vector_score','scrubbed_summary']::text[],
  'org_candidate_cards preserves the exact frozen blind-card column order'
);
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='org_access_requests_v'),
  array['id','organization_id','job_id','candidate_ref','alias','status','granted_scope','expires_at','pipeline_stage','job_title','message','requested_scope','duration_days','created_at','responded_at']::text[],
  'org_access_requests_v preserves the exact frozen blind request column order'
);
select ok(not has_table_privilege('anon','public.my_organization_v','select') and not has_table_privilege('anon','public.org_candidate_cards','select'),'anon cannot read organization views');
select * from finish();
rollback;
