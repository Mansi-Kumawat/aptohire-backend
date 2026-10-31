begin;
select plan(17);
select ok(has_column_privilege('authenticated','public.roster_entries','year','UPDATE'),'roster year is updatable');
select ok(has_column_privilege('authenticated','public.roster_entries','status','UPDATE'),'roster status is updatable');
select ok(has_column_privilege('authenticated','public.roster_entries','program','UPDATE'),'roster program is updatable');
select ok(has_column_privilege('authenticated','public.roster_entries','program_level','UPDATE'),'roster program level is updatable');
select ok(not has_column_privilege('authenticated','public.roster_entries','email','UPDATE'),'roster email is not updatable');
select ok(not has_column_privilege('authenticated','public.roster_entries','student_id','UPDATE'),'roster student link is not updatable');
select ok(not has_column_privilege('authenticated','public.roster_entries','student_id_hash','UPDATE'),'roster ID hash is not updatable');
select ok(not has_column_privilege('authenticated','public.roster_entries','id','UPDATE')
  and not has_column_privilege('authenticated','public.roster_entries','university_id','UPDATE')
  and not has_column_privilege('authenticated','public.roster_entries','full_name','UPDATE')
  and not has_column_privilege('authenticated','public.roster_entries','created_at','UPDATE'),
  'roster identity, owner, and system columns are not updatable');
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name in ('university_overview_v','university_funnel_v','university_skills_v','university_trends_v','university_demand_v') and column_name in ('student_id','full_name','email','student_name')),0,'university analytics expose no student identity columns');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='roster_entries' and policyname='roster_university_delete_unclaimed' and qual ~* 'student_id\s+is\s+null'),'roster deletion policy is limited to unclaimed rows');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='university_roster_objects_delete' and qual ilike '%bucket_id%' and qual ilike '%my_university_ids%'),'roster object deletion is scoped to member university paths');
select ok(not (select attnotnull from pg_attribute where attrelid='public.placements'::regclass and attname='student_id' and not attisdropped),'placements support an unclaimed roster entry without a student row');
select ok(has_column_privilege('authenticated','public.placements','roster_entry_id','INSERT'),'university placement insert can target a roster entry');
select ok(not has_column_privilege('authenticated','public.placements','student_id','INSERT'),'university cannot assign the linked student id');
select ok(has_table_privilege('authenticated','public.university_student_skills_v','select'),'university student skills view is granted to authenticated callers');
select ok(not has_table_privilege('anon','public.university_student_skills_v','select'),'anonymous callers cannot read university student skills');
select is((select count(*)::int from information_schema.columns where table_schema='public' and table_name='university_students_v' and column_name in ('student_id','roster_entry_id','program')),3,'university student projection preserves linked id and roster/program fields');
select * from finish();
rollback;
