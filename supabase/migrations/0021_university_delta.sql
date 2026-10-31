-- Forward-only university contract expansion. Existing columns remain first where possible.
alter table public.roster_entries add column if not exists full_name text;
alter table public.roster_entries add column if not exists program text;
alter table public.roster_entries add column if not exists student_id uuid references public.students on delete set null;
alter table public.affiliations add column if not exists roster_entry_id uuid references public.roster_entries on delete set null;
create unique index if not exists one_current_affiliation_per_roster_entry on public.affiliations(roster_entry_id) where is_current and roster_entry_id is not null;
alter table public.placements alter column student_id drop not null;
alter table public.placements add column if not exists roster_entry_id uuid references public.roster_entries on delete set null;
alter table public.placements add constraint placements_subject_required check(student_id is not null or roster_entry_id is not null);

-- Revoke prior broad column allowances. Hashes and linked student IDs remain function-only.
revoke update(email,program_level,year,status) on public.roster_entries from authenticated;
grant update(year,status,program,program_level) on public.roster_entries to authenticated;
revoke delete on public.roster_entries from authenticated;
grant delete on public.roster_entries to authenticated;
drop policy if exists roster_university_delete on public.roster_entries;
create policy roster_university_delete_unclaimed on public.roster_entries for delete to authenticated
 using(university_id=any(private.my_university_ids()) and student_id is null);

-- Member-only university identity view; owner-security is intentional and the WHERE clause is the gate.
create view public.my_university_v with (security_invoker=false) as
 select u.id,u.name,u.short_name,u.kind,u.tier,u.city,u.state,u.status,u.email_domains,u.approved_at,u.reference,u.status_note
 from public.universities u where u.id=any(private.my_university_ids()) or private.is_admin();
revoke all on public.my_university_v from public,anon,authenticated;
grant select on public.my_university_v to authenticated;
comment on view public.my_university_v is 'Security-definer gate: returns only universities in private.my_university_ids(), plus aal2 admins.';

-- Roster-first projection supports unclaimed rows; existing output columns retain their order.
create or replace view public.university_students_v with (security_invoker=false) as
 select r.student_id,
        coalesce(s.full_name,r.full_name) as full_name,
        coalesce(a.status::text,r.status::text) as status,
        coalesce(a.year,r.year) as year,
        coalesce(a.program_level,r.program_level) as program_level,
        a.verification::text as verification,
        (r.student_id is not null) as claimed,
        coalesce((select count(*)::int from public.skill_scores ss where ss.student_id=r.student_id and ss.verified and ss.share_ok and not ss.pending_review),0) as verified_skills_count,
        greatest(s.updated_at,(select max(sub.updated_at) from public.submissions sub where sub.student_id=r.student_id),r.created_at) as last_activity,
        coalesce((select p.status from public.placements p where (p.student_id=r.student_id or p.roster_entry_id=r.id) and p.university_id=r.university_id order by p.updated_at desc limit 1),'unknown') as placement_status,
        r.university_id,
        r.id as roster_entry_id,
        r.program
 from public.roster_entries r
 left join public.students s on s.id=r.student_id
 left join public.affiliations a on a.roster_entry_id=r.id and a.is_current
 where r.university_id=any(private.my_university_ids()) or private.is_admin();

create view public.university_student_skills_v with (security_invoker=false) as
 select distinct r.student_id,ski.name as skill_name,sf.name as family,ss.level,ss.score,ss.updated_at as verified_on
 from public.roster_entries r
 join public.skill_scores ss on ss.student_id=r.student_id and ss.verified and ss.share_ok and not ss.pending_review
 join public.skills ski on ski.id=ss.skill_id
 join public.skill_families sf on sf.id=ski.family_id
 where r.university_id=any(private.my_university_ids()) or private.is_admin();
revoke all on public.university_student_skills_v from public,anon,authenticated;
grant select on public.university_student_skills_v to authenticated;
comment on view public.university_student_skills_v is 'University-scoped gate; only verified, shareable, non-pending skill scores.';

-- Keep the existing aggregate columns first; append requested counters as compatibility-safe columns.
create or replace view public.university_overview_v with (security_invoker=false) as
 select a.university_id,count(distinct a.student_id)::int as student_count,
        count(distinct a.student_id) filter(where s.user_id is not null)::int as claimed_count,
        count(distinct a.student_id) filter(where exists(select 1 from public.submissions sb where sb.student_id=a.student_id and sb.status='scored'))::int as assessed_count,
        count(distinct a.student_id) filter(where exists(select 1 from public.skill_scores sc where sc.student_id=a.student_id and sc.verified and sc.share_ok and not sc.pending_review))::int as verified_count,
        count(distinct r.id)::int as students_total,
        count(distinct r.student_id) filter(where exists(select 1 from public.skill_scores sc where sc.student_id=r.student_id and sc.verified and sc.share_ok and not sc.pending_review))::int as verified_students,
        count(distinct r.student_id) filter(where s.updated_at>=date_trunc('month',now()))::int as active_this_month,
        count(distinct au.id)::int as projects_reviewed
 from public.affiliations a join public.students s on s.id=a.student_id
 left join public.roster_entries r on r.university_id=a.university_id
 left join public.audits au on au.submission_id in (select sub.id from public.submissions sub where sub.student_id=a.student_id)
 where a.university_id=any(private.my_university_ids()) or private.is_admin()
 group by a.university_id;

