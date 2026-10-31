-- Keep seeded project variation choices anonymous and prevent common slot combinations from dominating one template.
alter table public.project_assignments
  add column if not exists variation_fingerprint text
  check (variation_fingerprint is null or variation_fingerprint ~ '^[0-9a-f]{64}$');

-- The fingerprint contains no raw slot values and is written only by the authenticated assignment endpoint.
grant insert (variation_fingerprint) on public.project_assignments to authenticated;
revoke update (variation_fingerprint) on public.project_assignments from authenticated;

create index if not exists project_assignments_template_variation_recent_idx
  on public.project_assignments (template_id, variation_fingerprint, created_at desc)
  where variation_fingerprint is not null;

comment on column public.project_assignments.variation_fingerprint is
  'HMAC-SHA256 fingerprint of selected template variation slots; no raw slot values are stored.';
