# FROZEN CONTRACTS: what the five frontends already implement

> **Place this file at `aptohire-backend/docs/FROZEN-CONTRACTS.md`.** The backend prompt refers to "the frozen contracts", "the frontend contract" and "exactly as in the root/student prompt". **This file is that source.** It was copied verbatim from the five portal prompts.

## How to use this file

1. **Field names, enums, bounds, response shapes and error codes below are binding.** The frontends already validate against them with Zod. Do not rename, reorder or reinterpret them. If you believe something is wrong or unsafe, **do not guess**: implement it as written, add a `-- TODO(decision):` note, and report it.
2. **Server-side rules, security, rate limits, authorization and audit logging come from the backend prompt** (section 8). Where this file only gives a request/response shape, the backend prompt gives the behaviour.
3. If this file and the backend prompt's section 8.2 disagree on a **field name or shape**, this file wins. If they disagree on a **security rule**, the stricter rule wins and you report it.
4. Every function below must appear in `docs/CONTRACT.md` with its exact request/response and the portal that uses it.
5. Text such as "backend project must provide" or "TODO(backend)" in these excerpts is a request addressed to **you**. Treat each as a requirement and mark its status in `docs/DELTA_AUDIT.md` or your final report.

### Common error shape (all functions)

```json
{ "error": { "code": "VALIDATION_FAILED", "message": "…", "fields": { "email": "…" } } }
```

Codes: `VALIDATION_FAILED 422` · `UNAUTHENTICATED 401` · `FORBIDDEN 403` · `NOT_FOUND 404` · `CONFLICT 409` · `ROLE_ALREADY_SET 409` · `ACCOUNT_EXISTS 409` · `RATE_LIMITED 429` (with `Retry-After`) · `QUOTA_EXCEEDED 429` · `KILL_SWITCH 503` · `SERVICE_UNAVAILABLE 503` · `SUBSCRIPTION_INACTIVE 402` · `NO_TEMPLATE 422` · `VIDEO_REQUIRED 422` · `VIDEO_TOO_LONG 422` · `MISSING_SKILLS 422` · `GRANT_EXPIRED 403` · `MFA_REQUIRED 403`.

### Auth conventions

Base URL `${SUPABASE_URL}/functions/v1`. Anonymous functions (`public-verify`, `submit-application`) are called with the public anon key as `apikey` and `Authorization: Bearer <anon key>`. All other functions are called with the signed-in user's JWT. `admin-*` functions additionally require `aal2` (MFA).

---

## A. Anonymous endpoints used by the root site (`aptohire-root`)

#### 4.1 `public-verify` (anonymous, rate-limited, cached)

`GET /public-verify?id=<credentialId>`

`credentialId` is **18 lowercase hex characters** (`/^[a-f0-9]{18}$/`). Validate on the client before calling; invalid format → show the "not found" state without a network call.

Success `200`:

```jsonc
{
  "credential": {
    "credential_id": "a1b2c3d4e5f6a7b8c9",
    "issued_at": "2026-10-12",            // date of the first verified skill
    "last_updated": "2026-10-12",
    "display_name": "Aarav S.",           // OPTIONAL: present only if the student allowed it
    "affiliation": {                      // OPTIONAL
      "label": "Uni A",                   // university name, only if allowed
      "verification": "roster"            // "roster" | "student_id" | "unverified"
    },
    "skills": [                           // may be empty
      { "name": "React", "level": "Proficient", "verified": true,
        "score": 72,                      // OPTIONAL: only if the student allowed scores
        "verified_on": "2026-10-12" }
    ],
    "shared_fields": ["skills", "levels"] // what the student chose to show
  }
}
```

Errors (shape `{ "error": { "code": "...", "message": "..." } }`): `404 NOT_FOUND`, `429 RATE_LIMITED` (with `Retry-After`), `500/503 SERVICE_UNAVAILABLE`.

**The page must render only what the API returned.** Never assume `display_name`, `score` or `affiliation` exist. Never show unverified skills as verified. Parse every response with Zod (`lib/schemas/credential.ts`, `.strict()` off, unknown fields dropped).

#### 4.2 `submit-application` (anonymous, rate-limited, validated)

`POST /submit-application`. Body is a discriminated union on `type`.

