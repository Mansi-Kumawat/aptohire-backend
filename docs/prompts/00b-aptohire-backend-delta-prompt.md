# PROMPT 0B — `aptohire-backend` DELTA (apply the portal-driven additions to the backend you already built)

> **Use this if you already ran the original backend prompt.** Paste everything below this line into your AI coding tool **inside your existing `aptohire-backend/` folder**.
> **Before you start:** copy `FROZEN-CONTRACTS.md` into `aptohire-backend/docs/` (it holds the exact request/response shapes the frontends already implement, including `submit-application`), and save the updated full prompt (`00-aptohire-backend-prompt.md`) into `aptohire-backend/docs/prompts/` for reference. Sections 5.2, 6.2 and 8.2 of that file are the full specification of the original items; section 3 below (called 15A there) lists the **new** requirements.

---

## 0. Your role and how to work

You are a senior backend and security engineer (Postgres, Supabase, Deno). The repository already contains a backend built from the original prompt. **Do not rebuild it.** Your job is to **audit it against section 3 below ("section 15A" in the full prompt), then add only what is missing or wrong**, safely and incrementally.

Work in this order:

1. **Audit (read-only).** Read the repo: `supabase/migrations`, `supabase/functions`, `supabase/seed.sql`, `supabase/tests`, `docs/`. Write `docs/DELTA_AUDIT.md`: a table with one row per item in section 3 and these columns: **Item · Status (Present / Partial / Missing / Conflicts) · Where (file and line) · Action**. Do not change anything yet.
2. **Plan.** Write `docs/DELTA_PLAN.md` (max 1 page): the new migration files, functions to add or change, tests to add, seed changes, risks.
3. **Implement** in the phases of section 4. After each phase run everything that can run (`supabase db reset`, `supabase test db`, `deno test -A`, `deno check`, `deno lint`) and fix failures before moving on.
4. **Update documentation:** regenerate `docs/CONTRACT.md` (every new or changed object with exact names and the portal that uses it), `docs/RLS_MATRIX.md`, and `contract-dist/` (`npm run contract:export`).
5. **Report honestly** in the format of section 6: **Verified** (you ran it), **Inferred**, **Not run** (and why), **Manual step for the human**. Never claim a test passed unless you ran it.

Rules for decisions:

- Do not ask me questions. Pick the safe default, leave `-- TODO(decision):` or `// TODO(decision):`, and list it in the report.
- All data is **fictional**; emails use the reserved `.test` TLD.

### Non-negotiable constraints for a delta

- **Forward-only migrations.** **Never edit a migration that has already been applied.** Add new, numbered migration files (continue the existing numbering). If an earlier migration is wrong, fix it with a **corrective migration** and say so in the report.
- **Do not rename or remove anything the frontends already depend on.** If a name in 15A differs from what exists, **add the new name** (a view alias, a new column, a thin wrapper function) and keep the old one. Report every such compatibility shim.
- **Keep all security properties from the original prompt:** deny by default, explicit grants, RLS on every table, `security definer` functions with `set search_path = ''`, blind views with no identity columns, `anon` has no privileges, append-only `audit_log`, no secrets in the repo.
- **Every new table, view, column grant or function gets pgTAP/Deno tests** (positive and negative), and `RLS_MATRIX.md` stays one-to-one with the tests.

## 1. Safety rules (non-negotiable)

1. **Local first.** Work only against the local Supabase stack (`supabase start`). **Never run `supabase db push`, `supabase link`, `supabase functions deploy`, or `supabase secrets set` against a remote project.** Put those in the README as steps for the human.
2. **Never disable RLS to fix an error. Never move an authorization check into the frontend.** Never weaken a policy to make a feature work.
3. **No destructive actions** on anything but the local database. No production migrations. No deleting remote data.
4. **Secrets:** never commit a real secret; `.env*` ignored except `.env.example` (names and placeholders only); never print full secret values (redact as `sb_secret_abcd...[REDACTED]`); never put the service-role key, peppers, or provider keys in client-reachable output, logs, error messages or prompts.
5. **Do not send repository contents, student data, or secrets to third-party scanners.**
6. **CORS is not authorization.** Every function authenticates and authorizes explicitly.
7. **MCP/dev tools** (if connected) may touch local/dev only, read-only or least privilege.
8. Stop and report instead of acting if an action could lock users out, rotate credentials, or change production infrastructure.