-- Cohort breakdown; legacy aggregate fields remain present, with cohort columns appended.
create or replace view public.university_funnel_v with (security_invoker=false) as
 select r.university_id,
        count(distinct r.id)::int as invited,
        count(distinct r.id) filter(where r.student_id is not null)::int as registered,
        count(distinct r.id) filter(where exists(select 1 from public.submissions sb where sb.student_id=r.student_id and sb.status in ('scored','needs_review','auditing')) )::int as submitted,
        count(distinct r.id) filter(where exists(select 1 from public.skill_scores sc where sc.student_id=r.student_id and sc.verified and sc.share_ok and not sc.pending_review))::int as verified,
        r.year,coalesce(r.program,'') as program,r.status::text as status
 from public.roster_entries r
 where r.university_id=any(private.my_university_ids()) or private.is_admin()
 group by r.university_id,r.year,coalesce(r.program,''),r.status;

create view public.university_skills_v with (security_invoker=false) as
 select sk.id as skill_id,sk.name as skill_name,sf.name as family,
        count(distinct ss.student_id) filter(where ss.verified and ss.share_ok and not ss.pending_review)::int as verified_students,
        count(distinct ss.student_id)::int as assessed_students,
        avg(ss.score) filter(where ss.share_ok and not ss.pending_review) as avg_score,
        (select count(distinct job.id)::int from public.jobs job cross join lateral jsonb_array_elements(coalesce(job.required_skills,'[]'::jsonb)) as req(item) where job.status='open' and req.item->>'skill_id'=sk.id::text) as open_jobs
 from public.skills sk join public.skill_families sf on sf.id=sk.family_id
 left join public.skill_scores ss on ss.skill_id=sk.id
 where exists(select 1 from public.affiliations a where a.student_id=ss.student_id and a.university_id=any(private.my_university_ids())) or private.is_admin()
 group by sk.id,sk.name,sf.name;

create view public.university_trends_v with (security_invoker=false) as
 with weeks as (select generate_series(date_trunc('week',now())-interval '25 weeks',date_trunc('week',now()),interval '1 week')::date as week_start),
     uni_students as (select distinct a.student_id from public.affiliations a where a.university_id=any(private.my_university_ids())),
     registrations as (select date_trunc('week',s.created_at)::date as week_start,count(*)::int as n from public.students s join uni_students us on us.student_id=s.id where s.created_at>=date_trunc('week',now())-interval '25 weeks' group by 1),
     reviews as (select date_trunc('week',au.created_at)::date as week_start,count(*)::int as n from public.audits au join public.submissions sub on sub.id=au.submission_id join uni_students us on us.student_id=sub.student_id where au.created_at>=date_trunc('week',now())-interval '25 weeks' group by 1),
     weekly_verified as (select date_trunc('week',ss.updated_at)::date as week_start,count(distinct ss.student_id)::int as n from public.skill_scores ss join uni_students us on us.student_id=ss.student_id where ss.verified and ss.share_ok and not ss.pending_review and ss.updated_at>=date_trunc('week',now())-interval '25 weeks' group by 1)
 select w.week_start,coalesce((select sum(v.n) from weekly_verified v where v.week_start<=w.week_start),0)::int as verified_total,
        coalesce(rv.n,0)::int as reviews,coalesce(reg.n,0)::int as new_registrations
 from weeks w left join reviews rv using(week_start) left join registrations reg using(week_start)
 where private.my_university_ids() <> '{}'::uuid[] or private.is_admin();

create view public.university_demand_v with (security_invoker=false) as
 select sk.id,sk.name as skill_name,
        count(distinct j.id) filter(where j.status='open')::int as jobs_count,
        coalesce((select jsonb_object_agg(rc.reason,rc.total) from (
          select kv.key as reason,sum(kv.value::int) as total
          from public.demand_signals ds cross join lateral jsonb_each_text(ds.reason_counts) kv
          where ds.university_id=any(private.my_university_ids()) and sk.slug=any(ds.skill_slugs)
          group by kv.key) rc),'{}'::jsonb) as reasons,
        max(j.created_at) as last_posted_at
 from public.skills sk
 left join lateral (select distinct job.id,job.status,job.created_at from public.jobs job cross join lateral jsonb_array_elements(coalesce(job.required_skills,'[]'::jsonb)) as req(item) where req.item->>'skill_id'=sk.id::text) j on true
 where private.my_university_ids() <> '{}'::uuid[] or private.is_admin()
 group by sk.id,sk.name;

-- Replace the broad FOR ALL roster policy with operation-specific member-only rules.
drop policy if exists university_roster_objects on storage.objects;
create policy university_roster_objects_select on storage.objects for select to authenticated using(bucket_id='rosters' and (storage.foldername(name))[1]=any(select x::text from unnest(private.my_university_ids()) as ids(x)));
create policy university_roster_objects_insert on storage.objects for insert to authenticated with check(bucket_id='rosters' and (storage.foldername(name))[1]=any(select x::text from unnest(private.my_university_ids()) as ids(x)));
create policy university_roster_objects_update on storage.objects for update to authenticated using(bucket_id='rosters' and (storage.foldername(name))[1]=any(select x::text from unnest(private.my_university_ids()) as ids(x))) with check(bucket_id='rosters' and (storage.foldername(name))[1]=any(select x::text from unnest(private.my_university_ids()) as ids(x)));
create policy university_roster_objects_delete on storage.objects for delete to authenticated using(bucket_id='rosters' and (storage.foldername(name))[1]=any(select x::text from unnest(private.my_university_ids()) as ids(x)));
