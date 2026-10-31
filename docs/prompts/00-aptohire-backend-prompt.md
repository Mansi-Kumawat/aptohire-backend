# PROMPT 0 — `aptohire-backend` (shared Supabase backend for all five portals)

> Paste everything below this line into your AI coding tool inside an **empty folder** named `aptohire-backend/`.
> **Before you start,** copy `FROZEN-CONTRACTS.md` into `aptohire-backend/docs/` and copy your five plan documents into `aptohire-backend/docs/plan/`: `prd.md`, `features.md`, `architecture.md`, `design.md`, `agent.md`. They are the source of truth for the data model (`architecture.md` §6), the RLS matrix (§7), and the AI agent contracts (`agent.md` Part B). **This prompt adds to them and overrides them where it says so; section 15A lists additions demanded by the four portal prompts.**

---

## 0. Your role and how to work

You are a senior backend and security engineer (Postgres, Supabase, Deno). Build the **shared backend** for AptoHire: migrations, Row-Level Security (RLS), views, storage rules, Edge Functions, the AI agent layer (`mock` / `direct` / `n8n`), seed data, automated tests, and an exported **contract** that the five frontends consume.

Work in this order:

1. **Read** `docs/plan/*.md` fully. Then write `docs/PLAN.md` (max 2 pages): migration list, function list, what you can and cannot verify in this environment.
2. **Build** in the phases of section 16. After each phase run everything that can run (`supabase db reset`, `supabase test db`, `deno test`, `deno check`, `deno lint`) and fix failures before moving on.
3. **Verify and be honest.** Separate every statement in your report into **Verified** (you executed it), **Inferred** (proved from code/config), **Not run** (e.g., Docker or network unavailable), and **Manual dashboard step**. **Never claim a test passed unless you ran it.**
4. **Report** in the exact format of section 18.

Rules for decisions:

- Do not ask me questions. Pick the safe default, leave `-- TODO(decision):` or `// TODO(decision):`, and list it in the report.
- **Docs win** over your assumptions; this prompt wins over the docs where it explicitly overrides them (section 5.2).
- All data is **fictional**. No real people, emails (use the reserved `.test` TLD), or videos.

---

## 1. Mission and boundaries

AptoHire is **five web projects sharing one Supabase database**:

| Consumer | Host | Talks to this backend as |
|---|---|---|
| `aptohire-root` | `aptohire.com` | Anonymous: `public-verify`, `submit-application` only |
| `aptohire-student` | `student.aptohire.com` | Role `student` |
| `aptohire-university` | `university.aptohire.com` | Role `university` |
| `aptohire-organization` | `organization.aptohire.com` | Role `organization` |
| `aptohire-admin` | `admin.aptohire.com` | Role `admin` (MFA required) |

**This repo owns:** `supabase/migrations`, `supabase/functions`, `supabase/seed.sql`, `supabase/tests`, the agent prompts, `docs/CONTRACT.md`, and the exported contract package. **This repo contains no frontend.**

**The database is the security boundary.** The browsers hold only the public anon key and the user's JWT. Everything else is enforced here.

**Principles (from `architecture.md` §1):** AI proposes, rules decide (identity, consent, permissions and verification status are rule-based code and SQL, never AI); every AI step has a deterministic fallback; blind by construction (organizations never query identity columns); free-tier friendly.

---

## 2. Safety rules (non-negotiable)

1. **Local first.** Work only against the local Supabase stack (`supabase start`). **Never run `supabase db push`, `supabase link`, `supabase functions deploy`, or `supabase secrets set` against a remote project.** Put those in the README as steps for the human.
2. **Never disable RLS to fix an error. Never move an authorization check into the frontend.** Never weaken a policy to make a feature work.
3. **No destructive actions** on anything but the local database. No production migrations. No deleting remote data.
4. **Secrets:** never commit a real secret; `.env*` ignored except `.env.example` (names and placeholders only); never print full secret values (redact as `sb_secret_abcd...[REDACTED]`); never put the service-role key, peppers, or provider keys in client-reachable output, logs, error messages or prompts.
5. **Do not send repository contents, student data, or secrets to third-party scanners.**
6. **CORS is not authorization.** Every function authenticates and authorizes explicitly.
7. **MCP/dev tools** (if connected) may touch local/dev only, read-only or least privilege.
8. Stop and report instead of acting if an action could lock users out, rotate credentials, or change production infrastructure.

---

## 3. Stack and repository layout

| Layer | Choice |
|---|---|
| Database | Supabase Postgres 15+ with `pgcrypto`, `citext`, `vector` (pgvector, HNSW), `pg_cron`, Supabase Vault |
| Functions | Supabase Edge Functions (Deno, TypeScript strict), **Zod** for every input and output |
| Tests | **pgTAP** (`supabase test db`), **Deno test** (functions, agents), GitHub Actions CI |
| Tooling | Supabase CLI, Docker Desktop (local stack), Node 20 only for helper scripts |
| Agent builder | `mock` and `direct` required; `n8n` behind the same adapter (P2, section 9.7) |

```
aptohire-backend/
├─ README.md  .env.example  .gitignore  package.json  deno.json
├─ docs/
│  ├─ plan/               # prd, features, architecture, design, agent (copied in by the human)
│  ├─ PLAN.md  CONTRACT.md  RLS_MATRIX.md  SECURITY_NOTES.md  RUNBOOK.md
├─ supabase/
│  ├─ config.toml
│  ├─ migrations/         # forward-only, one concern per file (section 4.5)
│  ├─ seed.sql            # fictional demo data (section 12)
│  ├─ tests/              # pgTAP: *.test.sql
│  └─ functions/
│     ├─ _shared/         # http.ts, auth.ts, admin.ts, cors.ts, errors.ts, ratelimit.ts, idempotency.ts,
│     │                   # hmac.ts, hash.ts, audit.ts, config.ts, notify.ts, storage.ts,
│     │                   # schemas/ (zod), agents/ (adapter, mock, direct, n8n, providers, prompts/, post/)
│     └─ <kebab-name>/index.ts   # one folder per function (section 8)
├─ n8n/                   # docker-compose.yml + workflows/*.json (P2)
├─ scripts/               # export-contract.ts, create-admin.sql, export-snapshot.sh, secret-scan.sh
├─ contract-dist/         # generated: schemas/, database.types.ts, CONTRACT.md (git-ignored, built by script)
└─ .github/workflows/ci.yml
```

### Scripts (`package.json`)

`db:start`, `db:stop`, `db:reset` (migrations + seed), `db:test` (`supabase test db`), `fn:serve` (`supabase functions serve --env-file .env.local`), `fn:test` (`deno test -A`), `fn:check` (`deno check` + `deno lint`), `types` (`supabase gen types typescript --local`), `contract:export`, `secret:scan`.

### Environment (`.env.example`; real values only in `.env.local`, never committed)

