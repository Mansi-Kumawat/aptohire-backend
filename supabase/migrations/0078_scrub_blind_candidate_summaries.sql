-- Build the blind-card summary from the latest completed, scored audit. The result
-- is only a draft signal; the BEFORE trigger below scrubs it before storage.
create or replace function private.refresh_candidate_profile(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
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
  v_summary text;
begin
  if p_student_id is null then return; end if;
  select coalesce((st.visibility->>'discoverable')::boolean, false)
    into v_discoverable from public.students st where st.id = p_student_id;
  if not found then
    delete from public.candidate_profiles where student_id = p_student_id;
    return;
  end if;
  select a.program_level, a.year, a.status, a.verification, u.tier, u.status
    into v_program, v_year, v_status, v_verification, v_tier, v_university_status
    from public.affiliations a left join public.universities u on u.id = a.university_id
   where a.student_id = p_student_id and a.is_current
   order by a.started_on desc, a.id limit 1;
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
      else null end;
    if v_verification in ('roster','student_id') and v_university_status = 'approved' and v_tier between 1 and 3 then
      v_uni_category := 'Tier ' || v_tier::text || ' · University';
    end if;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('name', sk.name, 'level', ss.level, 'score', ss.score, 'verified', ss.verified) order by sk.name), '[]'::jsonb)
    into v_skills from public.skill_scores ss join public.skills sk on sk.id = ss.skill_id
   where ss.student_id = p_student_id and ss.verified and ss.share_ok and not ss.pending_review;
  select a.summary into v_summary
    from public.audits a join public.submissions sub on sub.id = a.submission_id
   where sub.student_id = p_student_id and sub.status = 'scored'
     and a.review_status = 'complete' and nullif(btrim(a.summary), '') is not null
   order by a.created_at desc, a.id desc limit 1;
  insert into public.candidate_profiles as cp(student_id, discoverable, skills, study_stage, uni_category, scrubbed_summary, refreshed_at)
  values (p_student_id, v_discoverable,
    case when v_discoverable then v_skills else '[]'::jsonb end,
    case when v_discoverable then v_study_stage else null end,
    case when v_discoverable then v_uni_category else null end,
    case when v_discoverable then v_summary else null end, now())
  on conflict (student_id) do update set
    discoverable = excluded.discoverable, skills = excluded.skills,
    study_stage = excluded.study_stage, uni_category = excluded.uni_category,
    scrubbed_summary = case when excluded.discoverable then excluded.scrubbed_summary else null end,
    embedding = case when excluded.discoverable then cp.embedding else null end,
    refreshed_at = excluded.refreshed_at;
end;
$function$;

create or replace function private.refresh_candidate_profile_from_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare v_student_id uuid;
begin
  select sub.student_id into v_student_id from public.submissions sub where sub.id = new.submission_id;
  if v_student_id is not null then perform private.refresh_candidate_profile(v_student_id); end if;
  return new;
end;
$function$;

create or replace function private.refresh_candidate_profile_from_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform private.refresh_candidate_profile(new.student_id);
  return new;
end;
$function$;

create or replace function private.refresh_candidate_profiles_from_organization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare r record;
begin
  for r in select cp.student_id from public.candidate_profiles cp loop
    perform private.refresh_candidate_profile(r.student_id);
  end loop;
  return new;
end;
$function$;

revoke all on function private.refresh_candidate_profile_from_audit() from public, anon, authenticated;
revoke all on function private.refresh_candidate_profile_from_submission() from public, anon, authenticated;
revoke all on function private.refresh_candidate_profiles_from_organization() from public, anon, authenticated;

drop trigger if exists students_refresh_candidate_projection on public.students;
create trigger students_refresh_candidate_projection
  after insert or update of visibility, full_name, primary_email, location on public.students
  for each row execute function private.refresh_candidate_profile_from_student();
drop trigger if exists universities_refresh_candidate_projection on public.universities;
create trigger universities_refresh_candidate_projection
  after update of status, tier, name, short_name, city, state on public.universities
  for each row execute function private.refresh_candidate_profiles_from_university();
drop trigger if exists organizations_refresh_candidate_summary on public.organizations;
create trigger organizations_refresh_candidate_summary
  after update of name on public.organizations
  for each row when (old.name is distinct from new.name)
  execute function private.refresh_candidate_profiles_from_organization();
drop trigger if exists audit_refresh_candidate_summary on public.audits;
create trigger audit_refresh_candidate_summary
  after insert or update of summary, review_status on public.audits
  for each row execute function private.refresh_candidate_profile_from_audit();
