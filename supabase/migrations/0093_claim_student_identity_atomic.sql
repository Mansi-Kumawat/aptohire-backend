-- Resolve the Auth user to exactly one permanent student row. Roster/email matches
-- are claimed in this transaction; raw student identifiers never enter the RPC.
create or replace function public.claim_student_identity(
  p_user_id uuid,
  p_verified_email text,
  p_roster_entry_id uuid,
  p_full_name text
)
returns table(student_id uuid,matched_existing_person boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_email text;
  v_email text;
  v_confirmed_at timestamptz;
  v_roster_student_id uuid;
  v_current public.students%rowtype;
  v_linked public.students%rowtype;
  v_email_match public.students%rowtype;
  v_student_id uuid;
  v_matched boolean := false;
begin
  if p_user_id is null or p_full_name is null or pg_catalog.length(pg_catalog.btrim(p_full_name)) not between 1 and 120 then
    raise exception using errcode='22023',message='invalid student identity input';
  end if;
  select u.email,u.email_confirmed_at into v_auth_email,v_confirmed_at from auth.users u where u.id=p_user_id;
  if not found then raise exception using errcode='42501',message='Auth user not found'; end if;
  if p_verified_email is not null then
    if v_confirmed_at is null or v_auth_email is null or pg_catalog.lower(pg_catalog.btrim(p_verified_email))<>pg_catalog.lower(v_auth_email) then
      raise exception using errcode='42501',message='verified email does not match Auth user';
    end if;
    v_email := pg_catalog.lower(pg_catalog.btrim(p_verified_email));
  end if;

  -- Lock the roster row before identity rows, matching the roster-import/approval lock order.
  if p_roster_entry_id is not null then
    select r.student_id into v_roster_student_id
      from public.roster_entries r join public.universities u on u.id=r.university_id and u.status='approved'
     where r.id=p_roster_entry_id for update of r;
    if not found then raise exception using errcode='P0002',message='approved roster row not found'; end if;
  end if;
  if v_email is not null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('student-email:'||v_email,0));
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('student-user:'||p_user_id::text,0));

  select s.* into v_current from public.students s where s.user_id=p_user_id for update;
  if found then v_student_id := v_current.id; v_matched := true; end if;

  if v_roster_student_id is not null then
    select s.* into v_linked from public.students s where s.id=v_roster_student_id for update;
    if not found then raise exception using errcode='P0002',message='roster-linked student not found'; end if;
    if v_linked.user_id is not null and v_linked.user_id<>p_user_id then
      raise exception using errcode='23505',message='student record belongs to another login';
    end if;
    if v_student_id is not null and v_student_id<>v_linked.id then
      raise exception using errcode='23505',message='account cannot claim a different student record';
    end if;
    if v_student_id is null then
      update public.students s set user_id=p_user_id,full_name=pg_catalog.btrim(p_full_name),
        primary_email=coalesce(v_email,s.primary_email),updated_at=now()
       where s.id=v_linked.id and s.user_id is null returning s.id into v_student_id;
      if not found then raise exception using errcode='23505',message='student record was claimed concurrently'; end if;
      v_matched := true;
    end if;
  elsif v_student_id is null and v_email is not null then
    select s.* into v_email_match from public.students s where s.primary_email=v_email for update;
    if found then
      if v_email_match.user_id is not null and v_email_match.user_id<>p_user_id then
        raise exception using errcode='23505',message='email is already linked to another login';
      end if;
      if v_email_match.user_id is null then
        update public.students s set user_id=p_user_id,full_name=pg_catalog.btrim(p_full_name),
          primary_email=v_email,updated_at=now()
         where s.id=v_email_match.id and s.user_id is null returning s.id into v_student_id;
        if not found then raise exception using errcode='23505',message='student record was claimed concurrently'; end if;
      else
        v_student_id := v_email_match.id;
      end if;
      v_matched := true;
    end if;
  end if;

  if v_student_id is null then
    insert into public.students(user_id,full_name,primary_email)
    values(p_user_id,pg_catalog.btrim(p_full_name),v_email)
    returning id into v_student_id;
    v_matched := false;
  end if;
  return query select v_student_id,v_matched;
end;
$$;
revoke all on function public.claim_student_identity(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.claim_student_identity(uuid,text,uuid,text) to service_role;
comment on function public.claim_student_identity(uuid,text,uuid,text) is
  'Atomically resolves one Auth user to an owned, roster-linked, verified-email-linked, or newly created student record without login takeover or raw student-ID storage.';
