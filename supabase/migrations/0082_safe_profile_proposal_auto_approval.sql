-- Users may change only their own active source's auto-approval preference.
revoke update on public.profile_sources from authenticated;
grant update(auto_approve) on public.profile_sources to authenticated;
create policy profile_sources_self_auto_approve
  on public.profile_sources for update to authenticated
  using (student_id=private.my_student_id() and revoked_at is null)
  with check (student_id=private.my_student_id() and revoked_at is null);

-- Auto-apply only profile fields with a deterministic, bounded mapping to existing student columns.
-- Unsupported or unsafe proposals remain pending for manual handling; verified scores are never touched.
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
         or (v_item->>'value') ~* '([a-z0-9._%+-]+@[a-z0-9.-]+[.][a-z]{2,}|https?://|www[.]|[+]?[0-9][0-9[:space:]().-]{8,}[0-9])' then
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
comment on function private.apply_auto_approved_profile_changes(uuid,jsonb) is
  'Service-owner helper for bounded, consented profile-source auto-approval; applies only safe headline/skills-interest fields and never score data.';

create or replace function public.persist_profile_proposal(
  p_student_id uuid,
  p_source_id uuid,
  p_source_type text,
  p_changes jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_source public.profile_sources%rowtype;
  v_proposal_id uuid;
  v_state text := 'pending';
begin
  if p_student_id is null or p_source_id is null or p_source_type is null
     or p_source_type not in ('github','linkedin_export')
     or p_changes is null or jsonb_typeof(p_changes) is distinct from 'array' then
    raise exception using errcode='22023', message='invalid profile proposal sync';
  end if;
  if jsonb_array_length(p_changes)>30 then
    raise exception using errcode='22023', message='too many profile proposal items';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_changes) as items(item)
     where jsonb_typeof(items.item) is distinct from 'object'
        or coalesce(items.item->>'field','') not in ('headline','skills_interest','experience','education','links','project_candidate')
        or coalesce(items.item->>'action','') not in ('add','update')
        or not (items.item ? 'value')
        or jsonb_typeof(items.item->'evidence') is distinct from 'string'
        or length(items.item->>'evidence') not between 1 and 500
  ) then
    raise exception using errcode='22023', message='invalid profile proposal item';
  end if;

  select ps.* into v_source from public.profile_sources ps
   where ps.id=p_source_id and ps.student_id=p_student_id
     and ps.source_type=p_source_type and ps.revoked_at is null
     and ps.consented_at is not null
   for update;
  if not found then raise exception using errcode='P0002', message='active consented profile source not found'; end if;

  if v_source.auto_approve and jsonb_array_length(p_changes)>0
     and private.apply_auto_approved_profile_changes(p_student_id,p_changes) then
    v_state := 'approved';
  end if;
  if jsonb_array_length(p_changes)>0 then
    insert into public.profile_proposals(student_id,source_id,changes,state)
    values(p_student_id,p_source_id,p_changes,v_state)
    returning id into v_proposal_id;
  end if;
  update public.profile_sources set last_synced_at=now() where id=p_source_id;
  return v_proposal_id;
end;
$function$;
revoke all on function public.persist_profile_proposal(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.persist_profile_proposal(uuid,uuid,text,jsonb) to service_role;
comment on function public.persist_profile_proposal(uuid,uuid,text,jsonb) is
  'Service-only atomic profile sync: locks the active consented source; only user-enabled, bounded headline/skills-interest changes auto-apply. Unsupported changes remain pending.';
