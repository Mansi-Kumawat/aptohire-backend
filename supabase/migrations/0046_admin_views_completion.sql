-- Complete admin view semantics without changing established view names.
-- Access is gated in the view predicate by the aal2-aware private.is_admin().

create or replace view public.admin_agent_stats_v with (security_invoker=false) as
select
  count(*)::int as runs_24h,
  coalesce(avg((r.status='failed')::int::numeric),0) as failure_rate,
  coalesce(percentile_cont(0.5) within group(order by r.latency_ms),0::double precision) as p50_latency_ms,
  coalesce(percentile_cont(0.95) within group(order by r.latency_ms),0::double precision) as p95_latency_ms,
  coalesce((select sum(t.token_estimate)::bigint from public.agent_runs t
            where t.created_at>=date_trunc('day',now())),0)::bigint as estimated_tokens_today
from public.agent_runs r
where r.created_at>=now()-interval '24 hours'
having private.is_admin();

create or replace view public.admin_agreement_v with (security_invoker=false) as
select a.id as audit_id,
       a.overall_score as ai_score,
       a.reviewed_score as human_score,
       coalesce((select l.metadata->>'decision'
                 from public.audit_log l
                 where l.target_type='audit' and l.target_id=a.id and l.action='admin_audit_reviewed'
                 order by l.created_at desc limit 1),
                case when a.reviewed_score=a.overall_score then 'confirmed' else 'adjusted' end) as outcome,
       a.created_at
from public.audits a
where a.reviewed_by is not null and a.reviewed_score is not null and private.is_admin();

create or replace view public.admin_borderline_v with (security_invoker=false) as
select a.id as audit_id,a.submission_id,a.overall_score,a.review_status,a.created_at
from public.audits a
cross join lateral (
  select (c.value->>0)::numeric as low_score,(c.value->>1)::numeric as high_score
  from public.app_config c where c.key='BORDERLINE'
) bounds
where a.review_status='pending'
  and a.overall_score between bounds.low_score and bounds.high_score
  and private.is_admin();

create or replace view public.admin_app_config_v with (security_invoker=false) as
select c.key,c.value,c.updated_by,c.updated_at
from public.app_config c
where c.key in ('AGENT_MODE','PASS_MARK','BORDERLINE','REQUIRE_VIDEO','VIDEO_MAX_MB',
                'VIDEO_MAX_SECONDS','AI_DAILY_CAP_PER_USER','AI_KILL_SWITCH','SCORE_BLEND_N','GRANT_DURATIONS')
  and private.is_admin();

revoke all on public.admin_agent_stats_v,public.admin_agreement_v,public.admin_borderline_v,public.admin_app_config_v from public,anon,authenticated;
grant select on public.admin_agent_stats_v,public.admin_agreement_v,public.admin_borderline_v,public.admin_app_config_v to authenticated;
comment on view public.admin_agent_stats_v is 'Aal2 admin-only aggregate; returns one zero-valued row when there are no recent runs and no rows for unauthorized callers.';
comment on view public.admin_agreement_v is 'Aal2 admin-only human-vs-agent comparison; includes only completed human reviews and excludes all identity columns.';
comment on view public.admin_borderline_v is 'Aal2 admin-only pending audit queue restricted to the configured BORDERLINE score interval.';
comment on view public.admin_app_config_v is 'Aal2 admin-only allowlisted config with last editor and timestamp; excludes unapproved keys.';
