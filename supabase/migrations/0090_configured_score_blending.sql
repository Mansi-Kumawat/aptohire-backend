-- Apply the configured confidence-weighted blend only to final, review-complete audits.
-- Pending borderline scores remain raw and hidden until a human resolves them.
create or replace function public.upsert_skill_score_history_per_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.audit_id is not null then
    update public.skill_score_history h
       set score=new.score, level=new.level, verified=new.verified, created_at=clock_timestamp()
     where h.student_id=new.student_id and h.skill_id=new.skill_id and h.audit_id=new.audit_id;
    if found then return null; end if;
  end if;
  return new;
end;
$$;
revoke all on function public.upsert_skill_score_history_per_audit() from public,anon,authenticated;
drop trigger if exists skill_score_history_upsert_per_audit on public.skill_score_history;
create trigger skill_score_history_upsert_per_audit
before insert on public.skill_score_history
for each row execute function public.upsert_skill_score_history_per_audit();

create or replace function public.compute_blended_skill_score(p_student_id uuid,p_skill_id uuid)
returns numeric
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_blend_n integer;
  v_raw text;
  v_score numeric;
begin
  select c.value#>>'{}' into v_raw from public.app_config c where c.key='SCORE_BLEND_N';
  if v_raw is null or v_raw !~ '^[1-9][0-9]{0,2}$' then
    raise exception using errcode='22023',message='invalid SCORE_BLEND_N configuration';
  end if;
  v_blend_n := v_raw::integer;
  if v_blend_n>100 then raise exception using errcode='22023',message='SCORE_BLEND_N is outside bounds'; end if;

  with per_audit as (
    select distinct on (h.audit_id)
      h.audit_id,h.score,coalesce(a.confidence,0)::numeric as confidence,a.created_at
    from public.skill_score_history h
    join public.audits a on a.id=h.audit_id
    where h.student_id=p_student_id and h.skill_id=p_skill_id and a.review_status='complete'
    order by h.audit_id,h.created_at desc,h.id desc
  ), recent as (
    select * from per_audit order by created_at desc,audit_id desc limit v_blend_n
  )
  select case
    when coalesce(sum(r.confidence),0)>0
      then round(sum(r.score*r.confidence)/sum(r.confidence),2)
    else (array_agg(r.score order by r.created_at desc,r.audit_id desc))[1]
  end
  into v_score from recent r;
  return v_score;
end;
$$;
revoke all on function public.compute_blended_skill_score(uuid,uuid) from public,anon,authenticated;
grant execute on function public.compute_blended_skill_score(uuid,uuid) to service_role;

create or replace function public.refresh_blended_scores_on_final_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_score numeric;
  v_pass_mark numeric;
  v_level text;
  item record;