---

---

## 2. Context you need (summary of the original design)

AptoHire has **five portals** (root, student, university, organization, admin) sharing **one Supabase database**. The backend is the security boundary: RLS, column grants, blind views, and Edge Functions with `withHandler` (Zod-validated, rate-limited, audited). Pass mark and borderline range come from `app_config` (never hard-coded). Roles live in `profiles.role` and can never be changed by the user. Organizations never read identity tables; the only identity path is `reveal-student` (audit-logged). Admin actions need MFA (`aal2`). Full details: `docs/prompts/00-aptohire-backend-prompt.md` and `docs/plan/*`.

---

## 3. Requirements to audit and implement (this is the specification; called "section 15A" in the full prompt)


The portal prompts were written after the original backend prompt and each lists backend items it needs. **These are binding additions.** Where one conflicts with an earlier section, this section wins. Document every item in `docs/CONTRACT.md` with the exact name.

### Student portal (`aptohire-student`)
- Views and tables as in 5.2/6.2: `public_config`, `public_universities`, `public_organizations`, `public_jobs`, `my_affiliation_proposals`, `student_access_requests_v`; `agent_runs.stage` readable by the submission's owner; the extra `students` columns; `tickets` insert policy + appeal trigger; `update_my_visibility` RPC; `profile_proposals`; `export-my-data`; `delete-my-account`; `evidence[].excerpt` and `audits.transcript`.
- `register-student` accepts `{kind:'unregistered', university_name, university_id?}` (a registered university chosen without verification yields an `unverified` affiliation).

### University portal (`aptohire-university`)
- `my_university_v` (own row for members): `id, name, short_name, kind, tier, city, state, status, email_domains, approved_at, reference` and an applicant-visible `status_note` (set by `admin-approve-university` when rejecting).
- `university_students_v` **must include** `roster_entry_id` (stable key), `student_id` (null if unclaimed), `full_name, status, year, program_level, program, verification, claimed, verified_skills_count, last_activity, placement_status`.
- **`university_student_skills_v`**: for the caller's own students only, `student_id, skill_name, family, level, score, verified_on`, restricted to `verified AND share_ok AND NOT pending_review`.
- Analytics views with these columns (cohort dimensions included so the client can filter): `university_overview_v(students_total, verified_students, active_this_month, projects_reviewed)` · `university_funnel_v(year, program, status, invited, registered, submitted, verified)` · `university_skills_v(skill_id, skill_name, family, verified_students, assessed_students, avg_score, open_jobs)` · `university_trends_v(week_start, verified_total, reviews, new_registrations)` (26 weeks) · `university_demand_v(id, skill_name, jobs_count, reasons jsonb, last_posted_at)`. **No student ids or names in any aggregate.**
- `placements` must also be settable for **unclaimed roster entries** (key by `roster_entry_id`, nullable `student_id`).
- Column grants: a university member may update **only** `year, status, program, program_level` on its own `roster_entries`; may delete **only unclaimed** rows; **storage delete** policy on its own `rosters/{university_id}/` objects.
- `roster-import` may be re-run with the same `csv_path` for a real import after a `dry_run`; `matched_existing` and `proposals_created` are **counts only**.
- Read access for universities to `public_jobs` plus any `jobs` columns safe to show (title, mode, location, status, required skills).

### Organization portal (`aptohire-organization`)
- `org_candidate_cards` **must include** `structured_score, vector_score, scrubbed_summary` in addition to the columns in 6.2.
- `org_access_requests_v` **must include** `id, candidate_ref, alias, job_id, job_title, message, requested_scope, granted_scope, duration_days, status, created_at, responded_at, expires_at, pipeline_stage`; **no identity**.
- `my_organization_v` (own row for members): `id, name, kind, size, website, status, subscription_status, verified_at, reference`.
- `jobs`: insert/update/select **only for members of an `approved` organization**; `required_skills jsonb [{skill_id, min_level, weight}]`; `status open|paused|closed`; `openings`.
- `skills`, `feedback_options` readable by authenticated users; `feedback` insert per 8.2 #16.
- `request-access` **rejects messages containing contact details** (email, phone-like numbers, URLs, handles) with `422 VALIDATION_FAILED` (the client also checks).
- `match-job` returns `{ status: 'ready' | 'running', candidate_count }`; reasons and gaps are deterministic text first.
- `reveal-student` returns exactly: `{ request_id, granted_scope, expires_at, profile?: { full_name, headline?, bio?, location?, links?: [{label,url}], university?: { name, verification }, avatar_url? }, scorecard?: { skills: [{ name, level, score?, verified, verified_on?, summary? }] }, projects?: [{ id, title, description?, skills, live_url?, github_url?, files?: [{name,url}], video_url? }], contact?: { email } }` (only granted scopes present).

