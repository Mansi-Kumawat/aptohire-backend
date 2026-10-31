-- Organization base-table access stays intentionally narrow. Blind views are the candidate discovery surface.
grant select on public.organizations, public.organization_members, public.jobs to authenticated;
grant update(pipeline_stage) on public.access_requests to authenticated;
create policy organization_public_or_member on public.organizations for select to authenticated using(status='approved' or id=any(private.my_org_ids()) or private.is_admin());
create policy organization_member_read on public.organization_members for select to authenticated using(user_id=auth.uid() or organization_id=any(private.my_org_ids()) or private.is_admin());
create policy organization_jobs_read on public.jobs for select to authenticated using(organization_id=any(private.my_org_ids()) or private.is_admin());
create policy organization_pipeline_stage_update on public.access_requests for update to authenticated using(organization_id=any(private.my_org_ids()) and status='accepted' and expires_at>now()) with check(organization_id=any(private.my_org_ids()) and status='accepted' and expires_at>now());
-- No organization grants or policies for students, affiliations, candidate_profiles, match_results,
-- submissions, audits, scores, or roster data. Do not add these to the Data API surface.
