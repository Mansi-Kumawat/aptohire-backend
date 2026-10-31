-- Admin catalog maintenance is available through authenticated Data API only at AAL2.
-- Existing student read policies and grants remain unchanged.
grant insert (family_id,slug,name), update (family_id,slug,name), delete on public.skills to authenticated;
grant select, insert, update, delete on public.skill_edges to authenticated;
grant insert (skill_id,role_text,level,title,brief,active), update (skill_id,role_text,level,title,brief,active), delete on public.project_templates to authenticated;

create policy admin_skills_write on public.skills
  for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy admin_skill_edges_manage on public.skill_edges
  for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy admin_project_templates_manage on public.project_templates
  for all to authenticated using (private.is_admin()) with check (private.is_admin());
create policy admin_project_templates_read_all on public.project_templates
  for select to authenticated using (private.is_admin());

comment on policy admin_skills_write on public.skills is 'AAL2 admins may maintain skill catalog rows; authenticated non-admins retain read-only access.';
comment on policy admin_skill_edges_manage on public.skill_edges is 'AAL2 admins may read and maintain skill prerequisite/relationship edges.';
comment on policy admin_project_templates_manage on public.project_templates is 'AAL2 admins may maintain assignment templates; student access remains active-template read-only.';
comment on policy admin_project_templates_read_all on public.project_templates is 'AAL2 admins may read active and inactive project templates.';

create or replace function private.audit_admin_catalog_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_id uuid;
  v_is_admin boolean := private.is_admin();
  v_is_system boolean := session_user in ('postgres','supabase_admin') or coalesce(auth.role(),'')='service_role';
begin
  if not v_is_admin and not v_is_system then
    raise exception using errcode='42501', message='aal2 admin or trusted system role required';
  end if;
  if tg_table_name='skill_edges' then
    v_target_id := case when tg_op='DELETE' then old.from_skill_id else new.from_skill_id end;
  else
    v_target_id := case when tg_op='DELETE' then old.id else new.id end;
  end if;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(auth.uid(), (case when v_is_admin then 'admin_' else 'system_' end)||tg_table_name||'_'||lower(tg_op), tg_table_name, v_target_id,
         pg_catalog.jsonb_build_object('operation',lower(tg_op)));
  if tg_op='DELETE' then
    return old;
  end if;
  return new;
end;
$$;
revoke all on function private.audit_admin_catalog_change() from public,anon,authenticated;
create trigger skills_admin_change_audit after insert or update or delete on public.skills
  for each row execute function private.audit_admin_catalog_change();
create trigger skill_edges_admin_change_audit after insert or update or delete on public.skill_edges
  for each row execute function private.audit_admin_catalog_change();
create trigger project_templates_admin_change_audit after insert or update or delete on public.project_templates
  for each row execute function private.audit_admin_catalog_change();
comment on function private.audit_admin_catalog_change() is 'Audits AAL2 admin and trusted system skill catalog/template writes with operation/type/id only; no content or PII.';
