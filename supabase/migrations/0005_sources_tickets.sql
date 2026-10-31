create table public.profile_proposals(id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students on delete cascade, source_id uuid references public.profile_sources on delete set null, changes jsonb not null, state text not null default 'pending' check(state in ('pending','approved','dismissed')), created_at timestamptz not null default now());
alter table public.profile_proposals enable row level security;
create policy profile_proposals_self_select on public.profile_proposals for select to authenticated using(student_id=private.my_student_id() or private.is_admin());
create policy profile_proposals_self_update on public.profile_proposals for update to authenticated using(student_id=private.my_student_id()) with check(student_id=private.my_student_id() and state in ('approved','dismissed'));
grant select, update(state) on public.profile_proposals to authenticated;
