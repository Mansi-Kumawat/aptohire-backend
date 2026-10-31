-- Treat any dotted hostname (including less common/new TLDs) as contact-like for headline auto-approval.
-- Existing proposals and student text are not rewritten; this affects future auto-application only.
create or replace function private.apply_auto_approved_profile_changes(p_student_id uuid,p_changes jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_item jsonb;
  v_skill_ids uuid[];
  v_slug_count integer;
  v_resolved_count integer;
begin
  if p_student_id is null or jsonb_typeof(p_changes) is distinct from 'array' then
    return false;
  end if;
  if jsonb_array_length(p_changes)=0 or jsonb_array_length(p_changes)>30
     or not exists(select 1 from public.students s where s.id=p_student_id) then
    return false;
  end if;

  -- Validate the entire batch before applying any row, so partial application is impossible.
  for v_item in select value from jsonb_array_elements(p_changes) as changes(value) loop
    if v_item->>'field'='headline' then
      if jsonb_typeof(v_item->'value') is distinct from 'string'
         or length(btrim(v_item->>'value')) not between 1 and 160
         or (v_item->>'value') ~* '([a-z0-9._%+-]+@[a-z0-9.-]+[.][a-z]{2,}|https?://|www[.]|[+]?[0-9][0-9[:space:]().-]{8,}[0-9]|(^|[^a-z0-9_])@[a-z0-9_.-]{2,}|(^|[^a-z0-9-])([a-z0-9-]+[.])+[a-z]{2,}(/[^[:space:]]*)?([^a-z0-9-]|$))' then
        return false;
      end if;
    elsif v_item->>'field'='skills_interest' then
      if jsonb_typeof(v_item->'value') is distinct from 'array' then return false; end if;
      if jsonb_array_length(v_item->'value')>25 then return false; end if;
      if exists(select 1 from jsonb_array_elements(v_item->'value') as values(item)
                where jsonb_typeof(values.item) is distinct from 'string'
                   or length(btrim(values.item#>>'{}')) not between 1 and 80) then
        return false;
      end if;
      select count(*),count(distinct item#>>'{}') into v_slug_count,v_resolved_count
        from jsonb_array_elements(v_item->'value') as values(item);
      if v_slug_count<>v_resolved_count then return false; end if;
      select count(*) into v_resolved_count
        from public.skills sk
       where sk.slug in (select jsonb_array_elements_text(v_item->'value'));
      if v_resolved_count<>v_slug_count then return false; end if;
    else
      -- Experience, education, links, and project-candidate values have no safe mapped columns yet.
      return false;
    end if;
  end loop;

  for v_item in select value from jsonb_array_elements(p_changes) as changes(value) loop
    if v_item->>'field'='headline' then
      update public.students set headline=btrim(v_item->>'value'),updated_at=now()
       where id=p_student_id;
    elsif v_item->>'field'='skills_interest' then
      select coalesce(array_agg(sk.id order by sk.slug),'{}'::uuid[]) into v_skill_ids
        from public.skills sk
       where sk.slug in (select jsonb_array_elements_text(v_item->'value'));
      if v_item->>'action'='add' then
        update public.students st
           set target_skill_ids=(select coalesce(array_agg(distinct ids.skill_id order by ids.skill_id),'{}'::uuid[])
                                  from unnest(coalesce(st.target_skill_ids,'{}'::uuid[])||v_skill_ids) ids(skill_id)),
               updated_at=now()
         where st.id=p_student_id;
      else
        update public.students set target_skill_ids=v_skill_ids,updated_at=now()
         where id=p_student_id;
      end if;
    end if;
  end loop;
  return true;
end;
$function$;
revoke all on function private.apply_auto_approved_profile_changes(uuid,jsonb) from public,anon,authenticated,service_role;
