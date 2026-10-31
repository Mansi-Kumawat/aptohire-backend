begin;
select plan(4);

select ok(has_table_privilege('authenticated','public.university_skills_v','select')
 and has_table_privilege('authenticated','public.university_demand_v','select'),
 'authenticated university portals receive the intended aggregate-view SELECT grants');
select ok(not has_table_privilege('anon','public.university_skills_v','select')
 and not has_table_privilege('anon','public.university_demand_v','select'),
 'anonymous callers cannot read university aggregate views');
select ok((select relrowsecurity from pg_class where oid='storage.objects'::regclass),
 'managed Storage object ACLs remain constrained by object RLS');
select is((select count(*)::int from pg_policies where schemaname in ('public','private','storage') and ('anon'::name=any(roles) or 'public'::name=any(roles))),0,
 'no active policy in any schema directly grants anon or PUBLIC access');

select * from finish();
rollback;