```ts
// university
{
  type: 'university',
  institution_name: string,            // 2–120
  short_name?: string,                 // ≤ 30
  kind: 'university' | 'college' | 'school',
  tier: 'tier1' | 'tier2' | 'tier3' | 'other',
  city: string, state: string,
  email_domains?: string[],            // e.g. ["unia.edu.test"], validated as domains
  student_count_band: '<500' | '500-2000' | '2000-5000' | '5000+',
  departments?: string,                // ≤ 200
  contact_name: string, contact_role: string,
  contact_email: string, contact_phone?: string,
  message?: string,                    // ≤ 1000
  consent: true,                       // literal true, required
  hp: string,                          // honeypot, must be ''
  captcha_token?: string,              // only when VITE_TURNSTILE_SITE_KEY is set
}
// organization
{
  type: 'organization',
  org_name: string,                    // 2–120
  org_kind: 'corporate' | 'startup' | 'agency' | 'other',
  size_band: '1-10' | '11-50' | '51-250' | '251-1000' | '1000+',
  website: string,                     // https URL
  hiring_focus: Array<'web_frontend' | 'backend' | 'data' | 'management_commerce' | 'other'>,
  contact_name: string, contact_role: string,
  work_email: string,                  // reject common free-mail domains with a friendly message
  message?: string,
  consent: true, hp: string, captcha_token?: string,
}
```

Headers: `Idempotency-Key: <crypto.randomUUID()>` (one per form instance, regenerated only after a successful submit).

Success `202`: `{ "reference": "AH-7K2Q9F", "status": "received" }`.

Errors: `422 VALIDATION_FAILED` with `{ error: { code, message, fields?: Record<string,string> } }` (map `fields` onto form fields), `429 RATE_LIMITED`, `503 SERVICE_UNAVAILABLE`.

> **Backend responsibilities (not built here, noted for `aptohire-backend`):** create a `pending` university/organization application from this payload, verify captcha if present, rate-limit by IP and email, never create a login, and let the admin portal approve or reject it.

---

## B. Student portal functions and shared types (`aptohire-student`)

### 4.4 Edge Functions (called with the student's JWT; base `${VITE_SUPABASE_URL}/functions/v1`)

All errors have the shape `{ error: { code, message, fields? } }`. Map every code to calm copy (section 9); never show raw messages.

| Function | Request → Response |
|---|---|
| `complete-signup` | `{ portal: 'student' }` → `204`. Sets `profiles.role` once. Idempotent |
| `register-student` | `{ full_name, program_level: 'ug'\|'pg', year?: number, choice: {kind:'detect'} \| {kind:'student_id', university_id, student_id_number} \| {kind:'unregistered', university_name} }` → `{ student_id, outcome: 'verified_roster'\|'needs_student_id'\|'verified_student_id'\|'unverified'\|'confirm_existing'\|'roster_no_match', affiliation?, matched_existing_person: boolean }`. The **raw student ID number is sent only to this function over TLS**; never log it, store it in state after submit, or put it in a URL |
| `confirm-affiliation` | `{ proposal_id }` **or** `{ new: { university_id?, university_name_text?, student_id_number?, program_level, year?, status } }` → `{ affiliation }`. Closes the old affiliation, opens the new one; scores untouched |
| `assign-project` | `{ target: {skill_slug} \| {role_text}, level?: 'Competent'\|'Proficient'\|'Advanced' }` → `201 { assignment_id, brief: ProjectBrief }`. Errors: `NO_TEMPLATE`, `QUOTA_EXCEEDED`, `KILL_SWITCH`, `VALIDATION_FAILED` |
| `submit-project` | `{ submission_id, confirm: true }` → `202 { run_id, status, mode }`. Errors: `VIDEO_REQUIRED`, `VIDEO_TOO_LONG`, `MISSING_SKILLS`, `QUOTA_EXCEEDED`, `KILL_SWITCH`. Also used to **retry** a `failed` submission |
| `respond-access` | `{ request_id, decision: 'accept'\|'decline', granted_scope?: Scope[], duration_days?: 7\|30\|90 }` → `{ status, expires_at? }` |
| `withdraw-access` | `{ request_id }` → `{ status: 'withdrawn' }` |
| `profile-sync` | `{ action: 'github_start' }` → `{ authorize_url }`; `{ action: 'github_sync' \| 'linkedin_parse' \| 'revoke', source_id?, text?, file_path?, delete_data?: boolean }` → `{ proposals?: ProfileProposal[], last_synced_at }` |
| `export-my-data` (**backend to add**) | `{}` → `{ signed_url }` (JSON export) |
| `delete-my-account` (**backend to add**) | `{ password, confirm: 'DELETE' }` → `204` |

