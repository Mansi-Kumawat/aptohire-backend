-- Retention cleanup deletes raw media only through the Storage API. SQL only selects
-- expired object names and clears references after the API confirms removal.
-- Supabase may preinstall pg_net in a schema other than `net`. Do not try to
-- relocate an existing extension; the dispatcher resolves its installed schema below.
create extension if not exists pg_net;

create or replace function public.expired_video_object_paths(p_limit integer default 500)
returns table(object_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit not between 1 and 1000 then
    raise exception using errcode='22023', message='limit must be from 1 to 1000';
  end if;
  return query
    select o.name::text
    from storage.objects o
    where o.bucket_id='videos' and o.created_at < now()-interval '90 days'
    order by o.created_at,o.name
    limit p_limit;
end;
$$;
revoke all on function public.expired_video_object_paths(integer) from public,anon,authenticated;
grant execute on function public.expired_video_object_paths(integer) to service_role;

create or replace function public.complete_video_retention_cleanup(p_paths text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  if p_paths is null or cardinality(p_paths)>1000 or exists(select 1 from unnest(p_paths) as u(path) where u.path is null or u.path='') then
    raise exception using errcode='22023', message='invalid cleanup path batch';
  end if;
  update public.submissions s
     set video_path=null,video_url=null,video_bytes=null,updated_at=now()
   where s.video_path=any(p_paths);
  get diagnostics v_count=row_count;
  insert into public.audit_log(actor_id,action,target_type,metadata)
  values(null,'raw_video_retention_cleanup','storage',jsonb_build_object('object_count',cardinality(p_paths),'submission_reference_count',v_count));
  return v_count;
end;
$$;
revoke all on function public.complete_video_retention_cleanup(text[]) from public,anon,authenticated;
grant execute on function public.complete_video_retention_cleanup(text[]) to service_role;

create or replace function private.invoke_retention_cleanup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_url text; v_secret text; v_extension_schema text;
begin
  select d.decrypted_secret into v_url from vault.decrypted_secrets d where d.name='aptohire_functions_url' limit 1;
  select d.decrypted_secret into v_secret from vault.decrypted_secrets d where d.name='aptohire_retention_secret' limit 1;
  -- No Vault config means intentionally dormant: local dev can invoke the Edge Function manually.
  if nullif(v_url,'') is null or nullif(v_secret,'') is null then return; end if;
  select n.nspname into v_extension_schema
    from pg_catalog.pg_extension e
    join pg_catalog.pg_namespace n on n.oid=e.extnamespace
   where e.extname='pg_net';
  if v_extension_schema is null then
    raise exception using errcode='55000', message='pg_net extension is unavailable';
  end if;
  execute format('select %I.http_post(url := $1, headers := $2, body := $3)',v_extension_schema)
    using rtrim(v_url,'/') || '/functions/v1/retention-cleanup',
          jsonb_build_object('content-type','application/json','x-retention-secret',v_secret),
          '{}'::jsonb;
end;
$$;
revoke all on function private.invoke_retention_cleanup() from public,anon,authenticated;

-- Keep-alive writes a successful pg_cron job run record without PII or user-facing data.
select cron.schedule('aptohire-keep-alive-daily','0 9 * * *',$cron$select now();$cron$);
select cron.schedule('aptohire-raw-video-retention-daily','15 4 * * *',$cron$select private.invoke_retention_cleanup();$cron$);

comment on function public.expired_video_object_paths(integer) is 'Service-role-only listing of video objects older than 90 days; never deletes storage rows directly.';
comment on function public.complete_video_retention_cleanup(text[]) is 'Service-role-only reference cleanup called only after Storage API removal succeeds; transcript, scores and evidence pointers are retained.';
comment on function private.invoke_retention_cleanup() is 'Vault-backed pg_cron dispatch; dormant until local/operator config sets the function URL and dedicated retention secret.';
