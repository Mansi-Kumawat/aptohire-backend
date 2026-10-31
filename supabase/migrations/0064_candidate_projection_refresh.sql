-- Keep the blind employer-facing skill projection in sync with consent and verified scores.
-- This intentionally stores only discoverability and shareable, verified skill facts.
create or replace function private.refresh_candidate_profile(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_discoverable boolean;
  v_skills jsonb;
begin
  if p_student_id is null then return; end if;

  select coalesce((st.visibility->>'discoverable')::boolean, false)
    into v_discoverable
    from public.students st
   where st.id = p_student_id;
  if not found then
    delete from public.candidate_profiles where student_id = p_student_id;
    return;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'name', sk.name,
    'level', ss.level,
    'score', ss.score,
    'verified', ss.verified
  ) order by sk.name), '[]'::jsonb)
    into v_skills
    from public.skill_scores ss
    join public.skills sk on sk.id = ss.skill_id
   where ss.student_id = p_student_id
     and ss.verified
     and ss.share_ok
     and not ss.pending_review;

  insert into public.candidate_profiles as cp(student_id, discoverable, skills, refreshed_at)
  values (p_student_id, v_discoverable, case when v_discoverable then v_skills else '[]'::jsonb end, now())
  on conflict (student_id) do update
    set discoverable = excluded.discoverable,
        skills = excluded.skills,
        study_stage = case when excluded.discoverable then cp.study_stage else null end,
        uni_category = case when excluded.discoverable then cp.uni_category else null end,
        scrubbed_summary = case when excluded.discoverable then cp.scrubbed_summary else null end,
        embedding = case when excluded.discoverable then cp.embedding else null end,
        refreshed_at = excluded.refreshed_at;
end;
$$;

create or replace function private.refresh_candidate_profile_from_skill_score()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform private.refresh_candidate_profile(old.student_id);
    return old;
  end if;
  perform private.refresh_candidate_profile(new.student_id);
  return new;
end;
$$;

create or replace function private.refresh_candidate_profile_from_student()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.refresh_candidate_profile(new.id);
  return new;
end;
$$;

revoke all on function private.refresh_candidate_profile(uuid) from public, anon, authenticated;
revoke all on function private.refresh_candidate_profile_from_skill_score() from public, anon, authenticated;
revoke all on function private.refresh_candidate_profile_from_student() from public, anon, authenticated;

drop trigger if exists skill_scores_refresh_candidate_projection on public.skill_scores;
create trigger skill_scores_refresh_candidate_projection
  after insert or update or delete on public.skill_scores
  for each row execute function private.refresh_candidate_profile_from_skill_score();

drop trigger if exists students_refresh_candidate_projection on public.students;
create trigger students_refresh_candidate_projection
  after insert or update of visibility on public.students
  for each row execute function private.refresh_candidate_profile_from_student();

-- Backfill existing rows so enabling the trigger repairs stale or incomplete projections.
do $$
declare r record;
begin
  for r in select id from public.students loop
    perform private.refresh_candidate_profile(r.id);
  end loop;
end;
$$;

comment on function private.refresh_candidate_profile(uuid) is
  'Rebuilds a blind candidate projection from currently shareable verified skill scores and discoverability consent.';
