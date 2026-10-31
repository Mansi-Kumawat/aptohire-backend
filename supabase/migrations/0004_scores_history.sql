create index skill_scores_student_idx on public.skill_scores(student_id,skill_id);
create index audits_submission_idx on public.audits(submission_id,created_at desc);
create index agent_runs_submission_idx on public.agent_runs(submission_id,created_at desc);
create index submissions_student_idx on public.submissions(student_id,created_at desc);
