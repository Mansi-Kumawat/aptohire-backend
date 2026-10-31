-- Admin authorization is role + aal2. All prior policies that call private.is_admin() tighten automatically.
create or replace function private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select coalesce(private.app_role()='admin' and auth.jwt()->>'aal'='aal2',false)
$$;

alter table public.universities add column if not exists status_note text;
alter table public.universities add column if not exists reference text unique;
alter table public.organizations add column if not exists status_note text;
alter table public.organizations add column if not exists reference text unique;
alter table public.app_config add column if not exists updated_by uuid references auth.users;
alter table public.audits add column if not exists reviewed_score numeric check(reviewed_score between 0 and 100);

create view public.admin_users_v with (security_invoker=false) as
 select u.id as user_id,
        coalesce(nullif(u.raw_user_meta_data->>'full_name',''),split_part(coalesce(u.email,''),'@',1)) as display_name,
        p.role,u.created_at,u.last_sign_in_at,
        coalesce((select uni.name from public.university_members um join public.universities uni on uni.id=um.university_id where um.user_id=u.id order by uni.name limit 1),
                 (select org.name from public.organization_members om join public.organizations org on org.id=om.organization_id where om.user_id=u.id order by org.name limit 1)) as university_or_org
 from auth.users u left join public.profiles p on p.id=u.id where private.is_admin();

create view public.admin_counts_v with (security_invoker=false) as
 select (select count(*)::int from public.applications a where a.status='received') as pending_approvals,
        (select count(*)::int from public.audits a where a.review_status='pending') as pending_reviews,
        (select count(*)::int from public.tickets t where t.status in ('open','assigned')) as open_tickets,
        (select count(*)::int from public.agent_runs r where r.status='failed' and r.created_at>=now()-interval '24 hours') as failed_runs_24h
 where private.is_admin();

create view public.admin_agent_stats_v with (security_invoker=false) as
 select count(*)::int as runs_24h,
        coalesce(avg((status='failed')::int::numeric),0) as failure_rate,
        percentile_cont(0.5) within group(order by latency_ms) as p50_latency_ms,
        percentile_cont(0.95) within group(order by latency_ms) as p95_latency_ms,
        coalesce(sum(token_estimate) filter(where created_at>=date_trunc('day',now())),0)::bigint as estimated_tokens_today
 from public.agent_runs where created_at>=now()-interval '24 hours' and private.is_admin() group by private.is_admin();

create view public.admin_agreement_v with (security_invoker=false) as
 select a.id as audit_id,a.overall_score as ai_score,a.reviewed_score as human_score,a.review_status as outcome,a.created_at
 from public.audits a where a.reviewed_by is not null and private.is_admin();

create view public.admin_audit_log_v with (security_invoker=false) as
 select l.id,l.actor_id,coalesce(nullif(u.raw_user_meta_data->>'full_name',''),split_part(coalesce(u.email,''),'@',1),'system') as actor_label,
        l.action,l.target_type,l.target_id,l.metadata,l.created_at
 from public.audit_log l left join auth.users u on u.id=l.actor_id where private.is_admin();

create view public.admin_borderline_v with (security_invoker=false) as
 select a.id as audit_id,a.submission_id,a.overall_score,a.review_status,a.created_at
 from public.audits a where a.review_status='pending' and private.is_admin();

create view public.admin_tickets_v with (security_invoker=false) as
 select t.id,t.submission_id,t.student_id,t.status,t.assigned_to,t.created_at,t.decision,
        a.reviewed_by as original_reviewer_id,
        coalesce(nullif(assignee.raw_user_meta_data->>'full_name',''),split_part(coalesce(assignee.email,''),'@',1)) as assignee_name
 from public.tickets t join public.submissions s on s.id=t.submission_id
 left join public.audits a on a.submission_id=s.id
 left join auth.users assignee on assignee.id=t.assigned_to
 where private.is_admin();

revoke all on public.admin_users_v,public.admin_counts_v,public.admin_agent_stats_v,public.admin_agreement_v,public.admin_audit_log_v,public.admin_borderline_v,public.admin_tickets_v from public,anon,authenticated;
grant select on public.admin_users_v,public.admin_counts_v,public.admin_agent_stats_v,public.admin_agreement_v,public.admin_audit_log_v,public.admin_borderline_v,public.admin_tickets_v to authenticated;
comment on view public.admin_agreement_v is 'Admin-only comparison view intentionally excludes identity columns.';
