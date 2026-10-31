-- Preserve the original reviewer across later appeal reviews, and restore appealed submissions.
-- TODO(decision): ack claims the ticket for the current admin; an overturned appeal returns to needs_review.
alter table public.tickets add column if not exists original_reviewer_id uuid references auth.users;
-- Keep the internal reviewer id out of student-visible base-table reads.
revoke select on public.tickets from authenticated;
grant select (id,submission_id,student_id,reason,status,assigned_to,decision,created_at,resolved_at) on public.tickets to authenticated;
update public.tickets t set original_reviewer_id=(
  select a.reviewed_by from public.audits a where a.submission_id=t.submission_id and a.reviewed_by is not null order by a.created_at desc limit 1
) where t.original_reviewer_id is null;

create or replace function private.initialize_ticket_review()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_reviewer uuid;
begin
  select a.reviewed_by into v_reviewer from public.audits a
   where a.submission_id=new.submission_id and a.reviewed_by is not null
   order by a.created_at desc limit 1;
  new.original_reviewer_id := coalesce(new.original_reviewer_id,v_reviewer);
  return new;
end;
$$;
revoke all on function private.initialize_ticket_review() from public,anon,authenticated;
create trigger ticket_capture_original_reviewer before insert on public.tickets
for each row execute function private.initialize_ticket_review();

create or replace function private.appeal_submission_on_ticket()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.submissions s set status='appealed',updated_at=now()
   where s.id=new.submission_id and s.student_id=new.student_id and s.status in ('scored','needs_review');
  if not found then raise exception 'ticket submission state changed' using errcode='40001'; end if;
  insert into public.notifications(user_id,kind,payload)
  select p.id,'ticket_opened',jsonb_build_object('ticket_id',new.id,'submission_id',new.submission_id)
   from public.profiles p where p.role='admin';
  return new;
end;
$$;
revoke all on function private.appeal_submission_on_ticket() from public,anon,authenticated;
create trigger ticket_mark_submission_appealed after insert on public.tickets
for each row execute function private.appeal_submission_on_ticket();

create or replace view public.admin_tickets_v with (security_invoker=false) as
 select t.id,t.submission_id,t.student_id,t.status,t.assigned_to,t.created_at,t.decision,
        coalesce(t.original_reviewer_id,a.reviewed_by) as original_reviewer_id,
        coalesce(nullif(assignee.raw_user_meta_data->>'full_name',''),split_part(coalesce(assignee.email,''),'@',1)) as assignee_name
 from public.tickets t join public.submissions s on s.id=t.submission_id
 left join lateral (select au.reviewed_by from public.audits au where au.submission_id=s.id order by au.created_at desc limit 1) a on true
 left join auth.users assignee on assignee.id=t.assigned_to
 where private.is_admin();
comment on view public.admin_tickets_v is 'Admin-only tickets view; original reviewer is preserved across subsequent appeal reviews.';

create or replace function public.admin_decide_ticket(
  p_actor_id uuid,
  p_ticket_id uuid,
  p_action text,
  p_assigned_to uuid default null,
  p_decision text default null,
  p_criterion text default null,
  p_note text default null,
  p_adjusted_scores jsonb default null
)
returns table(ticket_id uuid,status text,decision text)
language plpgsql security definer set search_path = '' as $$
declare
  v_ticket public.tickets%rowtype;
  v_submission public.submissions%rowtype;
  v_student_user_id uuid;
  v_original_reviewer uuid;
  v_audit_id uuid;
  v_pass_mark numeric;
  v_skills jsonb;
  v_note text;
