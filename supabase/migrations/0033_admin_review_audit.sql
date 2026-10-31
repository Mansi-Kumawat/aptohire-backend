-- Human review resolves the AI borderline state and refreshes only the blind, shareable skill projection.
-- TODO(decision): adjusted audits currently report the unweighted mean of the skills the reviewer changed.
alter table public.audits add column if not exists review_note text;

create or replace function public.admin_review_audit(
  p_actor_id uuid,
  p_audit_id uuid,
  p_decision text,
  p_adjusted_scores jsonb,
  p_note text
)
returns table(audit_id uuid, review_status text, reviewed_score numeric)
language plpgsql security definer set search_path = '' as $$
declare
  v_audit public.audits%rowtype;
  v_student_id uuid;
  v_user_id uuid;
  v_submission_status text;
  v_claimed_skill_ids uuid[];
  v_pass_mark numeric;
  v_item jsonb;
  v_skill_id uuid;
  v_score numeric;
  v_level text;
  v_seen uuid[] := '{}'::uuid[];
  v_reviewed_score numeric;
  v_skills jsonb;
begin
  if not exists(select 1 from public.profiles p where p.id=p_actor_id and p.role='admin') then
    raise exception using errcode='42501', message='admin role required';
  end if;
  if p_decision is null or p_decision not in ('confirm','adjust') or p_note is null or length(pg_catalog.btrim(p_note))=0 or length(p_note)>500 then
    raise exception using errcode='22023', message='invalid review decision or note';
  end if;
  if p_decision='confirm' and p_adjusted_scores is not null and p_adjusted_scores<>'[]'::jsonb then
    raise exception using errcode='22023', message='confirm decision cannot include adjusted scores';
  end if;
  if p_decision='adjust' then
    if jsonb_typeof(p_adjusted_scores) is distinct from 'array' then
      raise exception using errcode='22023', message='adjust decision requires 1 to 30 adjusted scores';
    end if;
    if jsonb_array_length(p_adjusted_scores) not between 1 and 30 then
      raise exception using errcode='22023', message='adjust decision requires 1 to 30 adjusted scores';
    end if;
  end if;
  select a.* into v_audit from public.audits a where a.id=p_audit_id for update;
  if not found then raise exception using errcode='P0002', message='audit not found'; end if;
  if v_audit.review_status<>'pending' then raise exception using errcode='40001', message='audit is not awaiting review'; end if;
  select s.student_id,st.user_id,s.status,s.claimed_skill_ids into v_student_id,v_user_id,v_submission_status,v_claimed_skill_ids
  from public.submissions s join public.students st on st.id=s.student_id where s.id=v_audit.submission_id for update of s;
  if not found then raise exception using errcode='P0002', message='submission not found'; end if;
  if v_submission_status not in ('needs_review','appealed') then raise exception using errcode='40001', message='submission is not in a reviewable state'; end if;
  select (c.value#>>'{}')::numeric into v_pass_mark from public.app_config c where c.key='PASS_MARK';
  if not found or v_pass_mark is null then raise exception 'PASS_MARK configuration is missing'; end if;

  if p_decision='confirm' then
    -- Existing score rows are the canonical AI per-skill result. If this audit includes
    -- skill_id/score pairs, insert those too, matching apply_audit's accepted shape.
    for v_item in select value from pg_catalog.jsonb_array_elements(coalesce(v_audit.rubric,'[]'::jsonb)) loop
      if v_item ? 'skill_id' and v_item ? 'score' then
        if v_item->>'skill_id' is null or (v_item->>'skill_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or jsonb_typeof(v_item->'score') is distinct from 'number' then raise exception using errcode='22023', message='invalid audit skill id'; end if;
        v_skill_id := (v_item->>'skill_id')::uuid;
        v_score := (v_item->>'score')::numeric;
        if not v_skill_id=any(v_claimed_skill_ids) or v_score<0 or v_score>100 then raise exception using errcode='22023', message='audit score is outside claimed skills or bounds'; end if;
        v_level := case when v_score<=50 then 'Emerging' when v_score<=69 then 'Competent' when v_score<=84 then 'Proficient' else 'Advanced' end;
        insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
        values(v_student_id,v_skill_id,v_score,v_level,v_score>v_pass_mark,false,v_score>v_pass_mark,p_audit_id,now())
        on conflict(student_id,skill_id) do update set score=excluded.score,level=excluded.level,verified=excluded.verified,pending_review=false,share_ok=excluded.share_ok,audit_id=p_audit_id,updated_at=now();
        insert into public.skill_score_history(student_id,skill_id,score,level,verified,audit_id)
        values(v_student_id,v_skill_id,v_score,v_level,v_score>v_pass_mark,p_audit_id);
      end if;
    end loop;
    update public.skill_scores ss set pending_review=false,share_ok=ss.score>v_pass_mark,verified=ss.score>v_pass_mark,updated_at=now()
     where ss.student_id=v_student_id and ss.audit_id=p_audit_id;
    v_reviewed_score := coalesce(v_audit.overall_score,0);
  else
    for v_item in select value from pg_catalog.jsonb_array_elements(p_adjusted_scores) loop
      if jsonb_typeof(v_item) is distinct from 'object' or v_item->>'skill_id' is null or (v_item->>'skill_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or jsonb_typeof(v_item->'score') is distinct from 'number' then
        raise exception using errcode='22023', message='invalid adjusted score item';
      end if;
      v_skill_id := (v_item->>'skill_id')::uuid;
      v_score := (v_item->>'score')::numeric;
      if not v_skill_id=any(v_claimed_skill_ids) or v_score<0 or v_score>100 then raise exception using errcode='22023', message='adjusted score is outside claimed skills or bounds'; end if;
      if v_skill_id=any(v_seen) then raise exception using errcode='22023', message='duplicate adjusted skill'; end if;
      v_seen := array_append(v_seen,v_skill_id);
      v_level := case when v_score<=50 then 'Emerging' when v_score<=69 then 'Competent' when v_score<=84 then 'Proficient' else 'Advanced' end;
      insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
      values(v_student_id,v_skill_id,v_score,v_level,v_score>v_pass_mark,false,v_score>v_pass_mark,p_audit_id,now())
      on conflict(student_id,skill_id) do update set score=excluded.score,level=excluded.level,verified=excluded.verified,pending_review=false,share_ok=excluded.share_ok,audit_id=p_audit_id,updated_at=now();
      insert into public.skill_score_history(student_id,skill_id,score,level,verified,audit_id)
      values(v_student_id,v_skill_id,v_score,v_level,v_score>v_pass_mark,p_audit_id);
    end loop;
    update public.skill_scores ss set pending_review=false,share_ok=ss.score>v_pass_mark,verified=ss.score>v_pass_mark,updated_at=now()
     where ss.student_id=v_student_id and ss.audit_id=p_audit_id;
    select avg((entry->>'score')::numeric) into v_reviewed_score from pg_catalog.jsonb_array_elements(p_adjusted_scores) as x(entry);
  end if;

  update public.audits a set review_status='complete',reviewed_by=p_actor_id,reviewed_score=v_reviewed_score,review_note=pg_catalog.btrim(p_note)
   where a.id=p_audit_id;
  update public.submissions s set status='scored',updated_at=now() where s.id=v_audit.submission_id;
  select coalesce(jsonb_agg(jsonb_build_object('name',sk.name,'level',ss.level,'score',ss.score,'verified',ss.verified) order by sk.name),'[]'::jsonb)
    into v_skills from public.skill_scores ss join public.skills sk on sk.id=ss.skill_id
    where ss.student_id=v_student_id and ss.verified and ss.share_ok and not ss.pending_review;
  insert into public.candidate_profiles(student_id,discoverable,skills,refreshed_at)
  select st.id,coalesce((st.visibility->>'discoverable')::boolean,false),v_skills,now() from public.students st where st.id=v_student_id
  on conflict(student_id) do update set discoverable=excluded.discoverable,skills=excluded.skills,refreshed_at=now();
  if v_user_id is not null then
    insert into public.notifications(user_id,kind,payload)
    values(v_user_id,'review_decided',jsonb_build_object('audit_id',p_audit_id,'decision',p_decision,'status','complete'));
  end if;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(p_actor_id,'admin_audit_reviewed','audit',p_audit_id,jsonb_build_object('decision',p_decision,'reviewed_score',v_reviewed_score));
  return query select p_audit_id,'complete'::text,v_reviewed_score;
end;
$$;
revoke all on function public.admin_review_audit(uuid,uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.admin_review_audit(uuid,uuid,text,jsonb,text) to service_role;
comment on function public.admin_review_audit(uuid,uuid,text,jsonb,text) is 'Service-role-only human review; resolves score sharing and candidate projection in one transaction.';
