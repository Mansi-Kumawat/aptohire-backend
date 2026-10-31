-- Two-phase student deletion: disable application access, erase/anonymize student records,
-- then soft-delete the Auth account so append-only audit-log foreign keys remain valid.
alter table public.profiles add column if not exists deletion_started_at timestamptz;
alter table public.access_requests alter column student_id drop not null;
alter table public.roster_entries add column if not exists anonymized_at timestamptz;
alter table public.roster_entries drop constraint if exists roster_entries_check;
alter table public.roster_entries add constraint roster_entries_identity_or_anonymized_check
  check(student_id_hash is not null or email is not null or anonymized_at is not null);

create or replace function private.app_role()
returns text language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p
  where p.id=auth.uid() and p.deletion_started_at is null
$$;
create or replace function private.my_student_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select s.id from public.students s
  join public.profiles p on p.id=s.user_id
  where s.user_id=auth.uid() and p.deletion_started_at is null
  limit 1
$$;
comment on function private.app_role() is 'Returns no role once an account deletion starts.';
comment on function private.my_student_id() is 'Returns no student id once an account deletion starts.';

create or replace function public.erase_student_account_data(p_user_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_role text;
  v_student_id uuid;
  v_primary_email extensions.citext;
begin
  select p.role into v_role from public.profiles p where p.id=p_user_id for update;
  if v_role is distinct from 'student' then raise exception using errcode='42501',message='student account required'; end if;
  update public.profiles p set deletion_started_at=coalesce(p.deletion_started_at,now()) where p.id=p_user_id;
  select s.id,s.primary_email into v_student_id,v_primary_email from public.students s where s.user_id=p_user_id for update;

  if v_student_id is not null then
    update public.access_requests r
       set status=case when r.status in ('pending','accepted') then 'withdrawn' else r.status end,
           granted_scope='{}',expires_at=coalesce(r.expires_at,now()),
           responded_at=case when r.status in ('pending','accepted') then coalesce(r.responded_at,now()) else r.responded_at end,
           message=null,match_result_id=null,student_id=null
     where r.student_id=v_student_id;
    delete from public.feedback f where f.student_id=v_student_id;
    delete from public.rubric_feedback_log l where l.ticket_id in (select t.id from public.tickets t where t.student_id=v_student_id);
    delete from public.tickets t where t.student_id=v_student_id;
    delete from public.placements pl where pl.student_id=v_student_id;
    update public.roster_entries r
       set student_id=null,student_id_hash=null,email=null,full_name='Anonymized student',anonymized_at=coalesce(r.anonymized_at,now())
     where r.student_id=v_student_id or (v_primary_email is not null and r.email=v_primary_email);
    delete from public.notifications n where n.user_id=p_user_id;
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_user_id,'student_account_data_erased','student',v_student_id,jsonb_build_object('data_subject_id',v_student_id));
    delete from public.students s where s.id=v_student_id;
  else
    delete from public.notifications n where n.user_id=p_user_id;
    insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
    values(p_user_id,'student_account_data_erased','auth_user',p_user_id,jsonb_build_object('data_subject_id',p_user_id));
  end if;
  return v_student_id;
end;
$$;
revoke all on function public.erase_student_account_data(uuid) from public,anon,authenticated;
grant execute on function public.erase_student_account_data(uuid) to service_role;
comment on function public.erase_student_account_data(uuid) is 'Idempotently disables student app access, withdraws/anonymizes requests, erases student rows and records an id-only audit event.';

create or replace function public.finalize_student_account_deletion(p_user_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_deleted_at timestamptz;
begin
  select p.deletion_started_at into v_deleted_at from public.profiles p where p.id=p_user_id and p.role='student' for update;
  if not found or v_deleted_at is null then raise exception using errcode='42501',message='deletion has not been prepared'; end if;
  if exists(select 1 from public.students s where s.user_id=p_user_id) then raise exception using errcode='40001',message='student data remains'; end if;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_user_id,'student_account_finalized','auth_user',p_user_id,jsonb_build_object('data_subject_id',p_user_id));
  delete from public.profiles p where p.id=p_user_id;
  return true;
end;
$$;
revoke all on function public.finalize_student_account_deletion(uuid) from public,anon,authenticated;
grant execute on function public.finalize_student_account_deletion(uuid) to service_role;
comment on function public.finalize_student_account_deletion(uuid) is 'Removes the application profile after Auth soft deletion and student-row erasure.';
