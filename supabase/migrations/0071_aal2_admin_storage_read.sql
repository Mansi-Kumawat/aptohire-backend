-- Admins may use authenticated Storage APIs to mint signed URLs for review media only.
-- The policy delegates the MFA gate to private.is_admin(); no Storage writes are granted.
create policy admin_review_media_select on storage.objects
  for select to authenticated
  using (bucket_id in ('videos','documents') and private.is_admin());
comment on policy admin_review_media_select on storage.objects is
  'AAL2 admins may read video/document object metadata to create short-lived review URLs; no other bucket or write access.';
