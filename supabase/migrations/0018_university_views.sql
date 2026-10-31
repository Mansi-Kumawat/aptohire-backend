create view public.university_students_v with (security_invoker=false) as
 select s.id as student_id,s.full_name,a.status::text as status,a.year,a.program_level,a.verification::text as verification,
        (s.user_id is not null) as claimed,
        (select count(*)::int from public.skill_scores ss where ss.student_id=s.id and ss.verified and ss.share_ok and not ss.pending_review) as verified_skills_count,
        greatest(s.updated_at,(select max(sub.updated_at) from public.submissions sub where sub.student_id=s.id)) as last_activity,
        coalesce((select p.status from public.placements p where p.student_id=s.id and p.university_id=a.university_id order by p.updated_at desc limit 1),'unknown') as placement_status,
        a.university_id
 from public.affiliations a join public.students s on s.id=a.student_id
 where a.university_id=any(private.my_university_ids()) or private.is_admin();
create view public.university_overview_v with (security_invoker=false) as
 select a.university_id,count(distinct a.student_id)::int as student_count,
        count(distinct a.student_id) filter(where s.user_id is not null)::int as claimed_count,
        count(distinct a.student_id) filter(where exists(select 1 from public.submissions sb where sb.student_id=a.student_id and sb.status='scored'))::int as assessed_count,
        count(distinct a.student_id) filter(where exists(select 1 from public.skill_scores sc where sc.student_id=a.student_id and sc.verified and sc.share_ok))::int as verified_count
 from public.affiliations a join public.students s on s.id=a.student_id
 where a.university_id=any(private.my_university_ids()) or private.is_admin() group by a.university_id;
create view public.university_funnel_v with (security_invoker=false) as
 select a.university_id,count(distinct a.student_id)::int as invited,
        count(distinct a.student_id) filter(where s.user_id is not null)::int as registered,
        count(distinct a.student_id) filter(where exists(select 1 from public.submissions sb where sb.student_id=a.student_id and sb.status in ('scored','needs_review','auditing')) )::int as submitted,
        count(distinct a.student_id) filter(where exists(select 1 from public.skill_scores sc where sc.student_id=a.student_id and sc.verified and sc.share_ok and not sc.pending_review))::int as verified
 from public.affiliations a join public.students s on s.id=a.student_id
 where a.university_id=any(private.my_university_ids()) or private.is_admin() group by a.university_id;
revoke all on public.university_students_v,public.university_overview_v,public.university_funnel_v from anon,authenticated;
grant select on public.university_students_v,public.university_overview_v,public.university_funnel_v to authenticated;