Types (`src/lib/schemas/`): `Scope = 'profile'\|'scorecard'\|'projects'\|'contact'`; `ProjectBrief`, `AuditOutput` summary fields and `ProfileProposal` exactly as:

```ts
type ProjectBrief = {
  title: string; scenario: string; level: 'Competent'|'Proficient'|'Advanced';
  target_skills: string[]; deliverables: string[]; constraints: string[];
  suggested_stack?: string[]; estimated_hours: number;
  rubric_preview: { criterion: string; weight: number }[];
  video_guidance: string; originality_questions: string[];
};
type EvidenceItem = { ref: string; kind: 'video'|'file'|'repo'|'doc'|'live'; label: string; pointer: string; excerpt?: string };
type AuditCriterion = { name: string; weight: number; score: number | null; rationale: string; evidence_refs: string[]; insufficient_evidence?: boolean };
type Audit = { id: string; submission_id: string; created_at: string; overall: number; confidence: number; summary: string;
  next_steps: string[]; flags: string[]; borderline: boolean; review_status: 'none'|'pending'|'confirmed'|'adjusted';
  per_skill: { skill_id: string; score: number; criteria: AuditCriterion[] }[];
  evidence: EvidenceItem[]; transcript?: { t: number; text: string }[] };
type ProfileProposal = { source: 'github'|'linkedin_export';
  changes: { field: 'headline'|'skills_interest'|'experience'|'education'|'links'|'project_candidate';
             action: 'add'|'update'; value: unknown; evidence: string }[] };
```

Video evidence `pointer` = seconds as a string; file/repo pointer = `path#Lstart-Lend`; render chip labels as `Video 01:42`, `src/cart.tsx`, `README.md`, `Live site`. Confidence label: ≥ 0.75 **High**, ≥ 0.5 **Medium**, else **Low** (`// TODO(decision)` thresholds).

---

## C. University portal functions and types (`aptohire-university`)

### 4.4 Edge Functions (staff JWT; base `${VITE_SUPABASE_URL}/functions/v1`)

Errors: `{ error: { code, message, fields? } }`. Map every code to calm copy (section 9); never show raw messages.

| Function | Request → Response |
|---|---|
| `complete-signup` | `{ portal: 'university', application_ref?: string }` → `204`. Sets `profiles.role` once (idempotent). If the **verified** email equals an application's contact email (and `application_ref` matches when given) the backend attaches the user to that university. Different role already set → `409 ROLE_ALREADY_SET` |
| `roster-import` | `{ university_id, source: { csv_path } \| { rows }, dry_run?: boolean }` → `ImportReport`. Used for **dry run**, **real import**, and **adding a single student** (`rows` with one entry) |

```ts
type LifeStatus = 'incoming' | 'enrolled' | 'dropout' | 'alumni';   // "Masters" = enrolled + program_level 'pg'
type CanonicalRow = {
  full_name: string; email?: string; student_id_number?: string;     // raw ID travels only to roster-import over TLS
  program?: string; program_level: 'ug' | 'pg'; year?: number; status: LifeStatus;
};
type ImportReport = {
  total: number; valid: number;
  invalid: { row: number; field: string; reason: string }[];
  duplicates: number; created: number; updated: number;
  matched_existing: number;      // COUNT ONLY. Never show which rows or which people.
  proposals_created: number;     // COUNT ONLY
};
```

**Canonical CSV header (what the client sends):** `full_name,email,student_id_number,program,program_level,year,status`. The client maps the user's columns to these, **drops every unmapped column before upload** (data minimisation), and re-serialises. Unmapped columns never leave the browser.

---

## D. Organization portal functions and types (`aptohire-organization`)

### 4.3 Edge Functions (recruiter JWT; base `${VITE_SUPABASE_URL}/functions/v1`)

