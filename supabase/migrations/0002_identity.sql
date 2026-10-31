create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text check (role in ('student','university','organization','admin')),
  created_at timestamptz not null default now()
);
create table public.universities (
  id uuid primary key default gen_random_uuid(), name text not null, short_name text,
  tier int, kind text, city text, state text, status text not null default 'pending',
  email_domains text[] not null default '{}', approved_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.students (
  id uuid primary key default gen_random_uuid(), user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null, primary_email extensions.citext unique,
  credential_id text unique default encode(extensions.gen_random_bytes(9),'hex'), photo_path text, headline text, bio text,
  links jsonb not null default '[]', location text, languages text[] not null default '{}',
  target_skill_ids uuid[] not null default '{}', target_roles text[] not null default '{}',
  visibility jsonb not null default '{"public_verify":["skills","levels"],"discoverable":true,"university_files":false}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index students_primary_email_unique on public.students(primary_email) where primary_email is not null;
create table public.university_members (
  id uuid primary key default gen_random_uuid(), university_id uuid not null references public.universities on delete cascade,
  user_id uuid not null references auth.users on delete cascade, member_role text not null default 'member',
  unique(university_id,user_id)
);
create table public.roster_entries (
  id uuid primary key default gen_random_uuid(), university_id uuid not null references public.universities on delete cascade,
  student_id_hash text, email extensions.citext, program_level text, year int, status public.life_status not null default 'student',
  created_at timestamptz not null default now(), check(student_id_hash is not null or email is not null)
);
create unique index roster_university_hash_uq on public.roster_entries(university_id,student_id_hash) where student_id_hash is not null;
create table public.affiliations (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students on delete cascade,
 university_id uuid references public.universities, university_name_text text, verification public.affiliation_verification not null default 'unverified',
 program_level text, year int, status public.life_status not null default 'student', is_current boolean not null default true,
 started_on date not null default current_date, ended_on date,
 check ((university_id is not null) or (university_name_text is not null))
);
create unique index one_current_affiliation on public.affiliations(student_id) where is_current;
create table public.affiliation_proposals (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students on delete cascade,
 university_id uuid not null references public.universities, roster_entry_id uuid references public.roster_entries,
 program_level text, status public.life_status, year int, state text not null default 'pending' check(state in ('pending','confirmed','dismissed')),
 created_at timestamptz not null default now()
);
create table public.profile_sources (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students on delete cascade,
 source_type text not null, token_secret_id uuid, auto_approve boolean not null default false, consented_at timestamptz, revoked_at timestamptz
);

create or replace function private.app_role() returns text language sql stable security definer set search_path = '' as $$
 select p.role from public.profiles p where p.id = auth.uid()
$$;
create or replace function private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select coalesce(private.app_role()='admin',false)
$$;
create or replace function private.my_student_id() returns uuid language sql stable security definer set search_path = '' as $$
 select s.id from public.students s where s.user_id=auth.uid() limit 1
$$;
create or replace function private.my_university_ids() returns uuid[] language sql stable security definer set search_path = '' as $$
 select coalesce(array_agg(m.university_id),'{}'::uuid[]) from public.university_members m where m.user_id=auth.uid()
$$;
revoke all on function private.app_role(), private.is_admin(), private.my_student_id(), private.my_university_ids() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.app_role(), private.is_admin(), private.my_student_id(), private.my_university_ids() to authenticated;

create or replace function private.reject_profile_role_change() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.role is distinct from old.role and current_user <> 'service_role' then raise exception 'role changes require privileged provisioning'; end if;
 return new;
end $$;
create trigger profiles_role_immutable before update of role on public.profiles for each row execute function private.reject_profile_role_change();

alter table public.profiles enable row level security;
alter table public.universities enable row level security;
alter table public.students enable row level security;
alter table public.university_members enable row level security;
alter table public.roster_entries enable row level security;
alter table public.affiliations enable row level security;
alter table public.affiliation_proposals enable row level security;
alter table public.profile_sources enable row level security;
-- Initial narrow access; later migration phases add validated policies.
grant select on public.profiles to authenticated;
grant select, update (full_name,photo_path,headline,bio,links,location,languages,target_skill_ids,target_roles) on public.students to authenticated;
grant select on public.universities, public.university_members, public.roster_entries, public.affiliations, public.affiliation_proposals to authenticated;
grant select on public.profile_sources to authenticated;
create policy profiles_self_read on public.profiles for select to authenticated using(id=auth.uid() or private.is_admin());
create policy students_self_read on public.students for select to authenticated using(user_id=auth.uid() or private.is_admin());
create policy students_self_update on public.students for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy universities_admin_read on public.universities for select to authenticated using(private.is_admin());
create policy members_self_read on public.university_members for select to authenticated using(user_id=auth.uid() or private.is_admin());
create policy roster_member_read on public.roster_entries for select to authenticated using(university_id=any(private.my_university_ids()) or private.is_admin());
create policy affiliations_self_read on public.affiliations for select to authenticated using(student_id=private.my_student_id() or private.is_admin());
create policy proposals_self_read on public.affiliation_proposals for select to authenticated using(student_id=private.my_student_id() or private.is_admin());
create policy sources_self_read on public.profile_sources for select to authenticated using(student_id=private.my_student_id() or private.is_admin());