Server-side only (Edge Functions): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APP_ENV` (`local|demo|production`), `ALLOWED_ORIGINS` (comma list), `AGENT_MODE` (`mock|direct|n8n`), `N8N_BASE_URL`, `N8N_WEBHOOK_SECRET`, `CALLBACK_SECRET`, `LLM_PROVIDER_ORDER` (`gemini,groq,openrouter`), `GEMINI_API_KEY`, `GROQ_API_KEY`, `OPENROUTER_API_KEY`, `LLM_MODEL_AUDIT`, `LLM_MODEL_FAST`, `EMBEDDING_MODEL`, `EMBEDDING_DIM` (default 768), `ID_HASH_PEPPER`, `ALIAS_PEPPER`, `RATE_LIMIT_PEPPER`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `TURNSTILE_SECRET_KEY` (optional), `SITE_URLS` (root, student, university, organization), `DEMO_PASSWORD` (non-production only), `VIDEO_MAX_MB`, `VIDEO_MAX_SECONDS`. **Model names are read from env, never hard-coded.** `APP_ENV=production` disables seed/reset and demo features.

---

## 4. Database foundations

### 4.1 Lock everything down first (`0000_lockdown.sql`)

Supabase grants broad default privileges to `anon` and `authenticated`. **Grants and RLS are separate controls; use both.**

- `revoke all` on schema `public` objects from `anon`/`authenticated`, and `alter default privileges in schema public revoke all on tables, sequences, functions from anon, authenticated` (and for the role that runs migrations). **Then grant explicitly, per object and per column where needed.**
- **`anon` gets nothing** except what a function exposes. No table, view, or RPC is executable by `anon` (verified by a pgTAP test that enumerates privileges).
- Create schema **`private`** for internal helpers and tables (rate limits, idempotency keys, secrets references). `private` is **not** exposed by the Data API; `authenticated` gets `usage` only if a policy helper needs it, and `execute` only on the specific helpers.
- Data API exposes **only `public`** (`config.toml` `[api] schemas = ["public"]`); disable GraphQL if unused; no public storage buckets.
- Every `security definer` function: `set search_path = ''`, fully qualified names, `revoke execute from public`, then grant to specific roles only.
- Every table in `public` has `enable row level security` (and `force row level security` on tables written by security-definer code paths where appropriate). A table without RLS and a pgTAP test is not done.
- Views in `public` that act as a **gate** (blind views) are `security_invoker = false` **on purpose**, with the gate in the view's own `WHERE`, a comment saying so, `revoke all from anon`, and explicit grants. Views that merely project the caller's own rows use `security_invoker = true`.

### 4.2 Identity helpers (in `private`, `stable`, `security definer`)

`private.app_role()` (**do not name anything `current_role`; it is a SQL keyword**), `private.is_admin()`, `private.my_student_id()`, `private.my_university_ids()`, `private.my_org_ids()`, `private.student_in_my_university(student_id)` (current **or past** affiliation to one of my universities with `roster`/`student_id` verification), `private.has_active_grant(org_id, student_id, scope)` (accepted, `expires_at > now()`, scope included).

Roles come from `profiles.role`. **A user can never set or change `profiles.role`**: no insert/update policy, a trigger rejects any role change not made by the service role, and a pgTAP test proves it.

### 4.3 `config.toml` requirements

`[api] schemas = ["public"]`; auth: `enable_signup = true`, `enable_confirmations = true`, `minimum_password_length = 10`, `jwt_expiry = 3600`, `enable_refresh_token_rotation = true`, `site_url` = root local URL, `additional_redirect_urls` = `http://localhost:5173/**` through `:5177/**`, TOTP MFA enroll and verify enabled; storage `file_size_limit` set to the free-tier maximum with a comment; local email via Inbucket. Comment which values must be re-checked in the hosted dashboard (**Manual dashboard step** list in `SECURITY_NOTES.md`).

### 4.4 Realtime

Add only these tables to the `supabase_realtime` publication: `submissions`, `agent_runs`, `notifications`, `access_requests`. RLS applies to Realtime changes; never publish tables containing identity data an organization could subscribe to. Add a pgTAP test that lists the publication contents.

### 4.5 Migration files (forward-only, one concern each; never edit an applied migration)

`0000_lockdown` · `0001_extensions_enums` · `0002_identity` (profiles, students, universities, members, roster, affiliations) · `0003_skills_projects_audits` · `0004_scores_history` · `0005_sources_tickets` · `0006_orgs_jobs_matching_consent` · `0007_system` (notifications, audit_log, app_config, rate limits, idempotency, applications) · `0008_functions_scoring` (`apply_audit`, lifecycle triggers, candidate profile refresh) · `0009_views` · `0010_rls_student` · `0011_rls_university` · `0012_rls_organization` · **`rls_visibility.sql`** (**all university↔organization and organization↔organization visibility, in this one file**, so tightening it later is a single change) · `0013_storage` · `0014_cron` · `0015_realtime`.

---

## 5. Data model

### 5.1 Base

Implement `architecture.md` §6 (tables, enums, indexes, `one_current_affiliation`, `apply_audit` scoring rules, HNSW index) exactly, **plus the additions and overrides below**.

### 5.2 Additions and overrides (these win over the docs)

| Area | Change |
|---|---|
| `students` | Add `location text`, `languages text[]`, `target_skill_ids uuid[]`, `target_roles text[]`. Add unique index on `primary_email` where not null. `visibility` shape: `{ "public_verify": ["skills","levels","scores","name","university"], "discoverable": true, "university_files": false }`; **implications enforced by the update RPC**: `levels` requires `skills`, `scores` requires `levels`. Default `["skills","levels"]` |
| `students` writes | Column-level grants let a student update only: `full_name, photo_path, headline, bio, links, location, languages, target_skill_ids, target_roles`. `visibility` changes **only** through RPC **`public.update_my_visibility(visibility jsonb)`** (validates shape and implications, then refreshes the candidate projection). `primary_email` follows the verified auth email via a trigger on `auth.users` (never client-writable) |
| `skill_scores` | Add `pending_review boolean default false` and `share_ok boolean default true`. While a borderline audit awaits review: `pending_review=true`, `share_ok=false`. `share_ok=false` rows never reach `candidate_profiles`, the public verification page, or organization views |
| `submissions` | Add `video_seconds int`, `video_bytes bigint` (client-reported, validated server-side against config; **client-reported duration is untrusted; note this limitation**), `originality_answers jsonb`. Students may insert/update/delete **only while `status='draft'`** and cannot set any other status (`with check`); all other transitions happen in functions |
| `agent_runs` | Add `submission_id uuid references submissions`, **`stage text`** (`received|reading|watching|scoring|writing|done`), `attempt int default 1`, `user_id uuid`. Owner of the submission can `select` the run (Realtime-safe); no student writes |
| `audits` | Add `transcript jsonb`, `visual_observations jsonb`, `next_steps text[]`; `evidence` items may carry `excerpt text` (≤ 1200 chars, **scrubbed** of secrets/PII patterns) |
| `project_assignments` | Student may update only `status` to `in_progress` (column grant + `with check`) |
| `tickets` | Student `insert` where `student_id = my_student_id()`, the submission is theirs and `scored`/`needs_review`, and no open ticket exists for it (partial unique index). Trigger sets `submissions.status='appealed'`; `admin-decide-ticket` restores it |
| `access_requests` | Partial unique index on `(organization_id, student_id, job_id)` where `status in ('pending','accepted')`. Add `pipeline_stage text check in ('interviewing','offered','closed')` (organization may update **only** this column on its own accepted rows). Student identity is never selectable by organizations from this table |
| `affiliation proposals` | New table `affiliation_proposals(id, student_id, university_id, roster_entry_id, program_level, status life_status, year, state 'pending'\|'confirmed'\|'dismissed', created_at)`. Student reads own via view `my_affiliation_proposals` |
| `profile_proposals` | New table `profile_proposals(id, student_id, source_id, changes jsonb, state 'pending'\|'approved'\|'dismissed', created_at)` (student read/update own `state`) |
| `profile_sources` | Add `auto_approve boolean default false`. Tokens only in Vault (`token_secret_id`); the column is **never** selectable by the student |
| `placements` | New: `student_id, university_id, status 'placed'\|'not_placed'\|'unknown' default 'unknown', organization_name_text, role_text, source 'university'\|'student', updated_by, updated_at`. **Never infer `not_placed` from missing data** |
| `applications` | New (admin-only): `id, reference text unique, type 'university'\|'organization', subject_id (university or organization id), contact_name, contact_role, contact_email citext, contact_phone, payload jsonb, status 'received'\|'approved'\|'rejected', claimed_user_id, created_at`. References look like `AH-7K2Q9F` (unambiguous alphabet, 6 chars) |
| `feedback_options` | New lookup of allowed `option_codes` with friendly labels (e.g., `strong_projects`, `needs_more_depth`, `not_a_fit_now`, `great_communication`); `feedback.option_codes` must be a subset |
| `rubric_feedback_log` | New: `ticket_id, criterion, outcome, note, created_at` (admin writes; feeds the rubric improvement log) |
| `private.rate_limits` | `(bucket text, key_hash text, window_start timestamptz, count int)`; **keys are HMAC hashes of IP/email, never raw** |
| `private.idempotency_keys` | `(key uuid, function text, request_hash text, response jsonb, created_at)`; TTL 24 h |
| `audit_log` | **Append-only**: revoke update/delete from every role; written only by functions and triggers; read-only for admin |
| `public_config` (view) | Exposes only: `PASS_MARK`, `BORDERLINE_LOW`, `BORDERLINE_HIGH`, `REQUIRE_VIDEO`, `VIDEO_MAX_MB`, `VIDEO_MAX_SECONDS`, `AI_KILL_SWITCH`, `AI_DAILY_CAP_PER_USER`. Granted to `authenticated` (and `anon` only for the keys the root site needs: none) |
| `app_config` | Seeds: `PASS_MARK=50`, `BORDERLINE=[40,60]`, `AGENT_MODE='mock'`, `REQUIRE_VIDEO=true`, `VIDEO_MAX_MB=50`, `VIDEO_MAX_SECONDS=190`, `AI_DAILY_CAP_PER_USER=5`, `AI_KILL_SWITCH=false`, `SCORE_BLEND_N=1`, `GRANT_DURATIONS=[7,30,90]`. Writes only through `admin-update-config` (audited) |