### Admin console (`aptohire-admin`)
- **`private.is_admin()` must also require `aal2`** (`auth.jwt()->>'aal' = 'aal2'`); every admin RLS policy and every `admin-*` function goes through it. Add a pgTAP test: an `aal1` admin reads nothing.
- Helper views (admin only): `admin_users_v(user_id, display_name, role, created_at, last_sign_in_at, university_or_org)`, `admin_counts_v(pending_approvals, pending_reviews, open_tickets, failed_runs_24h)`, `admin_agent_stats_v` (24 h runs, failure rate, p50/p95 latency, estimated tokens today), `admin_agreement_v` (human-reviewed audits with AI score, human score, outcome; **no identities**), `admin_audit_log_v` (with actor labels), `admin_borderline_v`, `admin_tickets_v` (with `original_reviewer_id`, assignee name).
- `admin-decide-ticket` accepts an optional `criterion` (written to `rubric_feedback_log`); `admin-review-audit` and ticket adjustments use `adjusted_scores: [{ skill_id, score }]`.
- Rejection notes (`admin-approve-university` / `admin-approve-org`) are stored in a column readable by the applicant's members through `my_university_v` / `my_organization_v` (`status_note`).
- Admin may create **signed URLs** for `videos` and `documents` (select policy) and write `skills`, `skill_edges`, `project_templates` (rubrics read-only). Expose who last changed each `app_config` key (`updated_by`, `updated_at`) to admins.
- `admin-view-student` (P2) and user-management functions (disable user, change role, invite) are **optional**; the console is read-mostly for users and has no impersonation.

### Notification kinds (stable strings; payloads carry ids and display text only, **no identity for organization-bound kinds**)
Student: `audit_ready`, `review_needed`, `review_decided`, `appeal_update`, `access_request`, `access_expiring`, `affiliation_proposal`, `feedback_received`, `source_proposals` · University: `application_decided`, `roster_matched`, `demand_alert`, `student_registered` · Organization: `access_accepted`, `access_declined`, `access_withdrawn`, `access_expiring`, `new_match`, `application_decided`, `subscription_changed` · Admin: `application_received`, `ticket_opened`, `review_needed`, `run_failed`.

### Extra seed requirements (non-production only)
- Logins (all `.test`): `tpo@unib.edu.test` (Uni B, approved), `tpo@unic.edu.test` (Uni C, **pending**, reference `AH-7K2Q9F`), `recruiter@orgc.demo.test` (**Orbit Analytics**, pending, reference `AH-4M8Z2D`), `recruiter@orgd.demo.test` (**Cedar Works**, approved, **subscription inactive**), plus admins `reviewer2@demo.aptohire.test` and `reviewer3@demo.aptohire.test` (MFA enrolled via the UI at first sign-in).
- Applications for admin demos: pending **Riverbend College** (free-mail domain in `email_domains`) and **Quick Hire Co** (free-mail contact, website domain mismatch), one **rejected** application with a note, plus the approved ones.
- 5 borderline audits pending review (one overdue by the 3-working-day rule), ~30 human-decided audits, ~120 `agent_runs` (mixed status/mode), ~200 `audit_log` entries, one ticket whose original review was confirmed by the demo admin.
- Uni A should have ~90 students in total (the 6 named plus generated fictional students) with a funnel of roughly 90 → 58 → 31 → 19 so the university dashboard looks alive, and unmatched demand for **Data Visualization** (1 job) and **Node.js** (2 jobs).

---

---

## 4. Implementation phases (finish each, run the checks, then continue)

