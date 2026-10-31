-- Generalized agent observability keeps provider provenance and keyed input hashes, never raw prompts.
alter table public.agent_runs add column kind text not null default 'audit' check(kind in ('audit','assign','match_reasons','jd_extract','profile','embed'));
alter table public.agent_runs add column provider text;
alter table public.agent_runs add column model text;
alter table public.agent_runs add column prompt_version text;
alter table public.agent_runs add column input_hash text;
alter table public.agent_runs add column started_at timestamptz;
alter table public.agent_runs add column finished_at timestamptz;
alter table public.agent_runs add constraint agent_runs_provider_allowed check(provider is null or provider in ('mock','gemini','groq','openrouter','n8n'));
alter table public.agent_runs add constraint agent_runs_model_length check(model is null or length(model) between 1 and 160);
alter table public.agent_runs add constraint agent_runs_prompt_version_length check(prompt_version is null or length(prompt_version) between 1 and 80);
alter table public.agent_runs add constraint agent_runs_input_hash_format check(input_hash is null or input_hash ~ '^[a-f0-9]{64}$');

-- Short-lived cache stores validated provider output and HMAC input hashes only; raw prompts are never retained.
create table private.agent_response_cache(
  kind text not null check(kind in ('audit','assign','match_reasons','jd_extract','profile','embed')),
  input_hash text not null check(input_hash ~ '^[a-f0-9]{64}$'),
  prompt_version text not null check(length(prompt_version) between 1 and 80),
  output jsonb not null,
  provider text not null check(provider in ('mock','gemini','groq','openrouter','n8n')),
  model text not null check(length(model) between 1 and 160),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '24 hours',
  primary key(kind,input_hash,prompt_version),
  check(pg_catalog.pg_column_size(output)<=65536)
);
alter table private.agent_response_cache enable row level security;
revoke all on private.agent_response_cache from public,anon,authenticated;
revoke all on private.agent_response_cache from service_role;

create or replace function public.read_agent_response_cache(p_kind text,p_input_hash text,p_prompt_version text)
returns table(output jsonb,provider text,model text,created_at timestamptz)
language sql
security definer
set search_path = ''
as $$
  select c.output,c.provider,c.model,c.created_at
  from private.agent_response_cache c
  where c.kind=p_kind and c.input_hash=p_input_hash and c.prompt_version=p_prompt_version and c.expires_at>now()
$$;
revoke all on function public.read_agent_response_cache(text,text,text) from public,anon,authenticated;
grant execute on function public.read_agent_response_cache(text,text,text) to service_role;

create or replace function public.store_agent_response_cache(p_kind text,p_input_hash text,p_prompt_version text,p_output jsonb,p_provider text,p_model text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare v_created timestamptz;
begin
  if p_kind is null or p_kind not in ('audit','assign','match_reasons','jd_extract','profile','embed')
    or p_input_hash is null or p_input_hash !~ '^[a-f0-9]{64}$'
    or p_prompt_version is null or length(p_prompt_version) not between 1 and 80
    or p_provider is null or p_provider not in ('mock','gemini','groq','openrouter','n8n')
    or p_model is null or length(p_model) not between 1 and 160
    or p_output is null or pg_catalog.pg_column_size(p_output)>65536 then
    raise exception using errcode='22023',message='invalid cache entry';
  end if;
  insert into private.agent_response_cache(kind,input_hash,prompt_version,output,provider,model,created_at,expires_at)
  values(p_kind,p_input_hash,p_prompt_version,p_output,p_provider,p_model,now(),now()+interval '24 hours')
  on conflict(kind,input_hash,prompt_version) do update set output=excluded.output,provider=excluded.provider,model=excluded.model,created_at=now(),expires_at=now()+interval '24 hours'
  returning created_at into v_created;
  return v_created;
end;
$$;
revoke all on function public.store_agent_response_cache(text,text,text,jsonb,text,text) from public,anon,authenticated;
grant execute on function public.store_agent_response_cache(text,text,text,jsonb,text,text) to service_role;

select cron.schedule('aptohire-agent-cache-purge-hourly','35 * * * *',$cron$delete from private.agent_response_cache where expires_at<=now()$cron$);
comment on table private.agent_response_cache is 'Service-only 24-hour validated-output cache. Stores HMAC input hashes and output only; never raw prompts.';
