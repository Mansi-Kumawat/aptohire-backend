-- Rubric material is read-only: catalog admins may edit template wording but cannot
-- author/replace embedded rubric definitions or change the rubric version of a saved template.
create or replace function private.guard_template_rubric_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op='INSERT' then
    if new.brief ?| array['rubric_preview','rubric','rubric_criteria','rubric_weights'] then
      raise exception using errcode='42501', message='rubric definitions are read-only';
    end if;
    return new;
  end if;

  if (old.brief->'rubric_preview') is distinct from (new.brief->'rubric_preview')
     or (old.brief->'rubric') is distinct from (new.brief->'rubric')
     or (old.brief->'rubric_criteria') is distinct from (new.brief->'rubric_criteria')
     or (old.brief->'rubric_weights') is distinct from (new.brief->'rubric_weights')
     or (old.brief->'rubric_version') is distinct from (new.brief->'rubric_version') then
    raise exception using errcode='42501', message='rubric definitions and versions are read-only';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_template_rubric_fields() from public,anon,authenticated;
create trigger project_templates_rubric_read_only
  before insert or update of brief on public.project_templates
  for each row execute function private.guard_template_rubric_fields();
comment on function private.guard_template_rubric_fields() is
  'Prevents edits to rubric content/version inside project template brief JSON; AAL2 admins may still edit non-rubric template wording.';
