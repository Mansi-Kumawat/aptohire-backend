-- Serialize sync proposal persistence with source revocation. A sync that started
-- before revoke cannot insert a proposal after revocation has committed.
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
begin
  if p_student_id is null or p_source_id is null or p_source_type is null or p_source_type not in ('github','linkedin_export') or
     p_changes is null or jsonb_typeof(p_changes) is distinct from 'array' then
    raise exception using errcode='22023', message='invalid profile proposal sync';
  end if;
  if jsonb_array_length(p_changes) > 30 then
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
   where ps.id=p_source_id and ps.student_id=p_student_id and ps.source_type=p_source_type and ps.revoked_at is null
   for update;
  if not found then raise exception using errcode='P0002', message='active profile source not found'; end if;

  if jsonb_array_length(p_changes) > 0 then
    insert into public.profile_proposals(student_id,source_id,changes,state)
    values(p_student_id,p_source_id,p_changes,'pending')
    returning id into v_proposal_id;
  end if;
  update public.profile_sources set last_synced_at=now() where id=p_source_id;
  return v_proposal_id;
end;
$function$;

revoke all on function public.persist_profile_proposal(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.persist_profile_proposal(uuid,uuid,text,jsonb) to service_role;
comment on function public.persist_profile_proposal(uuid,uuid,text,jsonb) is
  'Service-only atomic sync receipt: locks and verifies an active consented profile source before inserting proposals and updating last_synced_at; serialized against revoke_profile_source.';