Errors: `{ error: { code, message, fields? } }`. Map every code to calm copy (section 9); never show raw messages.

| Function | Request → Response |
|---|---|
| `complete-signup` | `{ portal: 'organization', application_ref?: string }` → `204`. Sets `profiles.role` once (idempotent). If the **verified** email equals an application's contact email (and `application_ref` matches when given) the backend attaches the user to that organization. `409 ROLE_ALREADY_SET` if a different role exists |
| `extract-job-skills` | `{ description }` → `{ skills: [{ skill_slug, min_level, weight }], title_suggestion?, nice_to_have?: string[], unclear?: string[] }` (JD text is untrusted; render outputs as text) |
| `match-job` | `{ job_id }` → `{ status: 'ready' \| 'running', candidate_count }`. Requires an approved organization with an **active** subscription (`402 SUBSCRIPTION_INACTIVE`). Rate-limited |
| `request-access` | `{ match_result_id (= candidate_ref), message?, requested_scope: Scope[], duration_days: 7\|30\|90 }` → `{ request_id }`. Errors: `CONFLICT` (already pending/accepted), `RATE_LIMITED` (20/day per organization), `SUBSCRIPTION_INACTIVE`, `FORBIDDEN`, `VALIDATION_FAILED` |
| `reveal-student` | `{ request_id }` → `Revealed` below. Only while the request is `accepted` and unexpired; otherwise `403 GRANT_EXPIRED`. **Every call is audit-logged by the backend**, so call it only when a recruiter opens a revealed candidate, never to render lists |

```ts
type Scope = 'profile' | 'scorecard' | 'projects' | 'contact';
type Revealed = {
  request_id: string; granted_scope: Scope[]; expires_at: string;
  profile?: { full_name: string; headline?: string; bio?: string; location?: string;
              links?: { label: string; url: string }[];
              university?: { name: string; verification: 'roster' | 'student_id' | 'unverified' };
              avatar_url?: string };                       // signed, short-lived
  scorecard?: { skills: { name: string; level: string; score?: number; verified: boolean;
                          verified_on?: string; summary?: string }[] };
  projects?: { id: string; title: string; description?: string; skills: string[];
               live_url?: string; github_url?: string;
               files?: { name: string; url: string }[]; video_url?: string }[];   // signed URLs, ~10 minutes
  contact?: { email: string };
};
```

Render **only the keys present**; if a scope is not granted, show "Not shared" for that section, never an empty fake. Parse with Zod; unknown keys are dropped.

---

## E. Admin console functions and types (`aptohire-admin`)

### 4.3 Edge Functions (admin JWT with `aal2`; base `${VITE_SUPABASE_URL}/functions/v1`)

Errors: `{ error: { code, message, fields? } }`. Map every code to calm copy (section 9); never show raw messages. `403 MFA_REQUIRED` → send the user to the MFA challenge and retry once after success.

| Function | Request → Response |
|---|---|
| `admin-approve-university` | `{ university_id, decision: 'approve' \| 'reject', note? }` → `{ status }`. Approve sets `approved`, runs the deferred roster matching, notifies members. Reject requires a note |
| `admin-approve-org` | `{ organization_id, decision: 'approve' \| 'reject', note? }` → `{ status, verified_at? }` |
| `admin-set-subscription` | `{ organization_id, status: 'active' \| 'inactive' }` → `{ subscription_status }` |
| `admin-review-audit` | `{ audit_id, decision: 'confirm' \| 'adjust', adjusted_scores?: { skill_id, score }[], note }` → `{ review_status }`. Re-applies scoring; clears the hold; notifies the student |
| `admin-decide-ticket` | `{ ticket_id, action: 'ack' \| 'assign' \| 'decide', assigned_to?, decision?: 'upheld' \| 'overturned' \| 'adjusted', note?, adjusted_scores?, criterion? }` → `{ status }`. **The backend rejects a decision by the reviewer who confirmed the original review (`FORBIDDEN`/`CONFLICT`).** `criterion` is optional (rubric log) |
| `admin-update-config` | `{ key, value }` → `{ key, value, updated_at }` for whitelisted keys: `AGENT_MODE`, `PASS_MARK`, `REQUIRE_VIDEO`, `AI_KILL_SWITCH`, `AI_DAILY_CAP_PER_USER`, `VIDEO_MAX_MB`, `VIDEO_MAX_SECONDS`, `BORDERLINE` (`[low, high]`) |
| `admin-retry-run` | `{ run_id }` → `{ run_id, status }` (failed/timeout runs only) |
| `admin-seed-reset` | `{}` → `204`. **`403` when `APP_ENV=production`** |
| `admin-view-student` (P2) | `{ student_id }` → detail; **audit-logged sensitive read**. Build the UI only if the contract provides it (feature flag `FEATURE_STUDENT_LOOKUP`) |

