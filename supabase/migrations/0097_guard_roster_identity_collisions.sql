-- A roster import row may identify a person by email, HMACed ID, or both.
-- Never let an UPDATE merge the hash of one roster person with another person's email.
create or replace function private.guard_roster_identity_collisions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.student_id_hash is not null and exists(
    select 1 from public.roster_entries r
     where r.university_id=new.university_id and r.student_id_hash=new.student_id_hash and r.id is distinct from new.id
  ) then
    raise exception using errcode='23505',message='duplicate roster identifier';
  end if;
  if new.email is not null and exists(
    select 1 from public.roster_entries r
     where r.university_id=new.university_id and r.email=new.email and r.id is distinct from new.id
  ) then
    raise exception using errcode='23505',message='duplicate roster email';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_roster_identity_collisions() from public,anon,authenticated,service_role;
drop trigger if exists roster_identity_collision_guard on public.roster_entries;
create trigger roster_identity_collision_guard
before insert or update of university_id,student_id_hash,email on public.roster_entries
for each row execute function private.guard_roster_identity_collisions();
comment on function private.guard_roster_identity_collisions() is
  'Prevents roster imports or writes from cross-merging distinct local ID hashes and emails; invoked only by the table trigger.';
