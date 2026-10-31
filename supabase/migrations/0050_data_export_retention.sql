-- List only stale, correctly shaped export objects; Edge cleanup deletes through Storage API.
create or replace function public.expired_data_export_object_paths(p_limit integer default 500)
returns table(object_path text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit<1 or p_limit>1000 then
    raise exception using errcode='22023',message='invalid export retention limit';
  end if;
  return query
    select o.name
    from storage.objects o
    where o.bucket_id='data-exports'
      and o.created_at<=now()-interval '30 days'
      and o.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/exports/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]json$'
    order by o.created_at asc,o.name asc
    limit p_limit;
end;
$$;
revoke all on function public.expired_data_export_object_paths(integer) from public,anon,authenticated;
grant execute on function public.expired_data_export_object_paths(integer) to service_role;
comment on function public.expired_data_export_object_paths(integer) is 'Service-role-only listing of correctly shaped data-export objects older than 30 days. Deletion must use Supabase Storage API.';

create or replace function public.complete_data_export_retention_cleanup(p_removed integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_removed is null or p_removed<0 or p_removed>1000 then
    raise exception using errcode='22023',message='invalid export cleanup count';
  end if;
  if p_removed>0 then
    insert into public.audit_log(actor_id,action,target_type,metadata)
    values(null,'data_export_retention_cleanup','system',jsonb_build_object('removed_count',p_removed,'retention_days',30));
  end if;
  return p_removed;
end;
$$;
revoke all on function public.complete_data_export_retention_cleanup(integer) from public,anon,authenticated;
grant execute on function public.complete_data_export_retention_cleanup(integer) to service_role;
comment on function public.complete_data_export_retention_cleanup(integer) is 'Service-role-only aggregate audit for data-export Storage API cleanup; records no paths or identities.';
