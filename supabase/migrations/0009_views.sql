create view public.public_config with (security_invoker=false) as
 select key,value from public.app_config where key in ('PASS_MARK','BORDERLINE_LOW','BORDERLINE_HIGH','REQUIRE_VIDEO','VIDEO_MAX_MB','VIDEO_MAX_SECONDS','AI_KILL_SWITCH','AI_DAILY_CAP_PER_USER');
create view public.public_universities with (security_invoker=false) as
 select id,name,short_name,tier,kind,city,state,status from public.universities where status='approved';
create view public.public_organizations with (security_invoker=false) as
 select id,name,kind,size,website,(verified_at is not null) as verified from public.organizations where status='approved';
create view public.public_jobs with (security_invoker=false) as
 select j.id,j.organization_id,j.title,j.mode,j.location,j.status from public.jobs j where j.status='open' and private.app_role() in ('student','university','admin');
create view public.org_candidate_cards with (security_invoker=false) as
 select m.id as candidate_ref,m.job_id,m.alias,m.final_score,m.confidence,m.reasons,m.gaps,
        cp.uni_category,cp.skills,cp.study_stage,
        (select count(*)::int from public.submissions s where s.student_id=m.student_id and s.status='scored') as project_count,
        (select r.status from public.access_requests r where r.match_result_id=m.id and r.organization_id=j.organization_id order by r.created_at desc limit 1) as request_status
 from public.match_results m join public.jobs j on j.id=m.job_id
 join public.candidate_profiles cp on cp.student_id=m.student_id
 where j.organization_id=any(private.my_org_ids()) and cp.discoverable;
create view public.org_access_requests_v with (security_invoker=false) as
 select r.id,r.organization_id,r.job_id,m.id as candidate_ref,m.alias,r.status,r.granted_scope,r.expires_at,r.pipeline_stage
 from public.access_requests r join public.match_results m on m.id=r.match_result_id
 where r.organization_id=any(private.my_org_ids());
create view public.student_access_requests_v with (security_invoker=false) as
 select r.id,o.name as organization_name,(o.verified_at is not null) as organization_verified,j.title as job_title,r.message,r.requested_scope,r.granted_scope,r.duration_days,r.status,r.expires_at,r.created_at,r.responded_at
 from public.access_requests r join public.organizations o on o.id=r.organization_id join public.jobs j on j.id=r.job_id
 where r.student_id=private.my_student_id();
create view public.my_affiliation_proposals with (security_invoker=false) as
 select ap.id,ap.student_id,ap.university_id,u.name as university_name,u.short_name,u.city,u.state as university_state,ap.program_level,ap.status,ap.year,ap.state as proposal_state,ap.created_at
 from public.affiliation_proposals ap join public.universities u on u.id=ap.university_id where ap.student_id=private.my_student_id();
create view public.org_revealed_students with (security_invoker=false) as
 select r.id as request_id,
        case when 'profile'=any(r.granted_scope) then s.full_name end as full_name,
        case when 'profile'=any(r.granted_scope) then s.headline end as headline,
        case when 'profile'=any(r.granted_scope) then s.bio end as bio,
        case when 'profile'=any(r.granted_scope) then s.location end as location,
        case when 'profile'=any(r.granted_scope) then s.links end as links,
        case when 'profile'=any(r.granted_scope) then u.name end as university_name,
        case when 'profile'=any(r.granted_scope) then a.verification::text end as verification,
        case when 'contact'=any(r.granted_scope) then s.primary_email::text end as primary_email
 from public.access_requests r join public.students s on s.id=r.student_id
 left join public.affiliations a on a.student_id=s.id and a.is_current
 left join public.universities u on u.id=a.university_id
 where r.organization_id=any(private.my_org_ids()) and r.status='accepted' and r.expires_at>now()
   and ('profile'=any(r.granted_scope) or 'contact'=any(r.granted_scope));
revoke all on public.public_config,public.public_universities,public.public_organizations,public.public_jobs,public.org_candidate_cards,public.org_access_requests_v,public.student_access_requests_v,public.my_affiliation_proposals,public.org_revealed_students from anon,authenticated;
grant select on public.public_config,public.public_universities,public.public_organizations to authenticated;
grant select on public.public_jobs to authenticated;
grant select on public.org_candidate_cards,public.org_access_requests_v,public.org_revealed_students to authenticated;
grant select on public.student_access_requests_v,public.my_affiliation_proposals to authenticated;
