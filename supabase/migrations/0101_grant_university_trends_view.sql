-- The weekly aggregate is a member-scoped SECURITY DEFINER view; expose only its frozen
-- aggregate projection to authenticated callers. The view predicate applies university scope.
revoke all on public.university_trends_v from public, anon;
grant select on public.university_trends_v to authenticated;
comment on view public.university_trends_v is
  'Weekly, university-scoped aggregate projection; accessible to authenticated university members and AAL2 admins only.';
