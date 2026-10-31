-- The former aggregate joined every score for a skill once any own-university student
-- had that skill. Restrict the input student set before aggregation to prevent cross-uni leakage.
create or replace view public.university_skills_v with (security_invoker=false) as
with caller_students as (
  select distinct r.student_id
  from public.roster_entries r
  where r.student_id is not null
    and (r.university_id=any(private.my_university_ids()) or private.is_admin())
)
select sk.id as skill_id,sk.name as skill_name,sf.name as family,
       count(distinct ss.student_id) filter(where ss.verified and ss.share_ok and not ss.pending_review)::int as verified_students,
       count(distinct ss.student_id)::int as assessed_students,
       avg(ss.score) filter(where ss.verified and ss.share_ok and not ss.pending_review) as avg_score,
       (select count(distinct job.id)::int
          from public.jobs job join public.organizations org on org.id=job.organization_id
          cross join lateral jsonb_array_elements(coalesce(job.required_skills,'[]'::jsonb)) as req(item)
         where job.status='open' and org.status='approved' and req.item->>'skill_id'=sk.id::text) as open_jobs
from public.skills sk
join public.skill_families sf on sf.id=sk.family_id
left join caller_students cs on true
left join public.skill_scores ss on ss.student_id=cs.student_id and ss.skill_id=sk.id
where private.my_university_ids() <> '{}'::uuid[] or private.is_admin()
group by sk.id,sk.name,sf.name;
comment on view public.university_skills_v is
  'University-scoped aggregate: scores are joined only for roster-linked students of the caller’s universities; admins may aggregate all; approved open-job demand only.';
