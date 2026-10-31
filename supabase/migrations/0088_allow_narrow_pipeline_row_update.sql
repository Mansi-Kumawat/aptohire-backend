-- PostgreSQL applies SELECT privileges and a SELECT policy to rows read by UPDATE.
-- Expose only non-student-identifying columns for accepted, active organization requests;
-- keep student_id/job_id/requested_scope/granted_scope unavailable to organization clients.
grant select (id,organization_id,status,expires_at,pipeline_stage) on public.access_requests to authenticated;
drop policy if exists organization_pipeline_stage_read on public.access_requests;
create policy organization_pipeline_stage_read on public.access_requests for select to authenticated using(
  organization_id=any(private.my_org_ids()) and status='accepted' and expires_at>now()
);
