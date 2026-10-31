-- Trusted row-transition producers for missing notification kinds.
-- Payloads deliberately omit applicant contact data, proposed profile content,
-- student names/emails, and provider/user-facing error text.

create or replace function private.notify_application_received()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_transition boolean;
begin
  if tg_op='INSERT' then v_transition:=true; else v_transition:=old.status is distinct from new.status; end if;
  if new.status='received' and v_transition then
    insert into public.notifications(user_id,kind,payload)
    select p.id,'application_received',jsonb_build_object(
      'application_id',new.id,
      'reference',new.reference,
      'application_type',new.type
    )
    from public.profiles p
    where p.role='admin';
  end if;
  return new;
end;
$$;
revoke all on function private.notify_application_received() from public,anon,authenticated;
create trigger applications_notify_received_insert
  after insert on public.applications
  for each row execute function private.notify_application_received();
create trigger applications_notify_received_update
  after update of status on public.applications
  for each row execute function private.notify_application_received();
comment on function private.notify_application_received() is
  'Notifies admins when an application enters received; payload excludes applicant identity and contact details.';

create or replace function private.notify_agent_run_failed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_transition boolean;
begin
  if tg_op='INSERT' then v_transition:=true; else v_transition:=old.status is distinct from new.status; end if;
  if new.status='failed' and v_transition then
    insert into public.notifications(user_id,kind,payload)
    select p.id,'run_failed',jsonb_build_object(
      'run_id',new.id,
      'stage',new.stage,
      'status','failed'
    )
    from public.profiles p
    where p.role='admin';
  end if;
  return new;
end;
$$;
revoke all on function private.notify_agent_run_failed() from public,anon,authenticated;
create trigger agent_runs_notify_failed_insert
  after insert on public.agent_runs
  for each row execute function private.notify_agent_run_failed();
create trigger agent_runs_notify_failed_update
  after update of status on public.agent_runs
  for each row execute function private.notify_agent_run_failed();
comment on function private.notify_agent_run_failed() is
  'Notifies admins on an agent-run transition to failed; omits potentially sensitive error text and student identity.';

create or replace function private.notify_student_registered()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_transition boolean;
begin
  if tg_op='INSERT' then v_transition:=true;
  else v_transition:=(not old.is_current or old.verification='unverified'::public.affiliation_verification);
  end if;
  if new.is_current
     and new.university_id is not null
     and new.verification in ('roster'::public.affiliation_verification,'student_id'::public.affiliation_verification)
     and exists(select 1 from public.students s where s.id=new.student_id and s.user_id is not null)
     and v_transition then
    insert into public.notifications(user_id,kind,payload)
    select um.user_id,'student_registered',jsonb_build_object(
      'university_id',new.university_id,
      'affiliation_id',new.id,
      'student_id',new.student_id
    )
    from public.university_members um
    where um.university_id=new.university_id;
  end if;
  return new;
end;
$$;
revoke all on function private.notify_student_registered() from public,anon,authenticated;
create trigger affiliations_notify_registered_insert
  after insert on public.affiliations
  for each row execute function private.notify_student_registered();
create trigger affiliations_notify_registered_update
  after update of is_current,verification on public.affiliations
  for each row execute function private.notify_student_registered();
comment on function private.notify_student_registered() is
  'Notifies own-university members when a linked current verified affiliation is created or becomes verified; no student name or contact is included.';

create or replace function private.notify_student_linked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_transition boolean;
begin
  if tg_op='INSERT' then v_transition:=true; else v_transition:=old.user_id is null; end if;
  if new.user_id is not null and v_transition then
    insert into public.notifications(user_id,kind,payload)
    select um.user_id,'student_registered',jsonb_build_object(
      'university_id',a.university_id,
      'affiliation_id',a.id,
      'student_id',a.student_id
    )
    from public.affiliations a
    join public.university_members um on um.university_id=a.university_id
    where a.student_id=new.id and a.is_current
      and a.verification in ('roster'::public.affiliation_verification,'student_id'::public.affiliation_verification)
      and a.university_id is not null;
  end if;
  return new;
end;
$$;
revoke all on function private.notify_student_linked() from public,anon,authenticated;
create trigger students_notify_registered_insert
  after insert on public.students
  for each row execute function private.notify_student_linked();
