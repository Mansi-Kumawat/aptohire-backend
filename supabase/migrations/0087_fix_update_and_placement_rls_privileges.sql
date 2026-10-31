-- Narrow SELECT columns required by the organization pipeline UPDATE policy.
-- This does not create a SELECT policy, so the request rows remain unreadable.
grant select (id,organization_id,status,expires_at) on public.access_requests to authenticated;

-- RLS subqueries in the placement policies inspect roster_entries.student_id,
-- a deliberately ungranted identity-link column. Keep that lookup behind a
-- SECURITY DEFINER predicate which reveals only the boolean for the caller's own university.
create or replace function private.university_can_manage_unclaimed_roster_entry(p_roster_entry_id uuid,p_university_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_roster_entry_id is not null
     and p_university_id = any(private.my_university_ids())
     and exists (
       select 1 from public.roster_entries r
        where r.id=p_roster_entry_id
          and r.university_id=p_university_id
          and r.student_id is null
     );
$$;
revoke all on function private.university_can_manage_unclaimed_roster_entry(uuid,uuid) from public,anon,authenticated;
grant execute on function private.university_can_manage_unclaimed_roster_entry(uuid,uuid) to authenticated;

drop policy if exists placement_unclaimed_university_insert on public.placements;
drop policy if exists placement_unclaimed_university_update on public.placements;
create policy placement_unclaimed_university_insert on public.placements for insert to authenticated with check(
  source='university' and student_id is null and roster_entry_id is not null
  and private.university_can_manage_unclaimed_roster_entry(roster_entry_id,university_id)
);
create policy placement_unclaimed_university_update on public.placements for update to authenticated using(
  source='university' and student_id is null and roster_entry_id is not null
  and private.university_can_manage_unclaimed_roster_entry(roster_entry_id,university_id)
) with check(
  source='university' and student_id is null and roster_entry_id is not null
  and private.university_can_manage_unclaimed_roster_entry(roster_entry_id,university_id)
);

-- Ticket eligibility inspects scored submissions; use a narrow boolean helper so the
-- browser policy does not need extra SELECT-column grants on private review fields.
create or replace function private.student_can_open_ticket(p_submission_id uuid,p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_student_id=private.my_student_id()
     and exists (
       select 1 from public.submissions s
        where s.id=p_submission_id
          and s.student_id=p_student_id
          and s.status in ('scored','needs_review')
     );
$$;
revoke all on function private.student_can_open_ticket(uuid,uuid) from public,anon,authenticated;
grant execute on function private.student_can_open_ticket(uuid,uuid) to authenticated;
drop policy if exists ticket_owner_insert on public.tickets;
create policy ticket_owner_insert on public.tickets for insert to authenticated with check(
  private.student_can_open_ticket(submission_id,student_id)
);