begin
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='admin') then
    raise exception using errcode='42501', message='admin role required';
  end if;
  if p_action is null or p_action not in ('ack','assign','decide') then raise exception using errcode='22023', message='invalid ticket action'; end if;
  if p_criterion is not null and (length(pg_catalog.btrim(p_criterion))=0 or length(p_criterion)>100 or p_criterion !~ '^[A-Za-z0-9 _.-]+$') then
    raise exception using errcode='22023', message='invalid rubric criterion';
  end if;

  select t.* into v_ticket from public.tickets t where t.id=p_ticket_id for update;
  if not found then raise exception using errcode='P0002', message='ticket not found'; end if;
  if v_ticket.status not in ('open','assigned') then raise exception using errcode='40001', message='ticket is already closed'; end if;
  select s.* into v_submission from public.submissions s where s.id=v_ticket.submission_id for update;
  if not found then raise exception using errcode='P0002', message='ticket submission not found'; end if;
  select st.user_id into v_student_user_id from public.students st where st.id=v_ticket.student_id;
  select a.id,a.reviewed_by into v_audit_id,v_original_reviewer from public.audits a
   where a.submission_id=v_ticket.submission_id order by a.created_at desc limit 1 for update;
  v_original_reviewer := coalesce(v_ticket.original_reviewer_id,v_original_reviewer);

  if p_action='ack' then
    if v_ticket.status='assigned' and v_ticket.assigned_to is distinct from p_actor_id then raise exception using errcode='40001', message='ticket is assigned to another reviewer'; end if;
    update public.tickets t set status='assigned',assigned_to=p_actor_id where t.id=p_ticket_id;
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_actor_id,'admin_ticket_acknowledged','ticket',p_ticket_id,jsonb_build_object('assigned_to',p_actor_id));
    return query select p_ticket_id,'assigned'::text,v_ticket.decision;
    return;
  elsif p_action='assign' then
    if p_assigned_to is null or not exists(select 1 from public.profiles p where p.id=p_assigned_to and p.role='admin') then
      raise exception using errcode='22023', message='assignment target must be an admin';
    end if;
    update public.tickets t set status='assigned',assigned_to=p_assigned_to where t.id=p_ticket_id;
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_actor_id,'admin_ticket_assigned','ticket',p_ticket_id,jsonb_build_object('assigned_to',p_assigned_to));
    return query select p_ticket_id,'assigned'::text,v_ticket.decision;
    return;
  end if;

  if p_decision is null or p_decision not in ('upheld','overturned','adjusted') then raise exception using errcode='22023', message='invalid ticket decision'; end if;
  if v_audit_id is null then raise exception using errcode='P0002', message='ticket audit not found'; end if;
  if v_original_reviewer is not null and v_original_reviewer=p_actor_id then raise exception using errcode='42501', message='appeal reviewer must differ from original reviewer'; end if;
  if p_adjusted_scores is not null and p_decision<>'adjusted' then raise exception using errcode='22023', message='adjusted scores require adjusted decision'; end if;
  if p_decision='adjusted' then
    if jsonb_typeof(p_adjusted_scores) is distinct from 'array' then raise exception using errcode='22023', message='adjusted decision requires an array'; end if;
    if jsonb_array_length(p_adjusted_scores) not between 1 and 30 then raise exception using errcode='22023', message='adjusted decision requires 1 to 30 adjusted scores'; end if;
  end if;
  v_note := coalesce(nullif(pg_catalog.btrim(p_note),''),case p_decision when 'upheld' then 'Appeal reviewed; original decision upheld.' when 'overturned' then 'Appeal upheld; further review required.' else 'Appeal reviewed; scores adjusted.' end);
  if length(v_note)>500 then raise exception using errcode='22023', message='decision note is too long'; end if;

  if p_decision in ('upheld','adjusted') then
    update public.audits a set review_status='pending' where a.id=v_audit_id;
    if p_decision='upheld' then
      perform * from public.admin_review_audit(p_actor_id,v_audit_id,'confirm',null,v_note);
    else
      perform * from public.admin_review_audit(p_actor_id,v_audit_id,'adjust',p_adjusted_scores,v_note);
    end if;
  else
    update public.audits a set review_status='pending',reviewed_by=p_actor_id,reviewed_score=null,review_note=v_note where a.id=v_audit_id;
    update public.submissions s set status='needs_review',updated_at=now() where s.id=v_ticket.submission_id;
    update public.skill_scores ss set pending_review=true,share_ok=false,updated_at=now() where ss.audit_id=v_audit_id;
    select (c.value#>>'{}')::numeric into v_pass_mark from public.app_config c where c.key='PASS_MARK';
    select coalesce(jsonb_agg(jsonb_build_object('name',sk.name,'level',ss.level,'score',ss.score,'verified',ss.verified) order by sk.name),'[]'::jsonb)
      into v_skills from public.skill_scores ss join public.skills sk on sk.id=ss.skill_id
      where ss.student_id=v_ticket.student_id and ss.verified and ss.share_ok and not ss.pending_review;
    insert into public.candidate_profiles(student_id,discoverable,skills,refreshed_at)
    select st.id,coalesce((st.visibility->>'discoverable')::boolean,false),v_skills,now() from public.students st where st.id=v_ticket.student_id
    on conflict(student_id) do update set discoverable=excluded.discoverable,skills=excluded.skills,refreshed_at=now();
  end if;

  update public.tickets t set status='closed',decision=p_decision,resolved_at=now() where t.id=p_ticket_id;
  insert into public.rubric_feedback_log(ticket_id,criterion,outcome,note)
  values(p_ticket_id,coalesce(p_criterion,'general'),p_decision,v_note);
  if v_student_user_id is not null then
    insert into public.notifications(user_id,kind,payload)
    values(v_student_user_id,'appeal_update',jsonb_build_object('ticket_id',p_ticket_id,'status','closed','decision',p_decision));
  end if;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'admin_ticket_decided','ticket',p_ticket_id,jsonb_build_object('decision',p_decision,'criterion',coalesce(p_criterion,'general')));
  return query select p_ticket_id,'closed'::text,p_decision;
end;
$$;
revoke all on function public.admin_decide_ticket(uuid,uuid,text,uuid,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.admin_decide_ticket(uuid,uuid,text,uuid,text,text,text,jsonb) to service_role;
comment on function public.admin_decide_ticket(uuid,uuid,text,uuid,text,text,text,jsonb) is 'Service-role-only ticket handling; appeal decisions must differ from the ticket’s preserved original reviewer.';