1. **D1 — Admin hardening:** make `private.is_admin()` require `aal2`; add the pgTAP test (an `aal1` admin reads nothing; an `aal2` admin works); confirm every `admin-*` function checks it; add `admin_users_v`, `admin_counts_v`, `admin_agent_stats_v`, `admin_agreement_v`, `admin_audit_log_v`, `admin_borderline_v`, `admin_tickets_v`; add optional `criterion` to `admin-decide-ticket`; add `updated_by`/`updated_at` visibility for `app_config`; add rejection `status_note` plumbing.
2. **D2 — University additions:** `my_university_v`; extend `university_students_v` (`roster_entry_id`, `program`); add `university_student_skills_v`; add or reshape the five analytics views to the exact columns in 15A; placements for unclaimed roster entries; column grants on `roster_entries` (update only `year, status, program, program_level`; delete only unclaimed); storage delete policy for own `rosters/` objects; `roster-import` re-run with the same `csv_path`, counts-only matching fields.
3. **D3 — Organization additions:** extend `org_candidate_cards` and `org_access_requests_v`; add `my_organization_v`; `jobs` policies limited to members of **approved** organizations; readable `skills` and `feedback_options`; contact-detail rejection in `request-access`; `match-job` `{status, candidate_count}`; confirm the exact `reveal-student` response shape.
4. **D4 — Student/root alignment:** verify every item in the "Student portal" list of 15A; add what is missing (for example `register-student` accepting `{kind:'unregistered', university_name, university_id?}`).
5. **D5 — Notifications and seed:** make sure every notification kind in 15A is produced by the right function or trigger; extend `seed.sql` with the extra logins, applications, borderline audits, tickets, runs, audit log, the larger Uni A population and the unmatched-demand rows; add a seed assertion script (`scripts/assert-demo-states.sql` or Deno) that checks every demo state; keep the production guard (`APP_ENV='production'` refuses to seed).
6. **D6 — Contract and docs:** regenerate `CONTRACT.md`, `RLS_MATRIX.md`, `contract-dist/`; update `README.md` demo-accounts table (emails only), `SECURITY_NOTES.md` and `RUNBOOK.md` for the new objects.

---

## 5. Acceptance checklist

- [ ] `docs/DELTA_AUDIT.md` covers every item in section 3 with an honest status and an action
- [ ] No applied migration was edited; all changes are new forward-only migrations; compatibility shims are listed
- [ ] `supabase db reset` applies everything cleanly; the seed assertion script passes for every demo state
- [ ] An `aal1` admin reads nothing (pgTAP); all `admin-*` functions reject `aal1`
- [ ] Blind views still have **no identity columns** (column list and value scan), including the extended `org_candidate_cards` and `org_access_requests_v`
- [ ] University analytics views contain **no student ids or names**; `university_student_skills_v` excludes unverified, unshareable and under-review skills
- [ ] `roster_entries` grants allow only the four updatable columns and delete only of unclaimed rows; storage delete policy covers only the caller's own `rosters/` objects
- [ ] `jobs` writes are limited to members of approved organizations; organizations still cannot read other organizations' jobs
- [ ] `request-access` rejects contact details in messages; `reveal-student` response matches 15A exactly and only contains granted scopes
- [ ] Every notification kind in 15A is produced and tested; organization-bound payloads contain no identity
- [ ] `CONTRACT.md`, `RLS_MATRIX.md`, `contract-dist/` regenerated and consistent with the code
- [ ] No secrets, no PII in logs, fixtures or docs; `secret:scan` clean

---

## 6. Final report (output exactly this at the end)

### ✅ Backend delta report

**Audit summary:** [counts of Present / Partial / Missing / Conflicts from `DELTA_AUDIT.md`]

**New migrations:** [file names with one-line purpose each]

**Changed or added functions:** [list]

**New or changed views and RPCs (exact names):** [list; these are the names every frontend must use]

**Compatibility shims kept for existing consumers:** [list or "none"]

**Verification status**
- **Verified (executed):** [commands run and results]
- **Inferred (from code/config):** [items]
- **Not run (and why):** [items]
- **Manual steps for the human:** [list]

**Decisions made (`TODO(decision)`):** [each item and default chosen]

**Known limitations:** [list]

**Files created or changed:** [grouped list]

**What the human should do next:**
1. `npm run db:reset`, then `npm run db:test` and `npm run fn:test` on a machine with Docker.
2. `npm run contract:export`, then copy `contract-dist/CONTRACT.md` into each portal's `docs/` folder.
3. Start the portals against the local backend (see the master runbook).
