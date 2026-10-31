-- Bound the retention listing and completion RPC to the exact video object shape accepted by the Edge worker.
create or replace function public.expired_video_object_paths(p_limit integer default 500)
returns table(object_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit<1 or p_limit>1000 then
    raise exception using errcode='22023',message='limit must be from 1 to 1000';
  end if;
  return query
    select o.name::text
    from storage.objects o
    where o.bucket_id='videos'
      and o.created_at<now()-interval '90 days'
      and o.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/demo[.](mp4|webm|mov)$'
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
  if p_paths is null or cardinality(p_paths)>1000
     or exists(select 1 from unnest(p_paths) as u(path)
               where u.path is null or u.path !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/demo[.](mp4|webm|mov)$') then
    raise exception using errcode='22023',message='invalid cleanup path batch';
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
