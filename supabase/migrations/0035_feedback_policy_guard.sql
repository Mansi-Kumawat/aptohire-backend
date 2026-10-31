-- Preserve blind access_requests: validate organization feedback through a narrow boolean helper
-- rather than granting organizations SELECT on the identity-bearing base table.
create or replace function private.feedback_request_allowed(
  p_organization_id uuid,
  p_student_id uuid,
  p_request_id uuid,
  p_option_codes text[]
)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(
    select 1
    from public.organization_members m
    join public.access_requests r on r.organization_id=m.organization_id
    where m.user_id=auth.uid()
      and m.organization_id=p_organization_id
      and r.id=p_request_id
      and r.student_id=p_student_id
      and r.status in ('accepted','expired')
      and r.responded_at is not null
      and not exists(
        select 1
        from unnest(coalesce(p_option_codes,'{}'::text[])) as chosen(code)
        where not exists(select 1 from public.feedback_options fo where fo.option_code=chosen.code)
      )
  );
$$;
revoke all on function private.feedback_request_allowed(uuid,uuid,uuid,text[]) from public,anon,authenticated;
grant execute on function private.feedback_request_allowed(uuid,uuid,uuid,text[]) to authenticated;
comment on function private.feedback_request_allowed(uuid,uuid,uuid,text[]) is
  'RLS-only boolean gate for organization feedback; does not expose access-request or student data.';

drop policy if exists feedback_org_insert on public.feedback;
create policy feedback_org_insert on public.feedback for insert to authenticated
with check (
  private.feedback_request_allowed(organization_id,student_id,request_id,option_codes)
  and (note is null or length(note)<=280)
);

-- Deliver the student-facing notification only after an authorized feedback row is inserted.
create or replace function private.notify_feedback_received()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid;
  v_organization_name text;
begin
  select s.user_id,o.name into v_user_id,v_organization_name
  from public.students s cross join public.organizations o
  where s.id=new.student_id and o.id=new.organization_id;
  if v_user_id is not null then
    insert into public.notifications(user_id,kind,payload)
    values(v_user_id,'feedback_received',jsonb_build_object(
      'feedback_id',new.id,
      'organization_id',new.organization_id,
      'organization_name',v_organization_name
    ));
  end if;
  return new;
end;
$$;
revoke all on function private.notify_feedback_received() from public,anon,authenticated;
create trigger feedback_received_notification after insert on public.feedback
for each row execute function private.notify_feedback_received();
comment on function private.notify_feedback_received() is
  'Sends an identity-minimal feedback_received notification to the feedback recipient after the authorized insert.';
