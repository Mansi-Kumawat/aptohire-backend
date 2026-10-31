-- University staff need the membership roster for their own university, but not other universities.
drop policy if exists members_self_read on public.university_members;
create policy university_members_scope_read on public.university_members
  for select to authenticated
  using (user_id = auth.uid() or university_id = any(private.my_university_ids()) or private.is_admin());
comment on policy university_members_scope_read on public.university_members is
  'Users see their own membership; university members see membership rows for their own university; aal2 admins see all.';
