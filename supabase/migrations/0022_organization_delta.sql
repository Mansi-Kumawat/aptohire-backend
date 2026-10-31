-- Member-scoped organization profile and status note for applicant follow-up.
create view public.my_organization_v with (security_invoker=false) as
 select o.id,o.name,o.kind,o.size,o.website,o.status,o.subscription_status,o.verified_at,o.reference,o.status_note
 from public.organizations o where o.id=any(private.my_org_ids()) or private.is_admin();
revoke all on public.my_organization_v from public,anon,authenticated;
grant select on public.my_organization_v to authenticated;
comment on view public.my_organization_v is 'Security-definer gate: only caller organization memberships and aal2 admins.';

-- Job contract and lifecycle constraints.
update public.jobs set status='paused' where status not in ('open','paused','closed');
alter table public.jobs alter column status set default 'paused';
alter table public.jobs add constraint jobs_status_allowed check(status in ('open','paused','closed'));
alter table public.jobs add column openings int not null default 1 check(openings between 1 and 1000);
alter table public.jobs add constraint jobs_required_skills_array check(jsonb_typeof(required_skills)='array');

-- Organizations may manage jobs only when they belong to an approved organization.
drop policy if exists organization_jobs_read on public.jobs;
create policy organization_jobs_read on public.jobs for select to authenticated
 using((organization_id=any(private.my_org_ids()) and exists(select 1 from public.organizations o where o.id=organization_id and o.status='approved')) or private.is_admin());
create policy organization_jobs_insert on public.jobs for insert to authenticated
 with check(organization_id=any(private.my_org_ids()) and exists(select 1 from public.organizations o where o.id=organization_id and o.status='approved'));
create policy organization_jobs_update on public.jobs for update to authenticated
 using(organization_id=any(private.my_org_ids()) and exists(select 1 from public.organizations o where o.id=organization_id and o.status='approved'))
 with check(organization_id=any(private.my_org_ids()) and exists(select 1 from public.organizations o where o.id=organization_id and o.status='approved'));
grant insert (organization_id,title,description,mode,location,status,required_skills,openings) on public.jobs to authenticated;
grant update (title,description,mode,location,status,required_skills,openings) on public.jobs to authenticated;

-- Universities receive the safe job fields through the public view; organizations cannot use this view.
create or replace view public.public_jobs with (security_invoker=false) as
 select j.id,j.organization_id,j.title,j.mode,j.location,j.status,j.required_skills
 from public.jobs j where j.status='open' and private.app_role() in ('student','university','admin');

-- Matching scores are safe, non-identity metadata shown only in the job-scoped blind view.
alter table public.match_results add column structured_score numeric check(structured_score between 0 and 100);
alter table public.match_results add column vector_score numeric check(vector_score between 0 and 100);
create or replace view public.org_candidate_cards with (security_invoker=false) as
 select m.id as candidate_ref,m.job_id,m.alias,m.final_score,m.confidence,m.reasons,m.gaps,
        cp.uni_category,
        coalesce((select jsonb_agg(jsonb_build_object('name',sk.name,'level',ss.level,'score',ss.score,'verified',ss.verified) order by sk.name)
                  from public.skill_scores ss join public.skills sk on sk.id=ss.skill_id
                  where ss.student_id=m.student_id and ss.share_ok and not ss.pending_review),'[]'::jsonb) as skills,
        cp.study_stage,
        (select count(*)::int from public.submissions s where s.student_id=m.student_id and s.status='scored') as project_count,
        (select r.status from public.access_requests r where r.match_result_id=m.id and r.organization_id=j.organization_id order by r.created_at desc limit 1) as request_status,
        m.structured_score,m.vector_score,cp.scrubbed_summary
 from public.match_results m join public.jobs j on j.id=m.job_id
 join public.candidate_profiles cp on cp.student_id=m.student_id
 join public.students st on st.id=m.student_id
 where j.organization_id=any(private.my_org_ids()) and cp.discoverable
   and coalesce((st.visibility->>'discoverable')::boolean,false)
   and exists(select 1 from public.skill_scores ss where ss.student_id=m.student_id and ss.share_ok and not ss.pending_review);
comment on view public.org_candidate_cards is 'Blind security-definer gate: own organization jobs only; no student id or identity columns; candidates require discoverable visibility and shareable scores.';

create or replace view public.org_access_requests_v with (security_invoker=false) as
 select r.id,r.organization_id,r.job_id,m.id as candidate_ref,m.alias,r.status,r.granted_scope,r.expires_at,r.pipeline_stage,
        j.title as job_title,r.message,r.requested_scope,r.duration_days,r.created_at,r.responded_at
 from public.access_requests r join public.match_results m on m.id=r.match_result_id
 join public.jobs j on j.id=r.job_id
 where r.organization_id=any(private.my_org_ids());
comment on view public.org_access_requests_v is 'Blind security-definer gate: own organization requests only; identity columns are not selected.';

-- Skills and feedback-option catalogs are safe for any authenticated portal.
grant select on public.skill_families,public.skills,public.feedback_options to authenticated;
create policy feedback_options_authenticated_read on public.feedback_options for select to authenticated using(true);

-- Feedback is insert-only for an org member who received this student's consented reveal.
grant insert (organization_id,student_id,request_id,option_codes,note) on public.feedback to authenticated;
create policy feedback_org_insert on public.feedback for insert to authenticated with check(
 organization_id=any(private.my_org_ids())
 and exists(select 1 from public.access_requests r where r.id=request_id and r.organization_id=feedback.organization_id and r.student_id=feedback.student_id and r.status in ('accepted','expired') and r.responded_at is not null)
 and not exists(select 1 from unnest(option_codes) as chosen(code) where not exists(select 1 from public.feedback_options fo where fo.option_code=chosen.code))
 and (note is null or length(note)<=280)
);
