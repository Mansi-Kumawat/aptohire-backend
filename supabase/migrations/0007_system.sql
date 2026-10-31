create table public.notifications(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade, kind text not null, payload jsonb not null default '{}', read_at timestamptz, created_at timestamptz not null default now());
create table public.audit_log(id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users, action text not null, target_type text, target_id uuid, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create table public.app_config(key text primary key, value jsonb not null, updated_at timestamptz not null default now());
create table public.applications(id uuid primary key default gen_random_uuid(), reference text unique not null, type text not null check(type in ('university','organization')), subject_id uuid, contact_name text not null, contact_role text, contact_email extensions.citext not null, contact_phone text, payload jsonb not null default '{}', status public.application_status not null default 'received', claimed_user_id uuid references auth.users, created_at timestamptz not null default now());
create table public.placements(id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students on delete cascade, university_id uuid references public.universities, status text not null default 'unknown' check(status in ('placed','not_placed','unknown')), organization_name_text text, role_text text, source text not null check(source in ('university','student')), updated_by uuid references auth.users, updated_at timestamptz not null default now());
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['notifications','audit_log','app_config','applications','placements'] LOOP EXECUTE format('alter table public.%I enable row level security',t); END LOOP; END $$;
-- Append-only audit trail; writes are reserved for trusted server-side code.
revoke update, delete on public.audit_log from public, anon, authenticated;
revoke all on public.audit_log from public, anon, authenticated;
create policy audit_admin_read on public.audit_log for select to authenticated using(private.is_admin());
grant select on public.audit_log to authenticated;
insert into public.app_config(key,value) values
 ('PASS_MARK','50'),('BORDERLINE','[40,60]'),('AGENT_MODE','"mock"'),('REQUIRE_VIDEO','true'),('VIDEO_MAX_MB','50'),('VIDEO_MAX_SECONDS','190'),('AI_DAILY_CAP_PER_USER','5'),('AI_KILL_SWITCH','false'),('SCORE_BLEND_N','1'),('GRANT_DURATIONS','[7,30,90]') on conflict(key) do nothing;
create table private.rate_limits(bucket text not null,key_hash text not null,window_start timestamptz not null,count int not null,primary key(bucket,key_hash,window_start));
create table private.idempotency_keys(key uuid not null,function text not null,request_hash text not null,response jsonb,created_at timestamptz not null default now(),primary key(key,function));
revoke all on private.rate_limits,private.idempotency_keys from public,anon,authenticated;
