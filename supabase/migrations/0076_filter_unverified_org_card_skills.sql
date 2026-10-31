-- Employer-facing cards must never present unverified scores as candidate skills.
create or replace view public.org_candidate_cards with (security_invoker=false) as
 select m.id as candidate_ref,m.job_id,m.alias,m.final_score,m.confidence,m.reasons,m.gaps,
        cp.uni_category,
        coalesce((select jsonb_agg(jsonb_build_object('name',sk.name,'level',ss.level,'score',ss.score,'verified',ss.verified) order by sk.name)
                  from public.skill_scores ss join public.skills sk on sk.id=ss.skill_id
                  where ss.student_id=m.student_id and ss.verified and ss.share_ok and not ss.pending_review),'[]'::jsonb) as skills,
        cp.study_stage,
        (select count(*)::int from public.submissions s where s.student_id=m.student_id and s.status='scored') as project_count,
        (select r.status from public.access_requests r where r.match_result_id=m.id and r.organization_id=j.organization_id order by r.created_at desc limit 1) as request_status,
        m.structured_score,m.vector_score,cp.scrubbed_summary
 from public.match_results m join public.jobs j on j.id=m.job_id
 join public.candidate_profiles cp on cp.student_id=m.student_id
 join public.students st on st.id=m.student_id
 where j.organization_id=any(private.my_org_ids()) and cp.discoverable
   and coalesce((st.visibility->>'discoverable')::boolean,false)
   and exists(select 1 from public.skill_scores ss where ss.student_id=m.student_id and ss.verified and ss.share_ok and not ss.pending_review);
comment on view public.org_candidate_cards is
  'Blind organization gate: own organization jobs only; candidates require discoverability and at least one verified/shareable/non-pending skill; returned skills use the same gate.';