**Levels:** Emerging ≤ 50 < Competent ≤ 69 < Proficient ≤ 84 < Advanced. `verified = score > PASS_MARK` (read from `app_config`, never hard-coded in SQL functions; pass it in). **Borderline** = score in `[BORDERLINE_LOW, BORDERLINE_HIGH]`.

---

## 6. Authorization (RLS, grants, views)

### 6.1 Policy matrix

Implement `architecture.md` §7.2 exactly, then these decisions:

- **Students** read only their own rows everywhere. "Limited public info" of universities, organizations and jobs is exposed as **views**, not base-table access (6.2).
- **Universities** read: own university row; own `roster_entries` (full CRUD on non-identity columns; `student_id_hash` is written only by functions); own students through limited views; **all organizations and all jobs** (via `rls_visibility.sql`); `demand_signals` for own university; never other universities' data; **never project files** unless `visibility.university_files = true` (no student UI sets it in this phase).
- **Organizations** read: **all universities (public columns)**; **all organizations (public columns)**; **own jobs in full** (and not other organizations' jobs); blind candidate cards for own jobs only; never `students`, `affiliations`, `match_results`, `candidate_profiles`, `submissions`, `audits`, `skill_scores`, `roster_entries`, storage objects.
- **Admin** reads everything via `private.is_admin()` policies (except `profile_sources.token_secret_id`). Admin has **no** impersonation.
- Anonymous reads **nothing**.

### 6.2 Views (names are part of the contract; list columns explicitly, never `select *`)

| View | For | Columns / gate |
|---|---|---|
| `public_config` | authenticated | whitelist above |
| `public_universities` | authenticated | `id, name, short_name, tier, kind, city, state, status` where `status in ('approved')` (students pick from approved ones); universities/admin see their own full row from the base table |
| `public_organizations` | authenticated | `id, name, kind, size, website, verified (verified_at is not null)` where `status='approved'` |
| `public_jobs` | student, university | `id, organization_id, title, mode, location, status` |
| `my_affiliation_proposals` | student | own pending proposals joined to university public columns |
| `student_access_requests_v` | student | own requests joined to `public_organizations` and `public_jobs`: `id, organization_name, organization_verified, job_title, message, requested_scope, granted_scope, duration_days, status, expires_at, created_at, responded_at, pipeline_stage` (student sees stage? no: **omit `pipeline_stage`**) |
| `org_candidate_cards` | organization | `candidate_ref (match_results.id), job_id, alias, final_score, confidence, reasons, gaps, uni_category, skills, study_stage, project_count, request_status`; gate `j.organization_id = any(private.my_org_ids())` and `candidate share_ok` and `discoverable`; **no `student_id`, name, email, photo, university name, file URLs** |
| `org_access_requests_v` | organization | own org's requests with `candidate_ref`, `alias`, `status`, `granted_scope`, `expires_at`, `pipeline_stage`; **no identity** |
| `org_revealed_students` | organization | per `architecture.md` §7.3: identity text fields only where `status='accepted' and expires_at > now()` and scope grants them. `profile` scope = name, headline, bio, location, links, **current university name and verification**; `contact` = email |
| `university_students_v` | university | own students (current or past verified affiliation): `student_id, full_name, status, year, program_level, verification, claimed, verified_skills_count, last_activity, placement_status` |
| `university_overview_v`, `university_funnel_v`, `university_skills_v`, `university_trends_v`, `university_demand_v` | university | own-university aggregates only: counts, averages, funnel (Invited → Registered → Submitted → Verified), skill demand vs supply (demand from all open jobs), weekly trends, unmatched-demand rows with **reason counts and skills, never student ids** |
| `admin_*` helper views | admin | optional convenience for queues (borderline, tickets, agent runs) |

**Files are never exposed to organizations through Storage policies**; only `reveal-student` issues short-lived signed URLs (section 8.D).

### 6.3 Column-level control

Because there is one database role (`authenticated`) for all app roles, **use views and column grants** to separate what each app role may read, never rely on the UI. Student base-table updates are limited by column grants (5.2). Organizations may update only `access_requests.pipeline_stage` on their own accepted rows.

### 6.4 RLS documentation

Generate `docs/RLS_MATRIX.md` from the final policies (table, role, operation, condition, test file). It must match the tests one-to-one.

---

## 7. Storage

Buckets (all **private**; sizes and MIME types set on the bucket as well as in policies):

| Bucket | Path | Rules |
|---|---|---|
| `videos` | `{student_id}/{submission_id}/demo.{ext}` | mp4/webm/mov, ≤ `VIDEO_MAX_MB`; owner insert/select; admin select; agents get **10-minute signed URLs**; resumable (TUS) allowed |
| `documents` | `{student_id}/{submission_id}/{name}` and `{student_id}/sources/{name}` | pdf/docx/md/zip, ≤ 20 MB; owner only |
| `rosters` | `{university_id}/{timestamp}.csv` | university members of that university only; the file is deleted after processing |
| `avatars` | `{student_id}.jpg` | ≤ 1 MB; owner only; reads via signed URL |
| `resumes` | `{student_id}/resume.pdf` | optional cache; owner only |

Policies derive the owner from `private.my_student_id()` and path prefix checks (`storage.foldername(name)`), **not** from client-supplied metadata. No policy ever grants organizations or other students access. A pgTAP/Deno test proves User A cannot create a signed URL or list/read User B's objects, and anonymous users cannot enumerate any bucket. Retention (implemented in cron, section 11): drafts deleted after 30 days; raw videos after 90 days (transcript, scores and evidence pointers stay); **no ID-card images are ever stored**.

---

## 8. Edge Functions

### 8.1 Shared framework (`_shared/`)

Every function uses one wrapper, `withHandler({ auth, roles?, schema, rateLimit, idempotent?, audit? }, fn)`:

- **Auth modes:** `jwt` (verify the JWT with Supabase Auth, then create a **per-request user-scoped client** forwarding the user's token so RLS applies; never share clients between requests), `none` (public functions only), `hmac` (n8n callback only).
- **Role check:** read `profiles.role`; mismatch → `403 FORBIDDEN`. Admin functions also require **`aal2`** (MFA) in the JWT.
- **The admin (service-role) client** lives only in `_shared/admin.ts`, is never the default client, and is used only after explicit authorization in the same request. Every admin-client use is traceable: caller → authentication → authorization → input validation → privileged operation → returned fields → audit log.
- **Input:** parse with Zod (reject unknown fields where stated); never trust a client-supplied user id, role, organization id, price, duration or entitlement.
- **Output:** Zod-validated; never return secrets, hashes, peppers, internal ids not needed, or stack traces. Errors: `{ "error": { "code", "message", "fields?" } }` with the codes in 8.9.
- **CORS:** allow only origins in `ALLOWED_ORIGINS` (the five hosts plus the local ports); `OPTIONS` handled; **CORS is not relied on for security**.
- **Rate limits** (`private.rate_limits`, hashed keys) per function and per user/IP/org; `429 RATE_LIMITED` with `Retry-After`.
- **Idempotency:** accept `Idempotency-Key` where noted; replay returns the stored response.
- **Logging:** structured, **no PII** (ids and hashes only), no request bodies for identity, student ID, transcripts or JD text.
- **`audit_log`** entries for: identity reveal, access grant/withdraw/decline, admin actions, appeals, config changes, approvals, role setting.

### 8.2 Function catalog

Contracts for A and B-1/B-2 below are **frozen** (the frontends already implement them). **The exact request/response shapes of every function the frontends call are in `docs/FROZEN-CONTRACTS.md` (copied from the portal prompts); read it first.** Everything else is specified here; document **all** of them in `docs/CONTRACT.md`.

#### A. Anonymous (root site)

**`public-verify`** · `GET ?id=<18 lowercase hex>` · auth `none` · rate limit 60/min/IP-hash · `Cache-Control: public, max-age=30, s-maxage=60`.
Validate `^[a-f0-9]{18}$`. Look up `students.credential_id` with the admin client. **Identical `404 NOT_FOUND` for malformed, unknown and deleted ids.** Build the response only from `visibility.public_verify`:

```jsonc
{ "credential": {
    "credential_id": "…", "issued_at": "YYYY-MM-DD", "last_updated": "YYYY-MM-DD",
    "display_name": "Aarav S.",                    // only if "name" shared: first name + last initial
    "affiliation": { "label": "Uni A", "verification": "roster" },   // only if "university" shared
    "skills": [ { "name": "React", "level": "Proficient", "verified": true,
                  "score": 72,                     // only if "scores" shared
                  "verified_on": "YYYY-MM-DD" } ],
    "shared_fields": ["skills","levels"] } }
```

Only skills with `verified=true AND share_ok=true` (never skills under human review). If `"skills"` is not shared → `skills: []`. If `"levels"` is not shared but skills are → `level: "Verified"`. `affiliation.verification` is `roster|student_id|unverified` (unverified keeps its label only if "university" is shared). `issued_at` = earliest `verified_on`; `last_updated` = latest `skill_scores.updated_at`. Never return `student_id`, email, photo, or file paths.

**`submit-application`** · `POST` · auth `none` · rate limit 5/hour per IP-hash and 3/day per email-hash · `Idempotency-Key` required.
Body: the discriminated union `type: 'university' | 'organization'` exactly as in **`docs/FROZEN-CONTRACTS.md` section A, 4.2** (fields, bounds, enums, `consent: true`, honeypot `hp`, optional `captcha_token`). Server rules: validate with Zod; **if `hp` is non-empty return a normal `202` with a fake reference and store nothing**; if `TURNSTILE_SECRET_KEY` is set verify the token (else skip); reject common free-mail domains for organizations with `422 VALIDATION_FAILED` and a friendly field message; normalise and validate `email_domains`. Creates a **`pending`** `universities`/`organizations` row and an `applications` row; **never creates a login or sends privileged data**. Response `202 { "reference": "AH-7K2Q9F", "status": "received" }`. Errors: `422 VALIDATION_FAILED { fields }`, `429`, `503`. Notify admins (`notifications`, `audit_log`).

#### B. Identity and student (JWT, role student unless noted)

1. **`complete-signup`** `{ portal: 'student'|'university'|'organization', application_ref?: string }` → `204`. Sets `profiles.role` **once** (idempotent for the same role; different role → `409 ROLE_ALREADY_SET`); `admin` can never be set here. For `university`/`organization`: if the **verified** email equals an application's `contact_email` (and `application_ref` matches when given) attach the user as a member of that pending subject; otherwise the user has no membership and the portal shows "apply for access". `// TODO(decision):` admin-invite path (`admin-invite-member`, P2).
2. **`register-student`** per `architecture.md` §9 and **`docs/FROZEN-CONTRACTS.md` section B**: `{ full_name, program_level, year?, choice: {kind:'detect'} | {kind:'student_id', university_id, student_id_number} | {kind:'unregistered', university_name, university_id?} }` → `{ student_id, outcome, affiliation?, matched_existing_person }` with `outcome ∈ verified_roster | needs_student_id | verified_student_id | unverified | confirm_existing | roster_no_match`.
   - `detect`: verified email domain ∈ **approved** `universities.email_domains` → roster lookup by email → `verified_roster`; domain matches but no roster row → `roster_no_match`; no domain match → `needs_student_id`.
   - `student_id`: university must be **approved**; HMAC-hash the normalised ID with `ID_HASH_PEPPER`, look up `roster_entries.student_id_hash` → `verified_student_id`, else `roster_no_match`. **The raw ID is never stored or logged.**
   - `unregistered`: affiliation `unverified`, `university_name_text` (or the picked university with verification `unverified`); **scores and discoverability are unaffected**.
   - Find the person by verified email or ID hash. Unclaimed match → claim it. Match claimed by **another** login → `409 ACCOUNT_EXISTS` (a roster match may add verification, **never take over a login**). Own existing person with a new matching roster → create an `affiliation_proposal` → `confirm_existing`.
   - Rate limit: 5/hour per user and 20/day per IP-hash for ID attempts. Return the same `roster_no_match` for "no such ID" and "wrong university" (no oracle).
   - Pending (unapproved) universities are **never** matched.
3. **`confirm-affiliation`** `{ proposal_id }` or `{ new: { university_id?, university_name_text?, student_id_number?, program_level, year?, status } }` → `{ affiliation }`. In one transaction: close the current affiliation (`is_current=false`, `ended_on`, status → alumni/dropout as appropriate, or masters rule), open the new one. **No new `students` row. `skill_scores`, `submissions`, `credential_id` untouched.** Unverified affiliations are self-editable; verified ones are not.
4. **`profile-sync`** (student) per **`docs/FROZEN-CONTRACTS.md` section B**: `github_start` returns an authorize URL (**read-only scope**, `state` bound to the user, PKCE where supported); the callback endpoint is a second path of the same function and redirects to `student` `/profile?tab=sources&connected=github`. Tokens go to **Vault**, never to a table or log. `github_sync` fetches public repos/languages/activity and writes `profile_proposals`; `linkedin_parse` parses a **user-uploaded export** (zip/csv ≤ 20 MB from `documents/{student_id}/sources/`) or pasted text (≤ 20,000 chars); **no scraping**. `revoke` stops syncing and, with `delete_data`, deletes derived data. Per-source consent is required; proposals require approval unless `auto_approve`. **Synced data never changes verified scores.** Content from sources is untrusted data in every prompt.
5. **`export-my-data`** `{}` → `{ signed_url }` (JSON of the student's own rows, 10-minute link). **`delete-my-account`** `{ password, confirm: 'DELETE' }` → `204`: re-verify the password, delete storage objects, delete or irreversibly anonymise the student's rows, revoke grants, write `audit_log` (ids only). Pending access requests become `withdrawn`.

#### C. Projects, review, agents

6. **`assign-project`** (student) `{ target:{skill_slug}|{role_text}, level? }` → `201 { assignment_id, brief }` using the Project Assigner (`agent.md` B4). Errors: `NO_TEMPLATE` (family without templates), `QUOTA_EXCEEDED`, `KILL_SWITCH`, `VALIDATION_FAILED`. Target level = current level + 1 (Competent for new learners); exclude recently assigned templates; seeded variation; similarity re-roll. The brief matches `ProjectBrief` in the student prompt.
7. **`submit-project`** (student) `{ submission_id, confirm: true }` → `202 { run_id, status, mode }`. Validates: ownership; status `draft` or `failed` (retry); `confirm`; at least one skill claimed; **`REQUIRE_VIDEO`** (video object or `video_url`) → `VIDEO_REQUIRED`; storage object size ≤ `VIDEO_MAX_MB`; reported `video_seconds ≤ VIDEO_MAX_SECONDS` → `VIDEO_TOO_LONG`; per-user daily cap → `QUOTA_EXCEEDED`; kill switch → `KILL_SWITCH`. Freezes the submission (`submitted → auditing`), creates `agent_runs(stage='received')`, invokes `audit-submission` without waiting.
8. **`audit-submission`** (internal; service-role only, not callable by users): builds the **evidence bundle** (`architecture.md` §12.4) with **no name, email or university**; signed URLs; GitHub public REST metadata; live URL status; document text; originality questions. Calls the agent adapter; updates `agent_runs.stage` at each step; on timeout (default 8 min) retry once in `direct`; if that fails mark `failed` (**never silently use mock for real students; mock is for demo accounts only**).
9. **`agent-callback`** (hmac) per `architecture.md` §12.3: verify `X-Aptohire-Timestamp` (±300 s) and `X-Aptohire-Signature` over `ts + "." + rawBody` (constant-time compare), reject finished runs (replay), Zod-validate, drop unknown fields, run post-processing (9.4), insert `audits`, call `apply_audit`, write notifications.

#### D. Matching and consent

10. **`extract-job-skills`** (organization) `{ description }` → `{ skills:[{skill_slug,min_level,weight}], title_suggestion? }` (JD Reader; JD text is untrusted data; cached by `input_hash`).
11. **`match-job`** (organization member of the job's org, or internal) `{ job_id }` → `{ status, candidate_count }`. Requires organization `approved` **and** `subscription_status='active'` (else `402 SUBSCRIPTION_INACTIVE`). Runs the pipeline in 9.5, writes `match_results` and `demand_signals`.
12. **`request-access`** (organization) `{ match_result_id, message?, requested_scope: Scope[], duration_days: 7|30|90 }` → `{ request_id }`. Verifies the match belongs to a job of the caller's organization, org active, no pending/accepted request exists, scopes valid; rate limit 20/day per org; notifies the student (`access_request`); `audit_log`.
13. **`respond-access`** (student) `{ request_id, decision:'accept'|'decline', granted_scope?, duration_days? }` → `{ status, expires_at? }`. Own request, `pending`. Accept requires a non-empty `granted_scope` that is a **subset of requested**; `expires_at = now() + duration`. Notify the organization; `audit_log`.
14. **`withdraw-access`** (student) `{ request_id }` → `{ status:'withdrawn' }` for own accepted requests; effects are immediate (views and `reveal-student` stop returning data); notify; `audit_log`.
15. **`reveal-student`** (organization) `{ request_id }` → data **only within `granted_scope`** and only while `accepted` and unexpired: `profile` (name, headline, bio, location, links, current university and verification, avatar as a signed URL), `scorecard` (verified, shareable skills, levels, scores, evidence summary; no raw files), `projects` (titles, descriptions, links, **10-minute signed URLs** for documents/videos), `contact` (email). **Every call writes `audit_log`.** After withdrawal or expiry: `403 GRANT_EXPIRED`.
16. **`submit-feedback`** is **not** a function: organizations insert `feedback` rows through RLS (must be a member of an organization with an accepted-then-expired/accepted request for that student; `option_codes` subset of `feedback_options`; note ≤ 280 chars).

#### E. University

17. **`roster-import`** (university member) `{ university_id, source: {csv_path} | {rows}, mapping?, dry_run? }` → `{ total, valid, invalid:[{row,field,reason}], duplicates, created, updated, matched_existing, proposals_created }`. Validate rows; **hash IDs server-side** (never store raw); upsert on `(university_id, student_id_hash)` or `(university_id, email)`; delete the CSV after processing; allowed for `pending` universities (rows are **locked**: no matching, claiming or proposals until approval). The same function adds a single student (`rows` with one entry). Matching an existing person by verified email or ID hash creates an `affiliation_proposal` (never a new person). Updating `year`/`status`/`program` directly on `roster_entries` (RLS) fires a trigger that updates **only the platform's linked `affiliations`**; the university's roster is the university's.

#### F. Admin (JWT, role admin, **aal2**, every action audited)

18. **`admin-approve-university`** `{ university_id, decision:'approve'|'reject', note? }` — approval sets `status='approved'`, `approved_at`, runs the deferred roster matching (creating proposals/claims), notifies members. **`admin-approve-org`** `{ organization_id, decision, note? }` sets `status`, `verified_at`. **`admin-set-subscription`** `{ organization_id, status:'active'|'inactive' }`.
19. **`admin-review-audit`** `{ audit_id, decision:'confirm'|'adjust', adjusted_scores?, note }` → updates `review_status`, `reviewed_by`, re-applies scoring, clears `pending_review`/sets `share_ok`, refreshes candidate profile, notifies the student.
20. **`admin-decide-ticket`** `{ ticket_id, action:'ack'|'assign'|'decide', assigned_to?, decision?: 'upheld'|'overturned'|'adjusted', note?, adjusted_scores? }`. **Rule: the reviewer who decides must differ from `audits.reviewed_by` of the original review.** Records the reason, writes `rubric_feedback_log`, restores `submissions.status`, notifies the student.
21. **`admin-update-config`** `{ key, value }` for whitelisted keys (`AGENT_MODE`, `PASS_MARK`, `REQUIRE_VIDEO`, `AI_KILL_SWITCH`, `AI_DAILY_CAP_PER_USER`, `VIDEO_MAX_MB`, `VIDEO_MAX_SECONDS`, `BORDERLINE`), validated and audited. **`admin-retry-run`** `{ run_id }`. **`admin-seed-reset`** — **disabled (`403`) when `APP_ENV=production`**; resets demo data only.
22. `admin-view-student` (P2): returns a student's detail **and writes `audit_log`** (sensitive read).

#### G. Cron and internal

`keep-alive` (daily; touches DB, logs), `expire-grants` (hourly; sets `expired`; reads also check `expires_at`), `retention-cleanup` (daily; drafts > 30 d, raw videos > 90 d, expired idempotency keys, stale rate-limit windows), `notify-matching-jobs` (after a candidate projection refresh: notifies organizations of **new matches without identity**).

### 8.9 Error codes (shared; document HTTP status for each)

`VALIDATION_FAILED 422` · `UNAUTHENTICATED 401` · `FORBIDDEN 403` · `NOT_FOUND 404` · `CONFLICT 409` · `ROLE_ALREADY_SET 409` · `ACCOUNT_EXISTS 409` · `RATE_LIMITED 429` · `QUOTA_EXCEEDED 429` · `KILL_SWITCH 503` · `SERVICE_UNAVAILABLE 503` · `SUBSCRIPTION_INACTIVE 402` · `NO_TEMPLATE 422` · `VIDEO_REQUIRED 422` · `VIDEO_TOO_LONG 422` · `MISSING_SKILLS 422` · `GRANT_EXPIRED 403` · `MFA_REQUIRED 403`.

---

## 9. Agent layer

### 9.1 Adapter (`_shared/agents/adapter.ts`)

One interface per agent kind (`audit`, `assign`, `match_reasons`, `jd_extract`, `profile`, `embed`); `AGENT_MODE` from `app_config`, overridable per run by an admin; modes `mock`, `direct`, `n8n` as in `architecture.md` §12.1. All outputs are Zod-validated; one repair retry for malformed JSON; every call writes an `agent_runs` row with mode, status, latency, token estimate, error.

### 9.2 Mock mode (required; deterministic; the default)

Seeded by `hash(input)`; 1–3 s delay; **schema-valid** results for every agent, with realistic template rationales. The **audit mock** uses rubric `web-frontend@1` (Functionality 25 · Code quality and structure 20 · UI, UX and accessibility 15 · Testing and reliability 10 · Documentation 10 · Problem solving and depth 10 · Communication (video) 10), evidence refs that exist in the bundle, a transcript with timestamps, a summary ≤ 600 characters, ≤ 3 next steps. Titles containing `[fail]` fail the run, `[slow]` take 40 s (the student mock does the same; keep behaviours aligned). Mock embeddings are deterministic hash-derived vectors of dimension `EMBEDDING_DIM`.

### 9.3 Direct mode and providers

`providers/` implements Gemini → Groq → OpenRouter with retries and quota-aware fallback (`LLM_PROVIDER_ORDER`), JSON-mode output, model names from env, per-provider daily caps, a global kill switch, per-user daily caps (`AI_DAILY_CAP_PER_USER`, counted from `agent_runs`), and a cache keyed by `input_hash`. **Free-tier providers may train on prompts: only synthetic or consented, redacted data is ever sent.** Implement fully, but test with **stubbed `fetch`**; do not require live keys.

### 9.4 Prompts and post-processing (`agents/prompts/*.md`, versioned)

Create `audit.md`, `assign.md`, `match-reasons.md`, `jd-extract.md`, `profile.md` following the skeletons in `agent.md` Part B; **each has a `prompt_version` stored on the result** (`audit.prompt_version`).

- **All student-provided content (transcripts, READMEs, documents, descriptions, JD text, synced profile text) is untrusted data, wrapped in clearly delimited blocks and never treated as instructions.** Add a mock/stub test with injection strings ("ignore previous instructions…") that must not change scores or leak the prompt; flag `prompt_injection_attempt`.
- **Fairness guards (`agent.md` B3.3) are mandatory in the prompt and in post-processing:** judge the work first; Communication ≤ 10%; **never penalise accent, pace, fluency, camera, lighting or background**; AI-use disclosure is not penalised; insufficient evidence → `insufficient_evidence` and lower confidence (not a guessed low score).
- **Post-processing (deterministic, not the model's arithmetic):** clamp 0–100; recompute the weighted overall from the rubric weights (ignoring `insufficient_evidence` criteria and renormalising); every `evidence_ref` must exist in the bundle (drop fabricated ones and lower confidence); set `borderline` when overall ∈ borderline range; scrub `excerpt` fields; cap lengths (rationale ≤ 280, summary ≤ 600, ≤ 3 next steps).
- **Project Assigner:** the LLM writes wording only, **within** template constraints; it may not change rubric, deliverables or level; no company names, personal data, or paid-service requirements.

### 9.5 Matching pipeline (`match-job`, `agent.md` B5 and `architecture.md` §12.5)

1. Refresh `candidate_profiles` (skills where `share_ok`, bucketed `study_stage`, `uni_category` such as "Tier 2 · University", `scrubbed_summary`, embedding) after each final audit, review decision, visibility or affiliation change. Only `discoverable` students.
2. **Structured match (primary):** per job skill `cover = Σ wᵢ · min(1, scoreᵢ / minScoreForLevel(rᵢ))`; verified skills count fully, unverified count 0.5; apply a coverage floor.
3. **Vector rerank (secondary):** cosine similarity via pgvector (HNSW) among candidates passing the floor.
4. `final = 0.7·structured + 0.3·vector`; `confidence` from audit confidences, evidence count and coverage.
5. **Reasons:** deterministic facts first ("Verified React, Proficient (78)"), then an LLM-worded one-liner constrained to those facts (mock: template).
6. **Alias:** `"Candidate " + base32(HMAC(ALIAS_PEPPER, job_id || student_id))[0:4]`, extended by one character on a per-job collision; stable per job, **not linkable across jobs**.
7. **Demand signals:** when candidates < threshold, per university reason counts: `no_eligible`, `incomplete_assessments`, `insufficient_evidence`, `skills_mismatch`, `opted_out`, `not_assessed` (counts only; no ids).
8. **Scrubbing (before embedding and before any text reaches an organization):** deterministic regex plus a roster-name dictionary pass removing names, emails, phones, URLs, university and company names, locations and handles. **The LLM is never trusted to scrub.** Unit-test with adversarial samples.

### 9.6 Profile Manager (`agent.md` B6)

Deterministic lifecycle rules (no LLM) for roster updates, new rosters (proposals), unregistered moves, graduation. LLM-assisted source sync only with per-source consent, proposals shaped as `ProfileProposal`, approval required unless `auto_approve`.

### 9.7 n8n mode (P2: build last)

`n8n/docker-compose.yml` and exported `workflows/audit.json`, `assign.json`, `match.json`, `profile.json`. The adapter posts an HMAC-signed job; n8n holds **only** `CALLBACK_SECRET` and LLM keys (**never** the database URL, service-role key or user JWTs); media by 10-minute signed URLs; callback signed and verified (8.2 #9). If n8n doesn't ACK within 5 s, retry once in `direct`.

---

## 10. Scoring, lifecycle and notifications (database logic)

- **`apply_audit(audit_id, pass_mark, borderline_low, borderline_high)`** (security definer, called only by functions): for each skill → `level`, `verified = score > pass_mark`; `skill_scores.score` = latest **final** audit score, or a confidence-weighted blend of the last `SCORE_BLEND_N` audits; insert `skill_score_history`; borderline → `audits.review_status='pending'`, `skill_scores.pending_review=true`, `share_ok=false`, submission `needs_review`; otherwise `scored`. Unit-test boundaries at 0, 40, 50, 51, 60, 61, 69, 70, 84, 85, 100.
- **Lifecycle triggers:** roster update → linked `affiliations` update; one `is_current` per student; unverified affiliations never lower scores, discoverability or matches (test).
- **Candidate projection refresh** (function + trigger queue) and `notify-matching-jobs`.
- **Notifications** written by functions/triggers for: `audit_ready`, `review_needed`, `review_decided`, `appeal_update`, `access_request`, `access_expiring` (3 days before), `affiliation_proposal`, `feedback_received`, `source_proposals`, plus staff notifications (applications, tickets). `payload` carries ids and display text only, **no identity for organization-bound notifications**.
- **`audit_log`** is append-only (revoked update/delete) and written for the events in 8.1.

---

## 11. Cron (`pg_cron`, `0014_cron.sql`)

`keep-alive` daily · `expire-grants` hourly · `retention-cleanup` daily · `access_expiring` notifier daily · rate-limit and idempotency purge daily. `scripts/export-snapshot.sh` documents a weekly logical export (human-run; free tier has no managed point-in-time backup).

---

## 12. Seed data (`supabase/seed.sql`; fictional; refuses to run when `app_config.APP_ENV='production'`)

Auth users are created in the seed with a **single, clearly fake demo password documented in `.env.example` as `DEMO_PASSWORD`** (non-production only). Emails use `.test`.

| Entity | Seed |
|---|---|
| Admin | `admin@demo.aptohire.test` (MFA enrolment documented in README) |
| **Uni A** | Tier 2, **approved**, domain `unia.edu.test`; TPO `tpo@unia.edu.test`; roster: Aman (incoming), Ajay (Y1), **Aarav (Y2)**, Akshit (Y3), Aarti (dropout), **Avi (alumnus)** |
| **Uni B** | Tier 3, **approved**, no email domain; TPO user; roster with ID hashes (e.g., `B-1042` = Naman): Nikhil, Neha, **Naman**, Naveen, Nita, **Niya** |
| **Uni C** | **pending** application; roster pre-uploaded but **locked**: Sumit, Sourav, Sam, Shiva, Shruti, Sohan |
| **Uni D** | **not registered** (name text only): Priya (Y2), Adarsh (Y3) with *unverified* affiliations |
| Lifecycle cases | Avi → masters at Uni B (**pending proposal**, scores unchanged after confirm) · Niya → masters at Uni D (unverified) · Aarti → joins Uni B · Nita → none · Sohan works at Org A with a profile auto-maintained from a consented source |
| Logins | `aarav@unia.edu.test`, `naman@demo.aptohire.test`, `avi@demo.aptohire.test`, `niya@demo.aptohire.test`, `tpo@unia.edu.test`, `recruiter@orga.demo.test`, `recruiter@orgb.demo.test` |
| Skills | All families seeded (Web/Frontend: HTML/CSS, JavaScript, React, TypeScript, Accessibility, API integration, Testing · Backend: Node.js, Python, SQL, REST design, Auth · Data: SQL analytics, Python/Pandas, Visualization, ML basics · Management/Commerce: Market analysis, Financial modelling, Project planning, Communication) with `skill_edges`; **project templates and full rubrics only for Web/Frontend** (others return `NO_TEMPLATE`) |
| Pre-scored | **Aarav** React 72 Proficient verified + TypeScript 58 Competent verified (one scored submission with full evidence, transcript, next steps); **Akshit** TypeScript Competent; **Naveen** React 52 **borderline, pending review**; **Avi** SQL Advanced. Evidence comes from mock audits and references **one small shared sample video path** (no real file) |
| Organizations | **Org A = Northwind Labs** (mid-size corporate), **Org B = Brightlane** (start-up), both approved, subscription active, one recruiter each |
| Jobs | Org A: "Frontend Developer (React)", "Frontend Intern (React)". Org B: "Junior Full-stack Intern", "UI Engineer (React)", and "Data Visualization Analyst" with **no matches** (triggers a university demand alert) |
| Consent states (Aarav) | **pending**: Org A · Frontend Developer (profile + scorecard, 30 d) · **accepted**: Org B · Junior Full-stack Intern (expires in ~20 days) · **declined**: Org A · Frontend Intern · **withdrawn**: Org B · UI Engineer |
| Other | A few `feedback` rows, `notifications` (some unread), one open `ticket` on a seeded submission, `placements` (Placed / Not placed / **Unknown** examples), `demand_signals` for the no-match job |

`admin-seed-reset` re-applies this seed and is disabled in production.

---

## 13. Tests (all must exist; run what you can and report honestly)

**pgTAP (`supabase/tests/*.test.sql`)**: for **every row of the RLS matrix**, impersonate each role (`set local role authenticated; set local request.jwt.claims …`) and assert allowed **and** denied counts. Required negative tests:

- Student A cannot read Student B's `students`, `submissions`, `audits`, `skill_scores`, `tickets`, `access_requests`, `notifications`.
- University A cannot read Uni B's `roster_entries`, `affiliations`, students, `demand_signals`.
- Organization **cannot** read `students`, `match_results`, `candidate_profiles`, `affiliations`, `submissions`, `audits`, `skill_scores`, `roster_entries`, or other organizations' jobs directly.
- **`org_candidate_cards` and `org_access_requests_v` return zero identity columns**: verified by column list **and** by a value scan (name, email, photo path, university name, file paths must not appear in any returned value).
- Reveal fields disappear after `withdrawn` and after `expires_at`.
- A user cannot set or change `profiles.role`; cannot update `students.visibility`, `primary_email`, `credential_id`, `skill_scores`, `audits`, or submission status directly.
- `anon` has **no** privileges on any table, view or function (privilege enumeration test).
- Student base-table updates are limited to the allowed columns; student cannot write `agent_runs`.
- Students cannot insert a ticket for someone else's or an unscored submission; only one open ticket per submission.
- `audit_log` cannot be updated or deleted by any role; the Realtime publication contains exactly the allowed tables.
- Storage: owner-only access; no organization or cross-student access; anonymous cannot list.
- `apply_audit` boundaries (section 10); pending-review rows have `share_ok=false` and never appear in `candidate_profiles`.
- `unverified` affiliations don't change scores, discoverability or candidate cards.
- One current affiliation per student; the claim-and-merge transaction creates no second `students` row.

**Deno tests (`deno test -A`)**: Zod schemas; `withHandler` (auth modes, role mismatch, MFA requirement, rate limit, idempotent replay, error shape); HMAC verify (valid, wrong secret, stale timestamp, replay); ID hashing and normalisation; alias stability per job and unlinkability across jobs; scrubbing on adversarial samples; `public-verify` visibility matrix (every combination of shared fields, uniform 404, no extra fields); `submit-application` (honeypot fake success stores nothing, free-mail rejection, rate limits, idempotency, Turnstile on/off); `register-student` outcomes; consent flow (`request → respond → reveal → withdraw → GRANT_EXPIRED`); agent contract tests (schema validity in mock and with stubbed providers; fabricated evidence refs dropped; weighted overall recomputed; injection strings ignored; fairness: same synthetic work with different accent/camera metadata differs by ≤ 3 points); matching pipeline unit tests.

**CI (`.github/workflows/ci.yml`)**: `supabase start`, `db reset`, `supabase test db`, `deno check`, `deno lint`, `deno test`, `secret:scan`. (**Write it; mark as Not run** if you can't execute it.)

---

## 14. Contract export (the frontends depend on this)

`npm run contract:export` produces **`contract-dist/`**:

- `docs/CONTRACT.md` (also kept in `docs/`): **every** table, view, RPC, storage bucket, Realtime table and Edge Function with request/response JSON, auth mode, roles, rate limits, error codes, and **which portal uses it**; the exact view names in 6.2; the evidence/audit/brief/proposal types; a "frozen vs. flexible" marker per item.
- `schemas/*.ts` (Zod) for every function input/output and shared types (`ProjectBrief`, `Audit`, `EvidenceItem`, `ProfileProposal`, `Scope`, application payloads, credential response).
- `database.types.ts` generated from the local schema.

The human copies `CONTRACT.md` (and, if wanted, `schemas/`) into each portal's `docs/`; each frontend states "the contract wins on exact names".

---

## 15. Documentation

`README.md` — beginner-friendly (short sentences, numbered steps): what this repo is; prerequisites (Docker Desktop, Supabase CLI, Deno, Node LTS); `npm run db:start`, `db:reset`, `fn:serve`; how to run tests; demo accounts table (emails only); how to link a **remote** project and push **as a manual, deliberate step** (`supabase link`, `supabase db push`, `supabase functions deploy`, `supabase secrets set --env-file`); dashboard settings to verify (auth URLs for all five hosts, MFA, SMTP, password rules, rate limits, bucket limits, disable unused APIs); free-tier notes (projects pause after inactivity, storage and egress limits, Vercel Hobby is non-commercial); common problems; glossary. `docs/SECURITY_NOTES.md`: assumptions, manual dashboard checklist, known limitations (client-reported video duration, free-tier LLM data use), and a note that a **separate security audit** (the uploaded `Security.md` prompt) will be run later. `docs/RUNBOOK.md`: kill switch, rotating peppers and keys (instructions only), restoring a paused project, export snapshot.

---

## 15A. Additions demanded by the four portal prompts (implement ALL; the frontends already depend on them)

The portal prompts were written after the sections above and each lists backend items it needs. **These are binding additions.** Where one conflicts with an earlier section, this section wins. Document every item in `docs/CONTRACT.md` with the exact name.

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

## 16. Build order (finish each phase, run the checks, then continue)

1. **Foundations:** repo, `config.toml`, `0000_lockdown`, extensions/enums, helpers, `_shared/` framework (`withHandler`, errors, CORS, rate limit, idempotency, audit, config), first pgTAP harness.
2. **Identity and RLS core:** `0002`, student/university RLS, profiles-role immutability, `public_config`, public views, tests.
3. **Skills, projects, audits, scoring:** `0003`–`0005`, `0008` (`apply_audit`), agent mock, `assign-project`, `submit-project`, `audit-submission`, `agent-callback`, `agent_runs.stage`, tickets and appeal trigger, tests.
4. **Student identity functions:** `complete-signup`, `register-student`, `confirm-affiliation`, proposals, roster matching, tests.
5. **Anonymous endpoints:** `public-verify`, `submit-application`, rate limits, tests.
6. **Organizations, matching, consent:** `0006`, blind views, `extract-job-skills`, `match-job`, candidate projection and scrubbing, `request-access`, `respond-access`, `withdraw-access`, `reveal-student`, `rls_visibility.sql`, tests (the most important suite).
7. **University:** `roster-import`, roster triggers, university views, placements, demand signals, tests.
8. **Admin:** approvals, subscription, borderline review, ticket decisions, config, retry, seed-reset, MFA enforcement, tests.
9. **Storage, cron, Realtime:** `0013`–`0015`, retention, expiry, notifications, tests.
10. **Sources and account:** `profile-sync`, `export-my-data`, `delete-my-account`.
11. **Seed and demo:** `seed.sql`, verify every demo state from section 12 with a script that asserts them.
12. **Direct providers and n8n:** providers with stubbed tests, prompts finalised; n8n workflows last (P2).
13. **Contract and docs:** `contract:export`, `CONTRACT.md`, `RLS_MATRIX.md`, README, SECURITY_NOTES, RUNBOOK, CI.

---

## 17. Acceptance checklist

- [ ] `supabase db reset` applies all migrations and the seed cleanly; every demo state in section 12 is asserted by a script
- [ ] Every table has RLS; `anon` has no privileges; grants are explicit; no `select *` views; `security definer` functions have `set search_path = ''`
- [ ] `docs/RLS_MATRIX.md` matches the pgTAP tests one-to-one; all required negative tests exist
- [ ] Blind views return **no identity** (column list and value scan); reveal data disappears after withdraw and expiry; files are reachable only through `reveal-student` signed URLs
- [ ] `profiles.role` cannot be changed by any user; admin functions require `aal2`; no impersonation
- [ ] `public-verify`: uniform 404, renders only shared fields, excludes skills under review; `submit-application`: honeypot, rate limits, idempotency, no login created
- [ ] `register-student` implements all six outcomes with no oracle, no login takeover, and no raw ID stored; claim-and-merge never creates a second person
- [ ] Review pipeline: statuses and `agent_runs.stage` update correctly; failed runs are recoverable; `mock` is never used silently for real students
- [ ] Post-processing recomputes overall deterministically, drops fabricated evidence, flags injection attempts; fairness test passes
- [ ] Pass mark and borderline range are read from config everywhere (none hard-coded in SQL functions or UI-facing logic)
- [ ] Every contract in `docs/FROZEN-CONTRACTS.md` is implemented exactly; any deviation is listed in the report
- [ ] **Every item in section 15A is implemented, named exactly, and documented in `CONTRACT.md`** (views, columns, functions, notification kinds, seed users); an `aal1` admin reads nothing
- [ ] `contract:export` works; `CONTRACT.md` documents every object and which portal uses it
- [ ] No secrets, no PII in logs, fixtures or docs; `secret:scan` clean; seed/reset refuse to run in production
- [ ] README, SECURITY_NOTES, RUNBOOK complete; every `TODO(decision)` listed

---

## 18. Final report (output exactly this at the end)

### ✅ Backend build report

**Stack and versions:** [Supabase CLI, Postgres, Deno, pgTAP, extensions]

**Migrations:** [list with one-line purpose each]

**Edge Functions:** [list; mark frozen-contract ones implemented exactly]

**Views and RPCs (exact names):** [list: these are the names every frontend must use]

**Verification status**
- **Verified (executed):** [commands run and results]
- **Inferred (from code/config):** [items]
- **Not run (and why):** [e.g., Docker unavailable, no network]
- **Manual dashboard steps for the human:** [list]

**Contract deviations from the frontend prompts:** [none, or each with reason]

**Decisions made (`TODO(decision)`):** [each item and default chosen]

**Known limitations:** [e.g., client-reported video duration, free-tier LLM data use, TTL/quotas]

**Files created:** [grouped list]

**What the human should do next:**
1. `npm run db:start && npm run db:reset`, then `npm run db:test` and `npm run fn:test` on a machine with Docker.
2. Copy `contract-dist/CONTRACT.md` into the `docs/` folder of each portal project.
3. When ready, link a **demo** Supabase project and push migrations and functions manually (README steps).
4. Run the separate security audit prompt against this repo.
