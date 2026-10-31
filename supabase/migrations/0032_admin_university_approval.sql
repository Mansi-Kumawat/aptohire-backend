-- University decisions are atomic. Approval performs conservative matching only against
-- confirmed auth emails, claims roster links, opens verified affiliations when safe, and
-- creates student-confirmed proposals when another current affiliation exists.
-- TODO(decision): review the confirmed-email auto-claim policy before production data is used.
create or replace function public.admin_university_action(
  p_actor_id uuid,
  p_university_id uuid,
  p_decision text,
  p_note text default null
)
returns table(university_id uuid, status text, matched_existing integer, proposals_created integer)
language plpgsql security definer set search_path = '' as $$
declare
  v_old_status text;
  v_new_status text;
  v_matched integer := 0;
  v_proposals integer := 0;
  v_roster record;
  v_current public.affiliations%rowtype;
  v_proposal_id uuid;
begin
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='admin') then
    raise exception using errcode='42501', message='admin role required';
  end if;
  if p_university_id is null or p_decision is null or p_decision not in ('approve','reject') then
    raise exception using errcode='22023', message='invalid university decision';
  end if;
  if p_note is not null and length(p_note)>500 then raise exception using errcode='22023', message='note is too long'; end if;
  select u.status into v_old_status from public.universities u where u.id=p_university_id for update;
  if not found then raise exception using errcode='P0002', message='university not found'; end if;
  v_new_status := case when p_decision='approve' then 'approved' else 'rejected' end;
  update public.universities u set status=v_new_status,
    approved_at=case when p_decision='approve' then now() else null end,
    status_note=case when p_decision='reject' then nullif(pg_catalog.btrim(p_note),'') else null end
  where u.id=p_university_id;
  update public.applications a set status=case when p_decision='approve' then 'approved'::public.application_status else 'rejected'::public.application_status end
   where a.type='university' and a.subject_id=p_university_id and a.status='received';

  if p_decision='approve' then
    for v_roster in
      select r.id as roster_entry_id,r.email,r.program_level,r.year,r.status,
             s.id as student_id,s.user_id
      from public.roster_entries r
      join auth.users u on u.email_confirmed_at is not null and pg_catalog.lower(u.email)=pg_catalog.lower(r.email::text)
      join public.students s on s.user_id=u.id
      where r.university_id=p_university_id and r.student_id is null and r.email is not null
        and not exists(select 1 from public.roster_entries earlier where earlier.university_id=r.university_id and earlier.student_id is null and earlier.email is not null and pg_catalog.lower(earlier.email::text)=pg_catalog.lower(r.email::text) and earlier.id<r.id)
      order by r.id for update of r
    loop
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_roster.student_id::text||':'||p_university_id::text,0));
      select a.* into v_current from public.affiliations a where a.student_id=v_roster.student_id and a.is_current for update;
      if found and v_current.university_id=p_university_id then
        update public.affiliations a set roster_entry_id=v_roster.roster_entry_id,verification='roster'::public.affiliation_verification,
          program_level=coalesce(v_roster.program_level,a.program_level),year=coalesce(v_roster.year,a.year),status=v_roster.status
         where a.id=v_current.id;
      elsif found then
        select ap.id into v_proposal_id from public.affiliation_proposals ap
         where ap.student_id=v_roster.student_id and ap.university_id=p_university_id and ap.state='pending'
         order by ap.created_at limit 1 for update;
        if found then
          update public.affiliation_proposals ap set roster_entry_id=v_roster.roster_entry_id,
            program_level=coalesce(v_roster.program_level,ap.program_level),status=v_roster.status,year=coalesce(v_roster.year,ap.year)
          where ap.id=v_proposal_id;
        else
          insert into public.affiliation_proposals(student_id,university_id,roster_entry_id,program_level,status,year)
          values(v_roster.student_id,p_university_id,v_roster.roster_entry_id,v_roster.program_level,v_roster.status,v_roster.year)
          returning id into v_proposal_id;
          v_proposals := v_proposals+1;
          insert into public.notifications(user_id,kind,payload)
          values(v_roster.user_id,'affiliation_proposal',jsonb_build_object('proposal_id',v_proposal_id,'university_id',p_university_id));
        end if;
      else
        insert into public.affiliations(student_id,university_id,roster_entry_id,verification,program_level,year,status,is_current)
        values(v_roster.student_id,p_university_id,v_roster.roster_entry_id,'roster'::public.affiliation_verification,v_roster.program_level,v_roster.year,v_roster.status,true);
      end if;
      update public.roster_entries r set student_id=v_roster.student_id
       where r.id=v_roster.roster_entry_id and r.student_id is null;
      if not found then raise exception 'roster row was claimed concurrently' using errcode='40001'; end if;
      v_matched := v_matched+1;
    end loop;
  end if;

  if p_decision='approve' and v_matched>0 then
    insert into public.notifications(user_id,kind,payload)
    select m.user_id,'roster_matched',jsonb_build_object('university_id',p_university_id,'matched_existing',v_matched,'proposals_created',v_proposals)
    from public.university_members m where m.university_id=p_university_id;
  end if;
  insert into public.notifications(user_id,kind,payload)
  select m.user_id,'application_decided',jsonb_build_object('university_id',p_university_id,'status',v_new_status)
  from public.university_members m where m.university_id=p_university_id;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'admin_university_decided','university',p_university_id,
    jsonb_build_object('decision',p_decision,'status',v_new_status,'matched_existing',v_matched,'proposals_created',v_proposals));
  return query select p_university_id,v_new_status,v_matched,v_proposals;
end;
$$;
revoke all on function public.admin_university_action(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.admin_university_action(uuid,uuid,text,text) to service_role;
comment on function public.admin_university_action(uuid,uuid,text,text) is 'Service-role-only admin decision; approval matches only confirmed account email and never overwrites a different current affiliation.';
