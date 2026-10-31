create or replace function public.apply_audit(p_audit_id uuid,p_pass_mark numeric,p_borderline_low numeric,p_borderline_high numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare a public.audits%rowtype; item jsonb; sid uuid; val numeric; lev text; is_borderline boolean;
begin
 select * into a from public.audits where id=p_audit_id for update;
 if not found then raise exception 'audit not found'; end if;
 if p_pass_mark is null or p_borderline_low is null or p_borderline_high is null or p_borderline_low>p_borderline_high then raise exception 'invalid scoring config'; end if;
 is_borderline := a.overall_score between p_borderline_low and p_borderline_high;
 for item in select value from jsonb_array_elements(coalesce(a.rubric,'[]'::jsonb)) loop
  if item ? 'skill_id' and item ? 'score' then
   sid := (item->>'skill_id')::uuid; val := greatest(0,least(100,(item->>'score')::numeric));
   lev := case when val<=50 then 'Emerging' when val<=69 then 'Competent' when val<=84 then 'Proficient' else 'Advanced' end;
   insert into public.skill_scores(student_id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at)
   values((select s.student_id from public.submissions s where s.id=a.submission_id),sid,val,lev,val>p_pass_mark,is_borderline,not is_borderline,p_audit_id,now())
   on conflict(student_id,skill_id) do update set score=excluded.score,level=excluded.level,verified=excluded.verified,pending_review=excluded.pending_review,share_ok=excluded.share_ok,audit_id=excluded.audit_id,updated_at=now();
   insert into public.skill_score_history(student_id,skill_id,score,level,verified,audit_id)
   values((select s.student_id from public.submissions s where s.id=a.submission_id),sid,val,lev,val>p_pass_mark,p_audit_id);
  end if;
 end loop;
 update public.audits set review_status=case when is_borderline then 'pending' else 'complete' end where id=p_audit_id;
 update public.submissions set status=case when is_borderline then 'needs_review' else 'scored' end, updated_at=now() where id=a.submission_id;
end $$;
revoke all on function public.apply_audit(uuid,numeric,numeric,numeric) from public,anon,authenticated;
grant execute on function public.apply_audit(uuid,numeric,numeric,numeric) to service_role;
comment on function public.apply_audit(uuid,numeric,numeric,numeric) is 'Trusted scoring applicator; receives config values, never embeds pass/borderline constants.';
