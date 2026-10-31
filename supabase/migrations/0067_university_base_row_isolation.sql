-- Keep the approved-university directory public through its explicit view, not the base table.
drop policy if exists university_public_approved on public.universities;
create policy universities_member_read on public.universities
  for select to authenticated
  using (id = any(private.my_university_ids()) or private.is_admin());
comment on policy universities_member_read on public.universities is
  'University members read only their own university row; aal2 admins use the admin gate. The approved public directory is exposed only via public_universities.';
comment on view public.public_universities is
  'Approved-only university directory for authenticated portals. This view is the intentional public-data surface; base-table RLS remains membership-scoped.';
