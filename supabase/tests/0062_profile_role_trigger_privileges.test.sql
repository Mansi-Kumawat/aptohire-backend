begin;
select plan(8);

select has_function('private','reject_profile_role_change',array[]::text[],'profile-role immutability trigger function remains installed');
select set_config('request.jwt.claim.role','authenticated',true);
select throws_ok(
  $$update public.profiles set role='admin' where id=md5('seed:auth:aarav@unia.edu.test')::uuid$$,
  'P0001',
  'role changes require privileged provisioning',
  'an authenticated JWT role cannot change a profile role'
);
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok(
  $$update public.profiles set role='admin' where id=md5('seed:auth:aarav@unia.edu.test')::uuid$$,
  'privileged provisioning claim can change a profile role'
);

select is(
  (select t.tgenabled::text from pg_trigger t
    join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='profiles' and t.tgname='profiles_role_immutable'),
  'O',
  'profile role immutability trigger remains enabled for ordinary writes'
);
select ok(
  not has_column_privilege('anon','public.profiles','role','UPDATE')
  and not has_column_privilege('authenticated','public.profiles','role','UPDATE'),
  'browser roles have no direct UPDATE privilege on profiles.role'
);
select is(
  (select count(*)::int
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
    where n.nspname='private' and p.proname='reject_profile_role_change'
      and acl.grantee=0 and acl.privilege_type='EXECUTE'),
  0,
  'PUBLIC has no direct execute grant on the SECURITY DEFINER trigger helper'
);
select ok(
  not has_function_privilege('anon','private.reject_profile_role_change()','execute')
  and not has_function_privilege('authenticated','private.reject_profile_role_change()','execute'),
  'browser roles cannot directly execute the trigger-only helper'
);
select ok(
  not has_function_privilege('service_role','private.reject_profile_role_change()','execute'),
  'service role cannot directly invoke the trigger-only helper'
);

select * from finish();
rollback;
