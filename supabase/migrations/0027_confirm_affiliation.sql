-- Student-confirmed affiliation changes are atomic and preserve the permanent student record.
create or replace function public.confirm_affiliation(
  p_student_id uuid,
  p_actor_id uuid,
  p_proposal_id uuid,
  p_university_id uuid,
  p_university_name_text text,
  p_student_id_hash text,
  p_program_level text,
  p_year int,
  p_status public.life_status
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_university_id uuid;
  v_university_name text;
  v_roster_id uuid;
  v_roster_student_id uuid;
  v_roster_email text;
  v_verification public.affiliation_verification;
  v_program_level text;
  v_year int;
  v_status public.life_status;
  v_current public.affiliations%rowtype;
  v_has_current boolean := false;
  v_affiliation_id uuid;
  v_unverified boolean := false;
begin
  if p_student_id is null or p_actor_id is null then
    raise exception 'student identity required' using errcode='42501';
  end if;
  if not exists(select 1 from public.students s where s.id=p_student_id and s.user_id=p_actor_id) then
    raise exception 'student identity mismatch' using errcode='42501';
  end if;

  if p_proposal_id is not null then
    select ap.university_id,ap.roster_entry_id,ap.program_level,ap.year,ap.status
      into v_university_id,v_roster_id,v_program_level,v_year,v_status
      from public.affiliation_proposals ap
     where ap.id=p_proposal_id and ap.student_id=p_student_id and ap.state='pending'
     for update;
    if not found then raise exception 'affiliation proposal not found' using errcode='P0002'; end if;
    if not exists(select 1 from public.universities u where u.id=v_university_id and u.status='approved') then
      raise exception 'university is not approved' using errcode='P0002';
    end if;
    if v_roster_id is not null then
      select r.student_id,r.email into v_roster_student_id,v_roster_email
        from public.roster_entries r where r.id=v_roster_id and r.university_id=v_university_id for update;
      if not found then raise exception 'roster row not found' using errcode='P0002'; end if;
      if v_roster_student_id is not null and v_roster_student_id<>p_student_id then
        raise exception 'roster row belongs to another student' using errcode='23505';
      end if;
      if exists(select 1 from auth.users u join public.students s on s.user_id=u.id
                 where s.id=p_student_id and u.email_confirmed_at is not null
                   and pg_catalog.lower(u.email)=pg_catalog.lower(v_roster_email::text)) then
        v_verification := 'roster'::public.affiliation_verification;
      else
        v_verification := 'student_id'::public.affiliation_verification;
      end if;
    else
      v_verification := 'unverified'::public.affiliation_verification;
    end if;
  else
    v_program_level := nullif(pg_catalog.btrim(p_program_level),'');
    v_year := p_year;
    v_status := coalesce(p_status,'student'::public.life_status);
    if v_program_level is null then raise exception 'program level required'; end if;
    if p_year is not null and (p_year < 1 or p_year > 10) then raise exception 'year out of range'; end if;

    if p_university_id is not null then
      select u.name into v_university_name from public.universities u
       where u.id=p_university_id and u.status='approved';
      if not found then raise exception 'university not found or not approved' using errcode='P0002'; end if;
      v_university_id := p_university_id;
      if p_student_id_hash is not null then
        if p_student_id_hash !~ '^[a-f0-9]{64}$' then raise exception 'invalid student id hash'; end if;
        select r.id,r.student_id,r.email into v_roster_id,v_roster_student_id,v_roster_email
          from public.roster_entries r
         where r.university_id=v_university_id and r.student_id_hash=p_student_id_hash
         limit 1 for update;
        if not found then raise exception 'roster match not found' using errcode='P0002'; end if;
        if v_roster_student_id is not null and v_roster_student_id<>p_student_id then
          raise exception 'roster row belongs to another student' using errcode='23505';
        end if;
        v_verification := 'student_id'::public.affiliation_verification;
      else
        v_verification := 'unverified'::public.affiliation_verification;
        v_unverified := true;
      end if;
    elsif p_university_name_text is not null and pg_catalog.length(pg_catalog.btrim(p_university_name_text))>0 then
      v_university_id := null;
      v_university_name := pg_catalog.btrim(p_university_name_text);
      v_verification := 'unverified'::public.affiliation_verification;
      v_unverified := true;
    else
      raise exception 'university selection required';
    end if;
  end if;

  select a.* into v_current from public.affiliations a
   where a.student_id=p_student_id and a.is_current for update;
  v_has_current := found;
  if v_has_current and p_proposal_id is null then
    if v_current.verification<>'unverified' and v_unverified then
      raise exception 'verified affiliation cannot be self-edited' using errcode='42501';
    end if;
    if v_current.verification<>'unverified' and v_current.university_id is not distinct from v_university_id then
      raise exception 'verified affiliation cannot be edited' using errcode='42501';
    end if;
    if v_current.verification='unverified' and v_verification='unverified' then
      update public.affiliations set university_id=v_university_id,university_name_text=case when v_university_id is null then v_university_name else null end,
        program_level=v_program_level,year=v_year,status=v_status where id=v_current.id;
      v_affiliation_id := v_current.id;
    elsif v_current.verification='unverified' and v_verification<>'unverified' then
      update public.affiliations set university_id=v_university_id,university_name_text=null,roster_entry_id=v_roster_id,
        verification=v_verification,program_level=v_program_level,year=v_year,status=v_status where id=v_current.id;
      v_affiliation_id := v_current.id;
    else
      update public.affiliations set is_current=false,ended_on=current_date where id=v_current.id;
    end if;
  elsif v_has_current then
    update public.affiliations set is_current=false,ended_on=current_date where id=v_current.id;
  end if;

  if v_affiliation_id is null then
    insert into public.affiliations(student_id,university_id,university_name_text,roster_entry_id,verification,program_level,year,status,is_current)
    values(p_student_id,v_university_id,case when v_university_id is null then v_university_name else null end,
      v_roster_id,v_verification,v_program_level,v_year,coalesce(v_status,'student'::public.life_status),true)
    returning id into v_affiliation_id;
  end if;

  if v_roster_id is not null then
    update public.roster_entries set student_id=p_student_id
     where id=v_roster_id and (student_id is null or student_id=p_student_id);
    if not found then raise exception 'roster row already claimed' using errcode='23505'; end if;
  end if;
  if p_proposal_id is not null then
    update public.affiliation_proposals set state='confirmed' where id=p_proposal_id and student_id=p_student_id and state='pending';
    if not found then raise exception 'proposal state changed' using errcode='40001'; end if;
  end if;

  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'affiliation_confirmed','student',p_student_id,jsonb_build_object('affiliation_id',v_affiliation_id,'verification',v_verification::text));
  return jsonb_build_object('id',v_affiliation_id,'university_id',v_university_id,
    'university_name_text',case when v_university_id is null then v_university_name else null end,
    'verification',v_verification::text,'program_level',v_program_level,'year',v_year,
    'status',coalesce(v_status,'student'::public.life_status)::text,'is_current',true);
end
$$;
revoke all on function public.confirm_affiliation(uuid,uuid,uuid,uuid,text,text,text,int,public.life_status) from public,anon,authenticated;
grant execute on function public.confirm_affiliation(uuid,uuid,uuid,uuid,text,text,text,int,public.life_status) to service_role;
comment on function public.confirm_affiliation(uuid,uuid,uuid,uuid,text,text,text,int,public.life_status) is
  'Atomically confirms an owned proposal or creates/updates the caller student affiliation. Never creates a student or mutates scores, submissions, or credential id.';

-- A university may update its roster facts, but those changes affect only the platform's
-- linked affiliation projection; they never rewrite the university's roster itself.
create or replace function private.sync_affiliation_from_roster()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.student_id is not null and new.student_id is not distinct from old.student_id then
    update public.affiliations set year=new.year,status=new.status,program_level=new.program_level
     where roster_entry_id=new.id and student_id=old.student_id and is_current;
  end if;
  return new;
end
$$;
revoke all on function private.sync_affiliation_from_roster() from public,anon,authenticated;
create trigger roster_affiliation_sync after update of year,status,program_level on public.roster_entries
for each row execute function private.sync_affiliation_from_roster();
