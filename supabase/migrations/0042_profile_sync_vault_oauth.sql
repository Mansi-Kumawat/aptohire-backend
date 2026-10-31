-- GitHub source sync token handling and one-time, user-bound OAuth state.
create extension if not exists supabase_vault with schema vault;

alter table public.profile_sources
  add column if not exists last_synced_at timestamptz;

create table private.github_oauth_states (
  state_hash text primary key check (state_hash ~ '^[a-f0-9]{64}$'),
  student_id uuid not null references public.students(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  source_id uuid not null references public.profile_sources(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
revoke all on private.github_oauth_states from public, anon, authenticated;
grant select, insert, delete on private.github_oauth_states to service_role;

create or replace function public.issue_github_oauth_state(
  p_user_id uuid,p_student_id uuid,p_source_id uuid,p_state_hash text
) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare v_expiry timestamptz := now()+interval '10 minutes';
begin
  if p_user_id is null or p_student_id is null or p_source_id is null or p_state_hash is null or p_state_hash !~ '^[a-f0-9]{64}$' then
    raise exception using errcode='22023',message='invalid OAuth state request';
  end if;
  if not exists(select 1 from public.students s where s.id=p_student_id and s.user_id=p_user_id) then
    raise exception using errcode='42501',message='student ownership required';
  end if;
  if not exists(select 1 from public.profile_sources ps where ps.id=p_source_id and ps.student_id=p_student_id and ps.source_type='github' and ps.revoked_at is null) then
    raise exception using errcode='42501',message='active GitHub source required';
  end if;
  delete from private.github_oauth_states where expires_at<=now() or student_id=p_student_id;
  insert into private.github_oauth_states(state_hash,student_id,user_id,source_id,expires_at)
  values(p_state_hash,p_student_id,p_user_id,p_source_id,v_expiry);
  return v_expiry;
end; $$;
revoke all on function public.issue_github_oauth_state(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.issue_github_oauth_state(uuid,uuid,uuid,text) to service_role;

create or replace function public.consume_github_oauth_state(p_state_hash text)
returns table(student_id uuid,user_id uuid,source_id uuid)
language plpgsql security definer set search_path = '' as $$
begin
  if p_state_hash is null or p_state_hash !~ '^[a-f0-9]{64}$' then return; end if;
  return query
    delete from private.github_oauth_states s
    where s.state_hash=p_state_hash and s.expires_at>now()
    returning s.student_id,s.user_id,s.source_id;
end; $$;
revoke all on function public.consume_github_oauth_state(text) from public,anon,authenticated;
grant execute on function public.consume_github_oauth_state(text) to service_role;

create or replace function public.store_profile_source_token(p_source_id uuid,p_student_id uuid,p_token text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_old uuid; v_secret uuid;
begin
  if p_source_id is null or p_student_id is null or p_token is null or length(p_token)<1 or length(p_token)>4096 then
    raise exception using errcode='22023',message='invalid source token';
  end if;
  select ps.token_secret_id into v_old from public.profile_sources ps
    where ps.id=p_source_id and ps.student_id=p_student_id and ps.source_type='github' and ps.revoked_at is null for update;
  if not found then raise exception using errcode='P0002',message='active profile source not found'; end if;
  v_secret := vault.create_secret(p_token,'aptohire-github-'||p_source_id::text,'GitHub OAuth token for one profile source');
  update public.profile_sources set token_secret_id=v_secret,consented_at=coalesce(consented_at,now()) where id=p_source_id;
  if v_old is not null then delete from vault.secrets where id=v_old; end if;
  return v_secret;
end; $$;
revoke all on function public.store_profile_source_token(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.store_profile_source_token(uuid,uuid,text) to service_role;

create or replace function public.read_profile_source_token(p_source_id uuid,p_student_id uuid)
returns text
language plpgsql security definer set search_path = '' as $$
declare v_token text;
begin
  select d.decrypted_secret into v_token
  from public.profile_sources ps join vault.decrypted_secrets d on d.id=ps.token_secret_id
  where ps.id=p_source_id and ps.student_id=p_student_id and ps.source_type='github' and ps.revoked_at is null;
  if v_token is null then raise exception using errcode='P0002',message='active source token not found'; end if;
  return v_token;
end; $$;
revoke all on function public.read_profile_source_token(uuid,uuid) from public,anon,authenticated;
grant execute on function public.read_profile_source_token(uuid,uuid) to service_role;

create or replace function public.revoke_profile_source(p_user_id uuid,p_source_id uuid,p_student_id uuid,p_delete_data boolean default false)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_secret uuid; v_source public.profile_sources%rowtype;
begin
  if not exists(select 1 from public.students s where s.id=p_student_id and s.user_id=p_user_id) then
    raise exception using errcode='42501',message='student ownership required';
  end if;
  select * into v_source from public.profile_sources ps
   where ps.id=p_source_id and ps.student_id=p_student_id for update;
  if not found then raise exception using errcode='P0002',message='profile source not found'; end if;
  v_secret:=v_source.token_secret_id;
  update public.profile_sources set revoked_at=coalesce(revoked_at,now()),token_secret_id=null where id=p_source_id;
  delete from private.github_oauth_states where source_id=p_source_id;
  if v_secret is not null then delete from vault.secrets where id=v_secret; end if;
  if p_delete_data then delete from public.profile_proposals where source_id=p_source_id; end if;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_user_id,'profile_source_revoked','profile_source',p_source_id,jsonb_build_object('deleted_derived_data',coalesce(p_delete_data,false)));
end; $$;
revoke all on function public.revoke_profile_source(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.revoke_profile_source(uuid,uuid,uuid,boolean) to service_role;

comment on table private.github_oauth_states is 'Single-use, short-lived GitHub OAuth state bound to an authenticated student and profile source.';
comment on function public.read_profile_source_token(uuid,uuid) is 'Service-role-only token retrieval for server-side GitHub API calls; never returns a token to a user client.';
