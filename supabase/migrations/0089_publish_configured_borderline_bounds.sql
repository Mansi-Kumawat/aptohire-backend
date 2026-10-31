-- Preserve the combined BORDERLINE admin setting while exposing the frozen
-- public_config keys consumed by portals. The range remains sourced from one value.
create or replace view public.public_config with (security_invoker=false) as
  select c.key,c.value
  from public.app_config c
  where c.key in ('PASS_MARK','REQUIRE_VIDEO','VIDEO_MAX_MB','VIDEO_MAX_SECONDS','AI_KILL_SWITCH','AI_DAILY_CAP_PER_USER')
  union all
  select 'BORDERLINE_LOW'::text,c.value->0
  from public.app_config c where c.key='BORDERLINE' and jsonb_typeof(c.value)='array' and jsonb_array_length(c.value)=2
  union all
  select 'BORDERLINE_HIGH'::text,c.value->1
  from public.app_config c where c.key='BORDERLINE' and jsonb_typeof(c.value)='array' and jsonb_array_length(c.value)=2;

comment on view public.public_config is
  'Authenticated public config allowlist; borderline low/high are derived from the single admin-managed BORDERLINE array.';
