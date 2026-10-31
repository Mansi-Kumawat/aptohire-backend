begin;
select plan(4);
select has_function('public','set_profile_role_once',array['uuid','text'],'signup role initializer exists');
select ok(has_function_privilege('service_role','public.set_profile_role_once(uuid,text)','execute'),'service role can initialize an account role');
select ok(not has_function_privilege('anon','public.set_profile_role_once(uuid,text)','execute'),'anonymous callers cannot initialize account roles');
select ok(not has_function_privilege('authenticated','public.set_profile_role_once(uuid,text)','execute'),'authenticated callers cannot initialize account roles directly');
select * from finish();
rollback;
