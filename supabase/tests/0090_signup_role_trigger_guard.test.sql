begin;
select plan(2);
select has_function('private', 'reject_profile_role_change', 'the profile role guard exists');
select ok(
  (select pg_get_functiondef('private.reject_profile_role_change()'::regprocedure) ilike '%auth.role()%service_role%'),
  'the role guard checks the caller JWT role, not SECURITY DEFINER current_user'
);
select * from finish();
rollback;
