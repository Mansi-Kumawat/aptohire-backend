-- Forward-only correction: preserve finish telemetry while rejecting only reversed evidence line ranges.
-- The prior telemetry migration accidentally restored the inverted range comparator.

create or replace function private.complete_agent_run_unchecked(p_run_id uuid,p_output jsonb,p_evidence_refs text[])
returns table(audit_id uuid,status text)
language plpgsql security definer set search_path = '' as $$
declare
  v_run public.agent_runs%rowtype;
  v_submission public.submissions%rowtype;
  v_audit_id uuid;
  v_pass_mark numeric;
  v_low numeric;
  v_high numeric;
  v_rubric jsonb;
  v_evidence jsonb;
  v_flags text[] := '{}'::text[];
begin
  if p_run_id is null or p_output is null or jsonb_typeof(p_output) is distinct from 'object'
     or jsonb_typeof(p_output->'criteria') is distinct from 'array' or p_evidence_refs is null then
    raise exception using errcode='22023',message='invalid agent callback';
  end if;
  if exists(
    select 1 from pg_catalog.unnest(p_evidence_refs) as provided(ref)
    where provided.ref is null
       or not (provided.ref ~ '^video:[0-9]{1,6}([.][0-9]{1,3})?$'
         or provided.ref ~ '^(repo|file|doc):[A-Za-z0-9._/-]+#L[1-9][0-9]{0,8}-L[1-9][0-9]{0,8}$'
         or provided.ref ~ $re$^live:https://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~:/?#@!$&'()*+,;=%-]*)?$re$)
       or case when provided.ref ~ '^(repo|file|doc):[A-Za-z0-9._/-]+#L[1-9][0-9]{0,8}-L[1-9][0-9]{0,8}$'
         then split_part(split_part(provided.ref,'#L',2),'-L',1)::bigint > split_part(provided.ref,'-L',2)::bigint
         else false end
       or provided.ref ~ '(^|[:/])[.][.]([/#:]|$)'
  ) then
    raise exception using errcode='22023',message='invalid evidence locator';
  end if;
  if coalesce((p_output->>'prompt_injection_attempt')::boolean,false) then v_flags := array['prompt_injection_attempt']; end if;
  select * into v_run from public.agent_runs r where r.id=p_run_id for update;
  if not found then raise exception using errcode='P0002',message='agent run not found'; end if;
  if v_run.status is distinct from 'running' or v_run.mode not in ('direct','n8n') or v_run.submission_id is null then
    raise exception using errcode='40001',message='agent run is not awaiting a callback';
  end if;
  if exists(select 1 from pg_catalog.unnest(p_evidence_refs) as provided(ref)
            where not (provided.ref=any(v_run.evidence_manifest)))
     or exists(select 1 from jsonb_array_elements(coalesce(p_output->'criteria','[]'::jsonb)) as c(value)
               cross join lateral jsonb_array_elements(coalesce(c.value->'evidence','[]'::jsonb)) as e(value)
               where not ((e.value->>'evidence_ref')=any(p_evidence_refs))) then
    raise exception using errcode='22023',message='callback references evidence outside the manifest';
  end if;
  select * into v_submission from public.submissions s where s.id=v_run.submission_id for update;
  if not found or v_submission.status is distinct from 'auditing' then
    raise exception using errcode='40001',message='submission is no longer auditing';
  end if;
  if coalesce(cardinality(v_submission.claimed_skill_ids),0)<1 then
    raise exception using errcode='23514',message='submission has no claimed skills';
  end if;
  select (c.value#>>'{}')::numeric into v_pass_mark from public.app_config c where c.key='PASS_MARK';
  select (c.value->>0)::numeric,(c.value->>1)::numeric into v_low,v_high from public.app_config c where c.key='BORDERLINE';
  if v_pass_mark is null or v_low is null or v_high is null or v_low>v_high then
    raise exception using errcode='55000',message='scoring configuration unavailable';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'key','skill_score','skill_id',x.skill_id,'score',(p_output->>'overall_score')::numeric,
    'confidence',(p_output->>'confidence')::numeric,
    'rationale','Aggregate skill score derived from the validated project audit.',
    'insufficient_evidence',false,'evidence','[]'::jsonb
  )),'[]'::jsonb) into v_rubric
  from pg_catalog.unnest(v_submission.claimed_skill_ids) as x(skill_id);
  v_rubric := coalesce(p_output->'criteria','[]'::jsonb) || v_rubric;
  with evidence_items as (
    select c.value->>'key' as criterion,e.value->>'evidence_ref' as ref,e.value->>'excerpt' as excerpt
    from jsonb_array_elements(coalesce(p_output->'criteria','[]'::jsonb)) as c(value)
    cross join lateral jsonb_array_elements(coalesce(c.value->'evidence','[]'::jsonb)) as e(value)
  ), mapped as (
    select criterion,ref,excerpt,split_part(ref,':',1) as kind,
      substring(ref from position(':' in ref)+1) as pointer
    from evidence_items
  )
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'ref',ref,'kind',kind,
    'label',case when kind='video' then 'Video '
      || lpad(floor((pointer)::numeric/60)::int::text,2,'0') || ':'
      || lpad(floor(mod((pointer)::numeric,60))::int::text,2,'0')
      when kind='live' then 'Live site' else split_part(pointer,'#',1) end,
    'pointer',pointer,'excerpt',excerpt
  ))),'[]'::jsonb) into v_evidence from mapped;
  insert into public.audits(submission_id,rubric_version,prompt_version,overall_score,confidence,summary,rubric,evidence,transcript,visual_observations,next_steps,review_status,flags)
  values(v_submission.id,p_output->>'rubric_version',p_output->>'prompt_version',
    (p_output->>'overall_score')::numeric,(p_output->>'confidence')::numeric,
    p_output->>'summary',v_rubric,v_evidence,coalesce(p_output->'transcript','[]'::jsonb),
    coalesce(p_output->'visual_observations','[]'::jsonb),
    array(select jsonb_array_elements_text(coalesce(p_output->'next_steps','[]'::jsonb))),'unreviewed',v_flags)
  returning id into v_audit_id;
  perform public.apply_audit(v_audit_id,v_pass_mark,v_low,v_high);
  update public.agent_runs set stage='done',status='completed',error_code=null,
    started_at=coalesce(started_at,created_at),
    finished_at=now(),
    latency_ms=coalesce(latency_ms,greatest(0,floor(extract(epoch from(now()-coalesce(started_at,created_at)))*1000)::int))
  where id=p_run_id;
  insert into public.audit_log(actor_id,action,target_type,target_id,metadata)
  values(v_run.user_id,'agent_run_completed','agent_run',p_run_id,jsonb_build_object('audit_id',v_audit_id));
  return query select v_audit_id,'completed'::text;
end; $$;

revoke all on function private.complete_agent_run_unchecked(uuid,jsonb,text[]) from public,anon,authenticated,service_role;
comment on function private.complete_agent_run_unchecked(uuid,jsonb,text[]) is 'Private atomic callback body; records finish telemetry with the audit transaction.';
