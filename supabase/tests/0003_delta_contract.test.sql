begin;
select plan(15);
select has_view('public','my_university_v','university member profile view exists');
select has_column('public','my_university_v','status_note','university rejection note is exposed only through member view');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='my_university_v'),
  array['id','name','short_name','kind','tier','city','state','status','email_domains','approved_at','reference','status_note']::text[],
  'my_university_v preserves the exact frozen output column order'
);
select has_column('public','university_students_v','roster_entry_id','student projection has stable roster key');
select has_column('public','university_students_v','student_id','claimed student id is nullable for unclaimed roster rows');
select has_column('public','university_students_v','program','student projection exposes program');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_students_v'),
  array['student_id','full_name','status','year','program_level','verification','claimed','verified_skills_count','last_activity','placement_status','university_id','roster_entry_id','program']::text[],
  'university_students_v preserves the exact frozen roster projection column order'
);
select has_view('public','university_student_skills_v','verified skills view exists');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='university_student_skills_v'),
  array['student_id','skill_name','family','level','score','verified_on']::text[],
  'university_student_skills_v preserves the exact frozen output column order'
);
select has_column('public','university_overview_v','students_total','overview has delta totals');
select has_column('public','university_funnel_v','program','funnel supports program cohort');
select has_view('public','university_skills_v','skills analytics exists');
select has_view('public','university_trends_v','weekly trends exists');
select has_view('public','university_demand_v','unmatched demand view exists');
select ok(not has_table_privilege('anon','public.my_university_v','select') and not has_table_privilege('anon','public.university_student_skills_v','select'),'anon cannot read university views');
select * from finish();
rollback;