drop trigger if exists submission_refresh_candidate_summary on public.submissions;
create trigger submission_refresh_candidate_summary
  after update of status on public.submissions
  for each row execute function private.refresh_candidate_profile_from_submission();

-- Candidate summaries are blind-card content. Treat every writer as untrusted and
-- deterministically remove identity-bearing values before storing anything visible.
create or replace function private.scrub_candidate_summary(p_value text, p_student_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_text text := left(coalesce(p_value, ''), 4000);
  v_term text;
  v_pos integer;
  v_search_from integer;
begin
  if p_value is null or p_student_id is null then return null; end if;

  -- Remove roster/student names, student emails, university names/locations, and
  -- organization names. The deliberately broad dictionary favors privacy over prose.
  for v_term in
    select distinct term from (
      select nullif(btrim(s.full_name), '') as term from public.students s
      union all select nullif(btrim(name_part.token), '') from public.students s cross join lateral regexp_split_to_table(s.full_name, '[^[:alnum:]]+') as name_part(token)
      union all select nullif(btrim(s.primary_email::text), '') from public.students s
      union all select nullif(btrim(split_part(s.primary_email::text, '@', 1)), '') from public.students s
      union all select nullif(btrim(s.location), '') from public.students s
      union all select nullif(btrim(u.name), '') from public.universities u
      union all select nullif(btrim(name_part.token), '') from public.universities u cross join lateral regexp_split_to_table(u.name, '[^[:alnum:]]+') as name_part(token)
      union all select nullif(btrim(u.short_name), '') from public.universities u
      union all select nullif(btrim(u.city), '') from public.universities u
      union all select nullif(btrim(u.state), '') from public.universities u
      union all select nullif(btrim(o.name), '') from public.organizations o
      union all select nullif(btrim(name_part.token), '') from public.organizations o cross join lateral regexp_split_to_table(o.name, '[^[:alnum:]]+') as name_part(token)
      union all select nullif(btrim(a.university_name_text), '') from public.affiliations a
    ) dictionary
    where term is not null and char_length(term) >= 3
    order by term
  loop
    v_search_from := 1;
    loop
      v_pos := strpos(lower(substr(v_text, v_search_from)), lower(v_term));
      exit when v_pos = 0;
      v_pos := v_search_from + v_pos - 1;
      v_text := overlay(v_text placing '[redacted]' from v_pos for char_length(v_term));
      v_search_from := v_pos + char_length('[redacted]');
      exit when v_search_from > char_length(v_text);
    end loop;
  end loop;

  v_text := regexp_replace(v_text, '[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[redacted]', 'gi');
  v_text := regexp_replace(v_text, '(https?://|www\.)[^[:space:]]+', '[redacted]', 'gi');
  v_text := regexp_replace(v_text, '\+?[0-9][0-9 ()\-.]{7,}[0-9]', '[redacted]', 'g');
  v_text := regexp_replace(v_text, '@[A-Za-z0-9_.-]{2,}', '[redacted]', 'g');
  v_text := btrim(regexp_replace(v_text, '[[:space:]]+', ' ', 'g'));
  if v_text = '' then return null; end if;
  return left(v_text, 600);
end;
$function$;

create or replace function private.scrub_candidate_profile_summary_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  new.scrubbed_summary := private.scrub_candidate_summary(new.scrubbed_summary, new.student_id);
  return new;
end;
$function$;

revoke all on function private.scrub_candidate_summary(text, uuid) from public, anon, authenticated;
revoke all on function private.scrub_candidate_profile_summary_trigger() from public, anon, authenticated;
drop trigger if exists candidate_profile_scrub_summary on public.candidate_profiles;
create trigger candidate_profile_scrub_summary
  before insert or update of scrubbed_summary, student_id on public.candidate_profiles
  for each row execute function private.scrub_candidate_profile_summary_trigger();

-- Rebuild every existing candidate projection from current trust/consent and audit
-- state; summary writes pass through the scrub trigger installed above.
do $block$
declare r record;
begin
  for r in select s.id from public.students s loop
    perform private.refresh_candidate_profile(r.id);
  end loop;
end;
$block$;

comment on function private.scrub_candidate_summary(text, uuid) is
  'Fail-closed deterministic blind-card text scrubber. Removes known roster names, emails, university and organization names, locations, URLs, phones, and social handles; intentionally favors privacy over preserving prose.';
