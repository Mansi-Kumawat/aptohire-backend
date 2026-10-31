-- Runtime pgTAP found platform/default anon ACLs and policies surviving the initial
-- application lockdown. Remove broad client access, then grant only the intended
-- university aggregates to authenticated portal users.
revoke all privileges on all tables in schema public,private,storage from anon,public;
revoke all privileges on all sequences in schema public,private,storage from anon,public;

do $$
declare
  v_col record;
  v_policy record;
  v_grantee_sql text;
begin
  -- Table-level REVOKE does not remove column-specific ACL entries.
  for v_col in
    select cp.table_schema,cp.table_name,cp.column_name,cp.privilege_type,cp.grantee
      from information_schema.column_privileges cp
     where cp.table_schema in ('public','private','storage') and cp.grantee in ('anon','PUBLIC')
       and exists (
         select 1 from pg_catalog.pg_class c
         join pg_catalog.pg_namespace n on n.oid=c.relnamespace
         where n.nspname=cp.table_schema
           and c.relname=cp.table_name
           and c.relowner=(select oid from pg_catalog.pg_roles where rolname=current_user)
           and c.relkind in ('r','p','v','m','f')
       )
  loop
    v_grantee_sql := case when v_col.grantee='PUBLIC' then 'PUBLIC' else quote_ident(v_col.grantee) end;
    execute format('revoke %s (%I) on table %I.%I from %s',v_col.privilege_type,v_col.column_name,
      v_col.table_schema,v_col.table_name,v_grantee_sql);
  end loop;

  -- An RLS policy for anon or PUBLIC defeats the intended authenticated-only boundary.
  for v_policy in
    select p.schemaname,p.tablename,p.policyname
      from pg_catalog.pg_policies p
     where p.schemaname in ('public','private','storage')
       and p.roles && array['anon'::name,'public'::name]
       and exists (
         select 1 from pg_catalog.pg_class c
         join pg_catalog.pg_namespace n on n.oid=c.relnamespace
         where n.nspname=p.schemaname and c.relname=p.tablename
           and c.relowner=(select oid from pg_catalog.pg_roles where rolname=current_user)
       )
  loop
    execute format('drop policy %I on %I.%I',v_policy.policyname,v_policy.schemaname,v_policy.tablename);
  end loop;
end
$$;

grant select on public.university_skills_v,public.university_demand_v to authenticated;
