-- Keep the approved-organization directory public through its explicit view, not the base table.
drop policy if exists organization_public_or_member on public.organizations;
create policy organizations_member_read on public.organizations
  for select to authenticated
  using (id = any(private.my_org_ids()) or private.is_admin());
comment on policy organizations_member_read on public.organizations is
  'Organization members read only their own organization row; aal2 admins use the admin gate. The approved public directory is exposed only via public_organizations.';
comment on view public.public_organizations is
  'Approved-only organization directory for authenticated portals. This view is the intentional public-data surface; base-table RLS remains membership-scoped.';
