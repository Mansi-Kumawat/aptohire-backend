-- Extend candidate projection refresh to keep blind study-stage and university buckets
-- synchronized with the student's current affiliation. These fields are never sourced
-- from unverified affiliations.
create or replace function private.refresh_candidate_profile(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_discoverable boolean;
  v_skills jsonb;
  v_study_stage text;
  v_uni_category text;
  v_program text;
  v_year integer;
  v_status public.life_status;
  v_tier integer;
  v_verification public.affiliation_verification;
  v_university_status text;
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

  select a.program_level, a.year, a.status, a.verification, u.tier, u.status
    into v_program, v_year, v_status, v_verification, v_tier, v_university_status
    from public.affiliations a
    left join public.universities u on u.id = a.university_id
   where a.student_id = p_student_id and a.is_current
   order by a.started_on desc, a.id
   limit 1;

  if found then
    v_study_stage := case
      when v_status = 'alumni' then 'Alumni'
      when v_status = 'dropout' then 'Not currently enrolled'
      when lower(coalesce(v_program, '')) ~ '(master|post.?grad|phd|doctor)' then 'Graduate'
      when v_year is not null and v_year <= 1 then 'Year 1'
      when v_year = 2 then 'Year 2'
      when v_year = 3 then 'Year 3'
      when v_year >= 4 then 'Year 4+'
      when lower(coalesce(v_program, '')) ~ '(undergrad|bachelor|btech|b\.tech|bsc|b\.sc)' then 'Undergraduate'
      else null
    end;
    if v_verification in ('roster', 'student_id') and v_university_status = 'approved' and v_tier between 1 and 3 then
      v_uni_category := 'Tier ' || v_tier::text || ' · University';
    end if;
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

  insert into public.candidate_profiles as cp(student_id, discoverable, skills, study_stage, uni_category, refreshed_at)
  values (
    p_student_id,
    v_discoverable,
    case when v_discoverable then v_skills else '[]'::jsonb end,
    case when v_discoverable then v_study_stage else null end,
    case when v_discoverable then v_uni_category else null end,
    now()
  )
  on conflict (student_id) do update
    set discoverable = excluded.discoverable,
        skills = excluded.skills,
        study_stage = excluded.study_stage,
        uni_category = excluded.uni_category,
        scrubbed_summary = case when excluded.discoverable then cp.scrubbed_summary else null end,
        embedding = case when excluded.discoverable then cp.embedding else null end,
        refreshed_at = excluded.refreshed_at;
end;
$$;

create or replace function private.refresh_candidate_profiles_from_university()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare r record;
begin
  for r in
    select distinct a.student_id
      from public.affiliations a
     where a.university_id = new.id and a.is_current
  loop
    perform private.refresh_candidate_profile(r.student_id);
  end loop;
  return new;
end;
$$;

create or replace function private.refresh_candidate_profile_from_affiliation()
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
  if tg_op = 'UPDATE' and old.student_id is distinct from new.student_id then
    perform private.refresh_candidate_profile(old.student_id);
  end if;
  return new;
end;
$$;

revoke all on function private.refresh_candidate_profile(uuid) from public, anon, authenticated;
revoke all on function private.refresh_candidate_profile_from_affiliation() from public, anon, authenticated;
revoke all on function private.refresh_candidate_profiles_from_university() from public, anon, authenticated;

drop trigger if exists affiliations_refresh_candidate_projection on public.affiliations;
create trigger affiliations_refresh_candidate_projection
  after insert or update or delete on public.affiliations
  for each row execute function private.refresh_candidate_profile_from_affiliation();

drop trigger if exists universities_refresh_candidate_projection on public.universities;
create trigger universities_refresh_candidate_projection
  after update of status, tier on public.universities
  for each row when (old.status is distinct from new.status or old.tier is distinct from new.tier)
  execute function private.refresh_candidate_profiles_from_university();

-- Rebuild the new affiliation-derived buckets for existing students.
do $$
declare r record;
begin
  for r in select id from public.students loop
    perform private.refresh_candidate_profile(r.id);
  end loop;
end;
$$;

comment on function private.refresh_candidate_profile(uuid) is
  'Rebuilds blind candidate projection from discoverability consent, shareable verified skill scores, and verified current-affiliation buckets.';