begin
  if new.review_status is distinct from 'complete' or old.review_status is not distinct from 'complete' then
    return new;
  end if;
  select (c.value#>>'{}')::numeric into v_pass_mark from public.app_config c where c.key='PASS_MARK';
  if v_pass_mark is null or v_pass_mark<0 or v_pass_mark>100 then
    raise exception using errcode='22023',message='invalid PASS_MARK configuration';
  end if;
  for item in
    select ss.student_id,ss.skill_id from public.skill_scores ss where ss.audit_id=new.id
  loop
    v_score := public.compute_blended_skill_score(item.student_id,item.skill_id);
    if v_score is null then continue; end if;
    v_level := case when v_score<=50 then 'Emerging' when v_score<=69 then 'Competent' when v_score<=84 then 'Proficient' else 'Advanced' end;
    update public.skill_scores ss
       set score=v_score,level=v_level,verified=v_score>v_pass_mark,pending_review=false,
           share_ok=v_score>v_pass_mark,updated_at=now()
     where ss.student_id=item.student_id and ss.skill_id=item.skill_id and ss.audit_id=new.id;
  end loop;
  return new;
end;
$$;
revoke all on function public.refresh_blended_scores_on_final_audit() from public,anon,authenticated;
drop trigger if exists refresh_blended_scores_after_final_audit on public.audits;
create trigger refresh_blended_scores_after_final_audit
after update of review_status on public.audits
for each row execute function public.refresh_blended_scores_on_final_audit();

create or replace function public.apply_audit(p_audit_id uuid,p_pass_mark numeric,p_borderline_low numeric,p_borderline_high numeric)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.audits%rowtype;
  item jsonb;
  sid uuid;
  val numeric;
  lev text;
  is_borderline boolean;
  has_scorable_skill boolean := false;
begin
  select * into a from public.audits where id=p_audit_id for update;
  if not found then raise exception using errcode='P0002',message='audit not found'; end if;
  if p_pass_mark is null or p_pass_mark<0 or p_pass_mark>100 or p_borderline_low is null or p_borderline_high is null
     or p_borderline_low<0 or p_borderline_low>100 or p_borderline_high<0 or p_borderline_high>100 or p_borderline_low>p_borderline_high then
    raise exception using errcode='22023',message='invalid scoring config';
  end if;
  select exists(
    select 1 from jsonb_array_elements(coalesce(a.rubric,'[]'::jsonb)) as rubric_entry(value)
     where rubric_entry.value ? 'skill_id' and rubric_entry.value ? 'score'
       and not coalesce((rubric_entry.value->>'insufficient_evidence')::boolean,false)
  ) and exists(
    select 1 from jsonb_array_elements(coalesce(a.rubric,'[]'::jsonb)) as criterion_entry(value)
     where criterion_entry.value->>'key' in ('functionality','quality','ui_accessibility','testing','documentation','problem_solving','communication')
       and not coalesce((criterion_entry.value->>'insufficient_evidence')::boolean,false)
       and jsonb_typeof(criterion_entry.value->'evidence')='array'
       and jsonb_array_length(criterion_entry.value->'evidence')>0
  ) into has_scorable_skill;
  is_borderline := not has_scorable_skill or a.overall_score between p_borderline_low and p_borderline_high;

  for item in select value from jsonb_array_elements(coalesce(a.rubric,'[]'::jsonb)) loop
    if has_scorable_skill and item ? 'skill_id' and item ? 'score'
       and not coalesce((item->>'insufficient_evidence')::boolean,false) then
      sid := (item->>'skill_id')::uuid;
      val := greatest(0,least(100,(item->>'score')::numeric));
      lev := case when val<=50 then 'Emerging' when val<=69 then 'Competent' when val<=84 then 'Proficient' else 'Advanced' end;
      insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
      values((select s.student_id from public.submissions s where s.id=a.submission_id),sid,val,lev,val>p_pass_mark,is_borderline,not is_borderline,p_audit_id,now())
      on conflict(student_id,skill_id) do update set score=excluded.score,level=excluded.level,verified=excluded.verified,pending_review=excluded.pending_review,share_ok=excluded.share_ok,audit_id=p_audit_id,updated_at=now();
      insert into public.skill_score_history(student_id,skill_id,score,level,verified,audit_id)
      values((select s.student_id from public.submissions s where s.id=a.submission_id),sid,val,lev,val>p_pass_mark,p_audit_id);
    end if;
  end loop;
  update public.audits set review_status=case when is_borderline then 'pending' else 'complete' end where id=p_audit_id;
  update public.submissions set status=case when is_borderline then 'needs_review' else 'scored' end,updated_at=now() where id=a.submission_id;
end;
$$;
revoke all on function public.apply_audit(uuid,numeric,numeric,numeric) from public,anon,authenticated;
grant execute on function public.apply_audit(uuid,numeric,numeric,numeric) to service_role;
comment on function public.apply_audit(uuid,numeric,numeric,numeric) is 'Applies only evidence-backed skills, keeps pending scores hidden, and applies configured confidence-weighted blending to final audits.';
