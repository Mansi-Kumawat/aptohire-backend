-- Add an organization-internal review step for accepted candidates.
-- Access remains gated by the existing accepted + unexpired RLS policy.
alter table public.access_requests
  drop constraint if exists access_requests_pipeline_stage_check;

alter table public.access_requests
  add constraint access_requests_pipeline_stage_check
  check (pipeline_stage is null or pipeline_stage in ('reviewed', 'interviewing', 'offered', 'closed'));
