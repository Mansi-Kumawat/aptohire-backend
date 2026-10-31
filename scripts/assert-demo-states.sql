-- Run after `supabase db reset` with `psql` or `supabase db query --local`.
-- Assertions deliberately fail fast; they do not insert or modify data.
DO $assert_demo_states$
DECLARE
  v_uni_a uuid := md5('seed:uni:a')::uuid;
  v_roster_count integer;
  v_linked_count integer;
  v_submitted_count integer;
  v_verified_count integer;
  v_unclaimed_count integer;
  v_jobs_viz integer;
  v_jobs_node integer;
  v_demo_auth_count integer;
  v_human_review_count integer;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.app_config
    WHERE key = 'APP_ENV' AND value #>> '{}' = 'production'
  ) THEN
    RAISE EXCEPTION 'Demo-state assertions are disabled in production';
  END IF;
  IF (SELECT value #>> '{}' FROM public.app_config WHERE key='AGENT_MODE') IS DISTINCT FROM 'mock' THEN
    RAISE EXCEPTION 'Demo reset must leave AGENT_MODE=mock';
  END IF;
  IF (SELECT value #>> '{}' FROM public.app_config WHERE key='AI_KILL_SWITCH') IS DISTINCT FROM 'false' THEN
    RAISE EXCEPTION 'Demo reset must leave AI_KILL_SWITCH=false';
  END IF;

  SELECT count(*) INTO v_roster_count FROM public.roster_entries WHERE university_id = v_uni_a;
  IF v_roster_count <> 90 THEN
    RAISE EXCEPTION 'Uni A roster expected 90 rows, got %', v_roster_count;
  END IF;

  SELECT count(*) INTO v_linked_count
  FROM public.roster_entries WHERE university_id = v_uni_a AND student_id IS NOT NULL;
  IF v_linked_count <> 58 THEN
    RAISE EXCEPTION 'Uni A expected 58 registered roster rows, got %', v_linked_count;
  END IF;

  SELECT count(*) INTO v_submitted_count FROM public.roster_entries r
  WHERE r.university_id=v_uni_a AND r.student_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.submissions s WHERE s.student_id=r.student_id
                AND s.status IN ('scored','needs_review','auditing'));
  SELECT count(*) INTO v_verified_count FROM public.roster_entries r
  WHERE r.university_id=v_uni_a AND r.student_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.skill_scores ss WHERE ss.student_id=r.student_id
                AND ss.verified AND ss.share_ok AND NOT ss.pending_review);
  IF v_submitted_count <> 31 OR v_verified_count <> 19 THEN
    RAISE EXCEPTION 'Uni A demo funnel expected 90 roster / 58 registered / 31 submitted / 19 verified; submitted %, verified %',
      v_submitted_count,v_verified_count;
  END IF;

  SELECT count(*) INTO v_unclaimed_count
  FROM public.roster_entries WHERE university_id = v_uni_a AND student_id IS NULL;
  IF v_unclaimed_count < 1 THEN
    RAISE EXCEPTION 'Uni A must include an unclaimed roster row';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.roster_entries
    WHERE id=md5('seed:unia:roster:1')::uuid AND full_name='Aman Incoming'
      AND student_id IS NULL AND status='incoming' AND program_level='ug'
  ) THEN
    RAISE EXCEPTION 'Canonical incoming unclaimed Uni A roster case is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.roster_entries r
    JOIN public.universities u ON u.id = r.university_id
    WHERE u.id = md5('seed:uni:c')::uuid AND r.full_name IS NOT NULL
      AND u.status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Pending Uni C and its demo roster rows are required';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.organizations WHERE id=md5('seed:org:c')::uuid AND status='pending')
     OR NOT EXISTS (SELECT 1 FROM public.organizations WHERE id=md5('seed:org:d')::uuid AND status='approved' AND subscription_status='inactive') THEN
    RAISE EXCEPTION 'Pending Orbit Analytics and inactive Cedar Works fixtures are required';
  END IF;

  SELECT count(*) INTO v_jobs_viz FROM public.jobs
  WHERE status='open' AND title ILIKE '%visualization%';
  SELECT count(*) INTO v_jobs_node FROM public.jobs
  WHERE status='open' AND title ILIKE '%node.js%';
  IF v_jobs_viz <> 1 OR v_jobs_node <> 2 THEN
    RAISE EXCEPTION 'Expected one data-visualization and two Node.js jobs; got %, %', v_jobs_viz, v_jobs_node;
  END IF;

  IF (SELECT count(*) FROM public.demand_signals WHERE university_id=v_uni_a AND 'node-js'=ANY(skill_slugs)) < 2 THEN
    RAISE EXCEPTION 'Uni A Node.js unmatched-demand fixtures are missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.demand_signals WHERE university_id=v_uni_a AND 'visualization'=ANY(skill_slugs)) THEN
    RAISE EXCEPTION 'Uni A data-visualization demand fixture is missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.applications WHERE reference='AH-7K2Q9F' AND status='received')
     OR NOT EXISTS (SELECT 1 FROM public.applications WHERE reference='AH-4M8Z2D' AND status='received') THEN
    RAISE EXCEPTION 'Pending demo applications are missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.applications a JOIN public.universities u ON u.id=a.subject_id
    WHERE a.reference='AH-8R2V3D' AND a.status='received' AND u.status='pending'
      AND u.email_domains @> array['gmail.test']
  ) THEN
    RAISE EXCEPTION 'Riverbend College free-mail-style pending application is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.applications a JOIN public.organizations o ON o.id=a.subject_id
    WHERE a.reference='AH-9Q3W4C' AND a.status='received' AND o.status='pending'
      AND split_part(a.contact_email::text,'@',2)='personal.test'
      AND split_part(regexp_replace(o.website,'^https?://',''), '/', 1)='quickhire.example.test'
  ) THEN
    RAISE EXCEPTION 'Quick Hire Co contact/website mismatch fixture is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.applications a JOIN public.universities u ON u.id=a.subject_id
    WHERE a.reference='AH-5D8F2K' AND a.status='rejected' AND u.status='rejected'
      AND u.status_note IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Rejected demo application and applicant-facing note are missing';
  END IF;

  SELECT count(*) INTO v_demo_auth_count FROM auth.users u
  JOIN public.profiles p ON p.id=u.id
  WHERE u.email=ANY(array[
    'admin@demo.aptohire.test','reviewer2@demo.aptohire.test','reviewer3@demo.aptohire.test',
    'aarav@unia.edu.test','naman@demo.aptohire.test','avi@demo.aptohire.test','niya@demo.aptohire.test',
    'tpo@unia.edu.test','tpo@unib.edu.test','tpo@unic.edu.test',
    'recruiter@orga.demo.test','recruiter@orgb.demo.test','recruiter@orgc.demo.test','recruiter@orgd.demo.test',
    'sohan@demo.aptohire.test'
  ]);
  IF v_demo_auth_count <> 15 THEN
    RAISE EXCEPTION 'Expected 15 fictional demo Auth accounts with profiles, got %',v_demo_auth_count;
  END IF;
  IF (SELECT count(*) FROM (VALUES
      ('admin@demo.aptohire.test','admin'),
      ('reviewer2@demo.aptohire.test','admin'),
      ('reviewer3@demo.aptohire.test','admin'),
      ('aarav@unia.edu.test','student'),
      ('naman@demo.aptohire.test','student'),
      ('avi@demo.aptohire.test','student'),
      ('niya@demo.aptohire.test','student'),
      ('sohan@demo.aptohire.test','student'),
      ('tpo@unia.edu.test','university'),
      ('tpo@unib.edu.test','university'),
      ('tpo@unic.edu.test','university'),
      ('recruiter@orga.demo.test','organization'),
      ('recruiter@orgb.demo.test','organization'),
      ('recruiter@orgc.demo.test','organization'),
      ('recruiter@orgd.demo.test','organization')
    ) AS expected(email,profile_role)
    JOIN auth.users u ON u.email=expected.email
    JOIN public.profiles p ON p.id=u.id AND p.role::text=expected.profile_role) <> 15 THEN
    RAISE EXCEPTION 'One or more fictional demo accounts have the wrong portal role';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profile_sources ps
    JOIN public.profile_proposals pp ON pp.source_id=ps.id AND pp.student_id=ps.student_id
    JOIN public.students s ON s.id=ps.student_id
    WHERE ps.id=md5('seed:profile-source:sohan:linkedin')::uuid
      AND ps.student_id=md5('seed:student:sohan')::uuid
      AND ps.source_type='linkedin_export' AND ps.consented_at IS NOT NULL
      AND ps.revoked_at IS NULL AND ps.auto_approve AND pp.state='approved'
      AND s.user_id=md5('seed:auth:sohan@demo.aptohire.test')::uuid
      AND s.headline='Frontend developer at Northwind Labs'
  ) THEN
    RAISE EXCEPTION 'Sohan consented auto-approved fictional profile-source fixture is incomplete';
  END IF;

  SELECT count(*) INTO v_human_review_count FROM public.audits
  WHERE id IN (SELECT md5('seed:human-review:audit:'||n)::uuid FROM generate_series(1,30) n)
    AND review_status='complete'
    AND reviewed_by=md5('seed:auth:reviewer2@demo.aptohire.test')::uuid;
  IF v_human_review_count <> 30 THEN
    RAISE EXCEPTION 'Expected 30 synthetic human-review demo audits, got %',v_human_review_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.skill_scores ss
    JOIN public.audits a ON a.id=ss.audit_id
    JOIN public.submissions s ON s.id=a.submission_id
    WHERE ss.student_id=md5('seed:student:avi')::uuid
      AND ss.skill_id=md5('seed:skill:sql')::uuid AND ss.score=90
      AND ss.level='Advanced' AND ss.verified AND ss.share_ok AND NOT ss.pending_review
      AND a.review_status='complete' AND s.status='scored'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.skill_scores ss
    JOIN public.audits a ON a.id=ss.audit_id
    JOIN public.submissions s ON s.id=a.submission_id
    WHERE ss.student_id=md5('seed:student:akshit')::uuid
      AND ss.skill_id=md5('seed:skill:typescript')::uuid AND ss.score=58
      AND ss.level='Competent' AND ss.verified AND ss.share_ok AND NOT ss.pending_review
      AND a.review_status='complete' AND s.status='scored'
  ) THEN
    RAISE EXCEPTION 'Pre-scored Avi SQL Advanced and Akshit TypeScript Competent fixtures are required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.affiliation_proposals p
    JOIN public.affiliations a ON a.student_id=p.student_id AND a.is_current
    WHERE p.id=md5('seed:affiliation-proposal:avi:unib')::uuid
      AND p.student_id=md5('seed:student:avi')::uuid
      AND p.university_id=md5('seed:uni:b')::uuid AND p.program_level='pg'
      AND p.state='pending' AND a.university_id=md5('seed:uni:a')::uuid
  ) THEN
    RAISE EXCEPTION 'Avi pending Uni B postgraduate proposal must preserve current Uni A affiliation';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.affiliations a
    WHERE a.student_id=md5('seed:student:aarti')::uuid AND a.is_current
      AND a.university_id=md5('seed:uni:b')::uuid AND a.verification='roster'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.affiliations a
    WHERE a.student_id=md5('seed:student:niya')::uuid AND a.is_current
      AND a.university_id IS NULL AND a.university_name_text='University D'
      AND a.program_level='pg' AND a.verification='unverified'
  ) OR EXISTS (
    SELECT 1 FROM public.affiliations a
    WHERE a.student_id=md5('seed:student:nita')::uuid AND a.is_current
  ) THEN
    RAISE EXCEPTION 'Aarti, Niya, and Nita affiliation lifecycle fixtures are incomplete';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.tickets t
    WHERE t.id=md5('seed:ticket:aarav:confirmed')::uuid
      AND t.status='closed' AND t.decision='upheld'
      AND t.original_reviewer_id=md5('seed:auth:reviewer2@demo.aptohire.test')::uuid
      AND t.assigned_to=md5('seed:auth:reviewer3@demo.aptohire.test')::uuid
  ) OR NOT EXISTS (
    SELECT 1 FROM public.audits a WHERE a.id=md5('seed:audit:aarav')::uuid
      AND a.review_status='complete' AND a.reviewed_by=md5('seed:auth:reviewer3@demo.aptohire.test')::uuid
  ) THEN
    RAISE EXCEPTION 'Confirmed demo ticket must preserve reviewer2 and show reviewer3 resolution';
  END IF;

  IF (SELECT count(*) FROM public.audits
      WHERE id IN (SELECT md5('seed:audit:borderline:'||n)::uuid FROM generate_series(1,5) n)
        AND review_status='pending' AND overall_score BETWEEN 40 AND 60) <> 5 THEN
    RAISE EXCEPTION 'Five pending audits inside the approved borderline score interval are required';
  END IF;
  IF (SELECT count(*) FROM public.audits
      WHERE id IN (SELECT md5('seed:audit:borderline:'||n)::uuid FROM generate_series(1,5) n)
        AND review_status='pending' AND created_at>now()-interval '10 days') <> 4 THEN
    RAISE EXCEPTION 'Four recent pending borderline audits are required for dashboard states';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.audits WHERE id=md5('seed:audit:borderline:1')::uuid
                 AND review_status='pending' AND overall_score BETWEEN 40 AND 60
                 AND created_at<=now()-interval '10 days') THEN
    RAISE EXCEPTION 'Overdue borderline audit fixture is missing';
  END IF;

  IF (SELECT count(*) FROM public.agent_runs
      WHERE id IN (SELECT md5('seed:agent-run:'||n)::uuid FROM generate_series(1,120) n)) <> 120
     OR (SELECT count(DISTINCT mode) FROM public.agent_runs
         WHERE id IN (SELECT md5('seed:agent-run:'||n)::uuid FROM generate_series(1,120) n)) < 3
     OR (SELECT count(DISTINCT status) FROM public.agent_runs
         WHERE id IN (SELECT md5('seed:agent-run:'||n)::uuid FROM generate_series(1,120) n)) < 3 THEN
    RAISE EXCEPTION 'Mixed 120-run synthetic agent telemetry is incomplete';
  END IF;

  IF (SELECT count(*) FROM public.audit_log
      WHERE id IN (SELECT md5('seed:audit-log:'||n)::uuid FROM generate_series(1,200) n)) <> 200 THEN
    RAISE EXCEPTION 'Expected 200 synthetic append-only audit-log records';
  END IF;
END
$assert_demo_states$;

SELECT 'AptoHire demo-state assertions passed' AS result;