create trigger students_notify_registered_update
  after update of user_id on public.students
  for each row execute function private.notify_student_linked();
comment on function private.notify_student_linked() is
  'Complements affiliation registration notifications when a previously unclaimed student profile is linked; payload omits names and contact details.';

create or replace function private.notify_demand_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_transition boolean;
begin
  if tg_op='INSERT' then v_transition:=true;
  else v_transition:=(old.reason_counts is distinct from new.reason_counts or old.skill_slugs is distinct from new.skill_slugs);
  end if;
  if new.university_id is not null and v_transition then
    insert into public.notifications(user_id,kind,payload)
    select um.user_id,'demand_alert',jsonb_build_object(
      'university_id',new.university_id,
      'job_id',new.job_id,
      'reason_counts',new.reason_counts,
      'skill_slugs',new.skill_slugs
    )
    from public.university_members um
    where um.university_id=new.university_id;
  end if;
  return new;
end;
$$;
revoke all on function private.notify_demand_alert() from public,anon,authenticated;
create trigger demand_signals_notify_insert
  after insert on public.demand_signals
  for each row execute function private.notify_demand_alert();
create trigger demand_signals_notify_update
  after update of reason_counts,skill_slugs on public.demand_signals
  for each row execute function private.notify_demand_alert();
comment on function private.notify_demand_alert() is
  'Notifies only the affected university members with aggregate reason counts and skill slugs; no student-level fields are included.';

create or replace function private.notify_audit_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_user_id uuid;
  v_transition boolean;
  v_initial_completion boolean := false;
begin
  if tg_op='INSERT' then v_transition:=true;
  else
    v_transition:=old.review_status is distinct from new.review_status;
    v_initial_completion:=(old.review_status='unreviewed' and new.review_status='complete');
  end if;
  if new.review_status='pending' and v_transition then
    insert into public.notifications(user_id,kind,payload)
    select p.id,'review_needed',jsonb_build_object('audit_id',new.id,'submission_id',new.submission_id)
    from public.profiles p where p.role='admin';
    select st.user_id into v_student_user_id
    from public.submissions s join public.students st on st.id=s.student_id
    where s.id=new.submission_id;
    if v_student_user_id is not null then
      insert into public.notifications(user_id,kind,payload)
      values(v_student_user_id,'review_needed',jsonb_build_object('audit_id',new.id,'submission_id',new.submission_id));
    end if;
  elsif v_initial_completion then
    select st.user_id into v_student_user_id
    from public.submissions s join public.students st on st.id=s.student_id
    where s.id=new.submission_id;
    if v_student_user_id is not null then
      insert into public.notifications(user_id,kind,payload)
      values(v_student_user_id,'audit_ready',jsonb_build_object('audit_id',new.id,'submission_id',new.submission_id));
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.notify_audit_state() from public,anon,authenticated;
create trigger audits_notify_insert
  after insert on public.audits
  for each row execute function private.notify_audit_state();
create trigger audits_notify_review_status
  after update of review_status on public.audits
  for each row execute function private.notify_audit_state();
comment on function private.notify_audit_state() is
  'Notifies admins and the owning student when scoring needs review, and notifies the student when initial scoring becomes ready; payloads contain ids only.';

create or replace function private.notify_source_proposal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_transition boolean;
begin
  if tg_op='INSERT' then v_transition:=true; else v_transition:=old.state is distinct from new.state; end if;
  if new.state='pending' and v_transition then
    select s.user_id into v_user_id from public.students s where s.id=new.student_id;
    if v_user_id is not null then
      insert into public.notifications(user_id,kind,payload)
      values(v_user_id,'source_proposals',jsonb_build_object('proposal_id',new.id,'source_id',new.source_id));
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.notify_source_proposal() from public,anon,authenticated;
create trigger profile_proposals_notify_insert
  after insert on public.profile_proposals
  for each row execute function private.notify_source_proposal();
create trigger profile_proposals_notify_state
  after update of state on public.profile_proposals
  for each row execute function private.notify_source_proposal();
comment on function private.notify_source_proposal() is
  'Notifies the owning student of a pending source proposal without exposing proposed profile changes in the notification payload.';