Domain types (`src/lib/schemas/`; mappers adapt to the contract):

```ts
type ApplicationRow = { id: string; reference: string; type: 'university' | 'organization'; subject_id: string;
  subject_name: string; status: 'received' | 'approved' | 'rejected'; subject_status: 'pending' | 'approved' | 'rejected';
  created_at: string; contact: { name: string; role: string; email: string; phone?: string };
  payload: Record<string, unknown>; locked_roster_count?: number; subscription_status?: 'active' | 'inactive'; verified_at?: string | null };
type ReviewItem = { audit_id: string; submission_id: string; submission_ref: string; title: string;
  skills: { skill_id: string; skill_name: string }[]; overall: number; confidence: number; created_at: string;
  review_status: 'pending' | 'confirmed' | 'adjusted'; reviewed_by?: string | null; reviewed_at?: string | null; flags: string[] };
type TicketRow = { id: string; ref: string; submission_id: string; audit_id: string; skill_names: string[];
  original_score: number; reason: string; status: 'open' | 'ack' | 'in_review' | 'decided';
  assigned_to?: { id: string; name: string } | null; original_reviewer_id?: string | null;
  decision?: 'upheld' | 'overturned' | 'adjusted' | null; decision_note?: string | null; created_at: string; decided_at?: string | null };
type AgentRunRow = { id: string; kind: 'audit' | 'assign' | 'match' | 'jd_extract' | 'profile' | 'embed';
  mode: 'mock' | 'direct' | 'n8n'; status: 'queued' | 'running' | 'succeeded' | 'failed' | 'timeout';
  stage?: string | null; attempt: number; latency_ms?: number | null; tokens_in?: number | null; tokens_out?: number | null;
  error?: string | null; model?: string | null; prompt_version?: string | null; submission_ref?: string | null;
  created_at: string; finished_at?: string | null };
type AuditLogRow = { id: string; created_at: string; actor_role: string; actor_id: string; actor_label?: string | null;
  action: string; target_type: string; target_id: string; details: Record<string, unknown> };
```

The review workbench also needs the `Audit` type (summary, `per_skill[]` with criteria `{name, weight, score|null, rationale, evidence_refs, insufficient_evidence?}`, `evidence[]` `{ref, kind: 'video'|'file'|'repo'|'doc'|'live', label, pointer, excerpt?}`, `transcript?: {t, text}[]`, `confidence`, `flags`, `next_steps`, `borderline`, `review_status`, `prompt_version`) and submission fields (title, description, `live_url`, `github_url`, file names, `ai_use` disclosure, `originality_answers`, video path or `video_url`). **Never map or render** the student's name, email, university or `student_id`.

---

## F. Notes on interpretation

- **`submit-application` (A):** the discriminated union on `type` and every field, enum and bound in section A are the contract. Server behaviour (honeypot returns a normal `202` with a fake reference and stores nothing; free-mail rejection for organizations; Turnstile verification when configured; hashed-key rate limits; idempotency; creating a `pending` `universities`/`organizations` row plus an `applications` row; never creating a login) is in backend prompt section 8.2-A.
- **Mock-alignment:** the frontends' mock backends show titles containing `[fail]` as failed reviews and `[slow]` as slow reviews, and use the rubric `web-frontend@1`. The backend `mock` agent mode must behave the same way (backend prompt section 9.2).
- **Names marked "backend to add"** in section B (for example `public_config`, `my_affiliation_proposals`, `export-my-data`, `delete-my-account`) and the views listed in sections C, D and E are required; their full column lists are in backend prompt section 15A.
