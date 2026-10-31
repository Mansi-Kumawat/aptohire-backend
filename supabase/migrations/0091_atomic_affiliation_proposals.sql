-- At most one open proposal per student/university. Keep the most recently refreshed
-- proposal if prior imports/registration requests created duplicate pending rows.
with ranked as (
  select id,row_number() over(partition by student_id,university_id order by created_at desc,id desc) as rn
  from public.affiliation_proposals where state='pending'
)
delete from public.notifications n using (select id from ranked where rn>1) d
 where n.kind='affiliation_proposal' and n.payload->>'proposal_id'=d.id::text;
with ranked as (
  select id,row_number() over(partition by student_id,university_id order by created_at desc,id desc) as rn
  from public.affiliation_proposals where state='pending'
)
delete from public.affiliation_proposals ap using (select id from ranked where rn>1) d where ap.id=d.id;
with ranked_notifications as (
  select n.id,row_number() over(partition by n.user_id,n.payload->>'proposal_id'
    order by (n.read_at is null) desc,n.created_at asc,n.id) as rn
  from public.notifications n where n.kind='affiliation_proposal' and n.payload ? 'proposal_id'
)
delete from public.notifications n using ranked_notifications r where n.id=r.id and r.rn>1;
create unique index affiliation_proposals_one_pending
  on public.affiliation_proposals(student_id,university_id) where state='pending';

create or replace function public.ensure_affiliation_proposal(
  p_student_id uuid,
  p_actor_id uuid,
  p_university_id uuid,
  p_roster_entry_id uuid,
  p_program_level text,
  p_status public.life_status,
  p_year integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_university_name text;
  v_roster_student_id uuid;
  v_current_affiliation_id uuid;
  v_proposal_id uuid;
begin
  if p_student_id is null or p_actor_id is null or p_university_id is null or p_roster_entry_id is null then
    raise exception using errcode='22023',message='proposal identity and roster row are required';
  end if;
  select s.user_id into v_user_id from public.students s where s.id=p_student_id;
  if not found or v_user_id is distinct from p_actor_id then
    raise exception using errcode='42501',message='student identity mismatch';
  end if;
  -- Match the established approval/import order: university -> roster row -> advisory lock.
  select u.name into v_university_name from public.universities u where u.id=p_university_id and u.status='approved' for update;
  if not found then raise exception using errcode='P0002',message='university is not approved'; end if;
  select r.student_id into v_roster_student_id from public.roster_entries r
   where r.id=p_roster_entry_id and r.university_id=p_university_id for update;
  if not found then raise exception using errcode='P0002',message='roster row not found'; end if;
  if v_roster_student_id is not null and v_roster_student_id<>p_student_id then
    raise exception using errcode='23505',message='roster row belongs to another student';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_student_id::text||':'||p_university_id::text,0));
  select a.id into v_current_affiliation_id from public.affiliations a
   where a.student_id=p_student_id and a.is_current and a.university_id is distinct from p_university_id for update;
  if not found then raise exception using errcode='40001',message='proposal is no longer needed'; end if;
  -- Do not lock an existing proposal here: confirm_affiliation locks proposal then roster.
  -- The advisory lock plus partial unique index serialize proposal insertion without inversion.
  select ap.id into v_proposal_id from public.affiliation_proposals ap
   where ap.student_id=p_student_id and ap.university_id=p_university_id and ap.state='pending';
  if not found then
    insert into public.affiliation_proposals(student_id,university_id,roster_entry_id,program_level,status,year,state)
    values(p_student_id,p_university_id,p_roster_entry_id,p_program_level,coalesce(p_status,'student'::public.life_status),p_year,'pending')
    returning id into v_proposal_id;
  end if;
  insert into public.notifications(user_id,kind,payload)
  select v_user_id,'affiliation_proposal',jsonb_build_object('proposal_id',v_proposal_id,'university_name',v_university_name)
  where not exists(select 1 from public.notifications n where n.user_id=v_user_id and n.kind='affiliation_proposal'
    and n.payload->>'proposal_id'=v_proposal_id::text);
  return v_proposal_id;
end;
$$;
revoke all on function public.ensure_affiliation_proposal(uuid,uuid,uuid,uuid,text,public.life_status,integer) from public,anon,authenticated;
grant execute on function public.ensure_affiliation_proposal(uuid,uuid,uuid,uuid,text,public.life_status,integer) to service_role;
comment on function public.ensure_affiliation_proposal(uuid,uuid,uuid,uuid,text,public.life_status,integer) is
  'Idempotently reuses or creates one pending affiliation proposal per student/university and emits one student notification atomically.';
