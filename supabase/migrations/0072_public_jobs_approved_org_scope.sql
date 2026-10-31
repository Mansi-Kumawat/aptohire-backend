-- Keep the public job projection limited to open jobs owned by approved organizations.
-- required_skills is the safe structured field the university portal needs to view demand.
create or replace view public.public_jobs with (security_invoker=false) as
 select j.id,j.organization_id,j.title,j.mode,j.location,j.status,j.required_skills
 from public.jobs j
 join public.organizations o on o.id=j.organization_id
 where j.status='open'
   and o.status='approved'
   and private.app_role() in ('student','university','admin');

comment on view public.public_jobs is
  'Safe public job projection for students, university members, and admins; only open jobs at approved organizations, including structured required skills.';
