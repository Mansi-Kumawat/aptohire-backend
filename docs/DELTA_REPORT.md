### 2026-10-23 continuation — roster grant allowlist assertions

Expanded test `0030_university_projection_security.test.sql` to 17 planned assertions, adding denials for UPDATE on roster identity, owner, and system fields. Together with existing positive grants for the four intended update columns and denials for email, student linkage, and ID hash, this tightens the documented roster update allowlist. Static plan lint passes; SQL remains unrun.

### 2026-10-23 continuation — expanded catalog-level privilege assertions

Expanded pgTAP `0060_rls_catalog_integrity.test.sql` to eight assertions. In addition to public/private table RLS and anon table/view/column denial, it explicitly checks `storage.objects` RLS, anon denial of `private` schema USAGE and sequence privileges, and that no policy directly targets anon or PUBLIC. Static TAP-plan lint passes; SQL remains unrun.

### 2026-10-23 continuation — Realtime publication boundary test

Added `supabase/tests/0064_realtime_publication_membership.test.sql` with three pgTAP assertions for exact publication membership, exclusion of identity-bearing/internal tables, and RLS enablement on every published table. Static numbering/plan lint now passes for 64 contiguous pgTAP tests. PostgreSQL test execution remains unavailable.

### 2026-10-23 continuation — university roster Storage delete behavior

Expanded pgTAP `0048_university_base_row_isolation.test.sql` to 39 planned assertions. It checks the operation-specific Storage delete policy and legacy `FOR ALL` removal, then verifies own-university roster object deletion, cross-university denial for both universities, and denial of unrelated student-video deletion. It also tests roster-row deletion: own-unclaimed deletion succeeds, while claimed-row and cross-university deletion are denied. Static TAP lint passes; SQL remains unrun.

### 2026-10-23 continuation — register-student output contract tests

Expanded `register-student_test.ts` to validate response schema shapes for all six documented registration outcomes and reject unknown outcomes, malformed student ids, and extra fields. This covers the frozen output schema only; handler/database outcome behavior remains unverified and the Deno suite is unavailable here.

### 2026-10-23 continuation — notification source/test traceability

Added `scripts/export-notification-matrix.js`/`npm run notifications:matrix`, which parses the 21 stable notification kinds from prompt §15A and generates `docs/NOTIFICATION_MATRIX.md` with source/test text-match candidates. `npm run check:notifications` verifies exact kind coverage, candidate file existence, and the static-only disclaimer. CI regenerates and diff-checks the artifact; text matches are explicitly not delivery or payload proof.

### 2026-10-23 continuation — notification payload hardening

Expanded pgTAP test `0009_access_consent_transitions.test.sql` from 14 to 16 assertions to verify organization delivery of `access_declined` and that its payload omits student identity. At that historical checkpoint, `match-job`'s `new_match` payload construction was refactored into `_shared/match-notifications.ts`; that helper and its Deno tests were later removed when migration `0099_atomic_match_persistence.sql` moved new-match counting/delivery into the atomic service-only RPC. Current status appears in the Phase 8 atomic match-persistence entry below.

### 2026-10-23 continuation — environment and secret-scan integrity

Added `scripts/check-env-example.js`/`npm run check:env-example` to require the prompt's 39 environment keys and all 21 literal Edge Function environment references in `.env.example`, reject non-placeholder sensitive values, and enforce local/mock/off/loopback-safe operating defaults; three Node tests cover missing names, unsafe defaults, and sensitive-value rejection. Expanded secret scanning to detect common Google/OpenAI/Anthropic/Groq/OpenRouter/Hugging Face provider key formats and added three Node tests spanning LLM, repository, cloud, payment patterns and ordinary placeholders; the tests and scanners run in CI and `check:static`. These improve local hygiene checks but do not validate actual runtime credentials or catch every secret format.

### 2026-10-23 continuation — explicit view columns lint

Added `scripts/check-view-select-star.js`/`npm run check:views` to source-scan migration view definitions and reject unqualified or relation-qualified `SELECT *`, including `DISTINCT` variants. The linter ignores comments and single/dollar-quoted string content. It passed for 41 view definitions across 85 migrations; a temporary `t.*` canary was rejected, and was removed. CI and `check:static` run it. This is source lint only; SQL execution remains the authoritative parser check.

### 2026-10-23 continuation — one-row-per-policy RLS register integrity

`npm run rls:coverage` updates a generated appendix in `docs/RLS_MATRIX.md` that enumerates all 59 source-inventoried policies and lists exact policy-name test mentions plus relation-name candidates. `npm run check:rls-register` verifies all relation/policy pairs appear exactly once and the static-only warning remains; CI and `check:static` run it. This improves traceability but does not establish positive/negative test behavior; the actual RLS matrix remains incomplete.

### 2026-10-23 continuation — migration numbering in static CI check

Extended `npm run test:plans` to validate four-digit migration names and contiguous `0000`–`0084` numbering, 63 contiguous pgTAP files, assertion-plan counts, and exactly one transaction start/finish/rollback in every test. It passes statically; SQL syntax and execution remain unchecked.

### 2026-10-23 continuation — single-command offline checks

Added `npm run check:static` to group the reset guard, admin-AAL2 static check/tests, SECURITY DEFINER lint, pgTAP plan lint, TODO inventory, secret scan, and RLS inventory/candidate generation. End-to-end run passed. SQL/Deno execution is not included.

### 2026-10-23 continuation — admin Edge AAL2 static guard

Added `npm run security:admin-aal2` and `npm run test:admin-aal2` to CI. Static checks passed for all eight present `admin-*` handlers, requiring JWT auth, the `admin` role, and `aal2: true`; negative parser cases reject omitted/invalid gates. This is source lint, not runtime authorization proof.

### 2026-10-23 continuation — guarded local reset and fictional seed

`npm run db:reset` now uses a wrapper that requires explicit `APP_ENV=local|demo`, rejects production/missing/unknown values before launching Supabase, and documents that direct CLI invocation bypasses the wrapper. Added `npm run test:seed-guard` and CI coverage with `APP_ENV=local`; the Node tests pass, and a real production-mode wrapper invocation was rejected before CLI execution. The seed SQL's database-side APP_ENV production check remains as defense in depth. This does not implement the separate admin-console seed-reset function.

### 2026-10-23 continuation — headline contact-data hardening

Migrations `0083_harden_profile_headline_auto_approval.sql` and `0084_reject_arbitrary_headline_domains.sql` reject social handles and bare domains, including uncommon TLDs, as well as explicit URLs, email, and phone patterns. Existing stored content is unchanged. PgTAP `0063` now has 32 assertions, including pending-state and unchanged-profile checks for handles and domains with common or uncommon TLDs. SQL is unrun.

### 2026-10-23 continuation — consent-bound profile-source auto-approval

Migration `0082_safe_profile_proposal_auto_approval.sql` grants authenticated students UPDATE only on their own active source's `auto_approve` column. `persist_profile_proposal` atomically applies bounded `headline` and catalog-resolved `skills_interest` changes only when consent and the preference are active; unsafe headlines and unsupported fields remain pending. No verified score is changed. PgTAP `0063_profile_source_auto_approval.test.sql` has 32 assertions covering owner-only active-source update success, cross-owner and revoked-source denial, verified-score preservation, unsafe handle/domain fallback, and no partial application of mixed safe/unsupported batches. Sohan's fictional consented LinkedIn-export state and `.test` login are added to seed/assertions. Runtime SQL verification remains unrun; unsupported fields remain an explicit gap.

### 2026-10-23 continuation — demo pre-score and proposal cases

Seeded deterministic, completed synthetic audit/submission/score fixtures for Avi (SQL Advanced) and Akshit (TypeScript Competent), plus Avi's pending masters-at-Uni-B proposal while preserving his current Uni A affiliation. `assert-demo-states.sql` now verifies those relationships. Existing 30 human-review and Uni A funnel counts are preserved by mapping two of the 30 human-review fixtures to Avi and Akshit. Seed/assertions now also cover Aarti's Uni B move, Niya's unverified Uni D move, and Nita's lack of a current affiliation. Sohan's consented auto-approved LinkedIn headline fixture is seeded and asserted; SQL reset and assertions remain unrun.

### 2026-10-23 continuation — implementation plan refresh

Rewrote `docs/PLAN.md` to reflect migrations through `0084`, 63 pgTAP files, all 28 Edge Function folders, current verification boundaries, and the concrete unfinished acceptance scope. It distinguishes assistant-executed static checks, prior user-reported runs, and unavailable DB/Deno verification.

### 2026-10-23 continuation — deterministic contract export cleanup

The contract exporter now rebuilds `contract-dist/` from scratch before copying current sources, eliminating stale schema files when a source is removed. A temporary stale-file probe was removed during a successful export. Live database schema and generated types still require local Supabase CLI/DB.

### 2026-10-23 continuation — TODO decision inventory lint

Added `scripts/check-todo-decisions.js` and `npm run todo:decisions` to CI. It verifies every source file with a `TODO(decision)` marker is represented in the maintained decisions inventory; all 10 current source files are listed. Added the prompt's unimplemented admin-invite-member path to the inventory. This does not constitute product sign-off.

### 2026-10-23 continuation — CI pgTAP plan lint

Added `scripts/check-pgtap-plans.js` and `npm run test:plans` as a CI step. It checks contiguous numbering and compares each declared test plan with recognized assertion-call count. Static check passes all 63 current test files and rejected a temporary mismatched-plan fixture. This is not SQL/pgTAP execution.

### 2026-10-23 continuation — trigger-function execute hardening

Migration `0081_revoke_profile_role_trigger_exec.sql` removes inherited direct EXECUTE from PUBLIC, anon, authenticated, and service_role for the trigger-only SECURITY DEFINER role immutability helper. The trigger continues to enforce role immutability through normal profile updates. Test `0062_profile_role_trigger_privileges.test.sql` adds eight behavior/grant/ACL/trigger assertions; SQL remains unrun.

### 2026-10-23 continuation — static SECURITY DEFINER check

Added `scripts/check-security-definers.js` and CI's `npm run security:definers` step. It checks all 88 migration SECURITY DEFINER declarations for an explicitly empty `search_path` and a matching-arity `REVOKE ALL ON FUNCTION` explicitly naming PUBLIC; static scan passes. This is source lint only and does not prove runtime authorization behavior.

### 2026-10-23 continuation — database-level job skill validation

Added migration `0080_validate_job_requirements.sql` with a private strict JSONB shape validator and SECURITY DEFINER trigger on `public.jobs`; malformed keys/types/UUIDs/levels/weights, duplicates, and arrays over 30 items are rejected before reaching matching or aggregate views. Added test `0061_job_requirement_shape.test.sql` with 16 assertions. Static TAP plan count matches; runtime is unverified.

### 2026-10-23 continuation — RLS catalog structural checks

Added pgTAP `0060_rls_catalog_integrity.test.sql` with five catalog-level assertions for RLS enablement on public/private tables, policy-bearing relation RLS, protected private tables, core internal table denial, and enumeration of anon table/view/column privileges across public/private/storage. This is structural coverage and does not satisfy the required per-policy behavioral suite. TAP plan counts and static numbering now match through 60; SQL remains unrun.

### 2026-10-23 continuation — atomic profile-source sync persistence

Added migration `0079_atomic_profile_proposal_sync.sql` and service-only RPC `public.persist_profile_proposal(uuid,uuid,text,jsonb)` to lock and verify the active source before writing profile proposals or advancing `last_synced_at`. `profile-sync` now uses it for GitHub and LinkedIn; external GitHub OAuth/API fetches reject redirects and JSON bodies are bounded. Test `0059_atomic_profile_proposal_sync.test.sql` has 15 assertions for permissions, source matching, field/evidence validation, batch limits, empty sync, and revoked-source denial. Static source ranges/imports and secret scan pass; runtime checks remain unrun.

### 2026-10-23 continuation — direct-audit provider redaction

Extended direct-audit evidence redaction to punctuation-separated student-name tokens, candidate location, current university city/state, and known organization names before text reaches the provider. The database-backed organization dictionary is bounded; if it exceeds the safe bound or fails to load, the local synthetic direct run fails closed. Expanded `_shared/agents/evidence-bundle_test.ts` with location/company canaries; Deno checks remain unrun.

### 2026-10-23 continuation — blind candidate-summary scrubbing

Found that employer cards directly returned `candidate_profiles.scrubbed_summary`, while automatic projection refresh did not produce or sanitize this value. Migration `0078_scrub_blind_candidate_summaries.sql` now derives candidate prose from the latest completed audit on a scored submission, refreshes it as audit/submission state and identity dictionaries change, and applies a private deterministic scrubber on every summary insert/update and legacy-row backfill; it removes known roster names/emails, known locations, universities and organizations, plus URL, phone, and social-handle patterns. Test `0058_blind_candidate_summary_scrub.test.sql` has 20 assertions. The operation is deliberately lossy and is not proof against unknown identifiers or contextual re-identification; SQL remains unrun.

### ✅ Backend delta report

### 2026-10-23 continuation — rubric immutability

Migration `0077_freeze_project_template_rubrics.sql` resolves the template/rubric boundary at the current JSON schema: AAL2 admins may edit non-rubric wording, but cannot insert or change rubric content keys or change a saved `rubric_version`. Test `0057_project_template_rubric_read_only.test.sql` has 7 assertions. Future rubric versions require a reviewed registry/migration; SQL remains unrun.

### 2026-10-23 continuation — employer verified-skill disclosure

A source review found that `org_candidate_cards` included shareable/non-pending but unverified scores in candidate skill details and eligibility. Migration `0076_filter_unverified_org_card_skills.sql` now requires `verified`, `share_ok`, and not pending-review for both the card and returned skill list. Test `0056_org_candidate_card_verified_skill_filter.test.sql` has 7 assertions for verified-only display, unverified-only omission, blind-value scans, and direct-table denial. SQL remains unrun.

### 2026-10-23 continuation — university demand job scoping

Migration `0075_isolate_university_demand_jobs.sql` corrects `university_demand_v` so job counts and latest-posted time exclude pending organizations; demand-reason counts remain limited to the caller's universities. Test `0055_university_demand_view_scope.test.sql` adds 9 assertions for A/B isolation, approved/pending job filtering, and student/anonymous denial. SQL remains unrun.

### 2026-10-23 continuation — university skill aggregate isolation

A source review found `university_skills_v` could include scores from students at other universities because the old `EXISTS` predicate did not restrict the rows being aggregated. Migration `0074_isolate_university_skill_aggregates.sql` scopes inputs to roster-linked students at the caller's university (AAL2 admins see global aggregates) and counts only verified/shareable/non-pending scores in the average. Test `0054_university_skill_aggregate_isolation.test.sql` has 12 assertions for A/B isolation, student denial, admin behavior, and pending-review exclusion. SQL remains unrun; this is a confirmed source-level bug fix, not verified runtime behavior.

### 2026-10-22 continuation — AAL2 admin catalog writes

Migration `0073_aal2_admin_skill_catalog_write.sql` adds AAL2-gated Data API RLS/grants for skill, skill-edge, and project-template maintenance, allows admins to read inactive templates, and writes ID/type/operation-only audit events from a SECURITY DEFINER trigger. Test `0053_aal2_admin_skill_catalog_write.test.sql` now has 18 assertions for AAL1 denial, AAL2 writes, student catalog reads/writes, active-template visibility versus inactive-template denial, and audit. There is no separate rubric relation; follow-up migration `0077` blocks rubric content/version changes inside the JSON while preserving non-rubric template edits. SQL remains unrun.

### 2026-10-22 continuation — safe public jobs projection

The delta requires student/university access to safe public jobs including structured required skills. Migration `0072_public_jobs_approved_org_scope.sql` replaces `public_jobs` compatibly (preserving existing columns and appending `required_skills`) and restricts it to open jobs at approved organizations. Test `0052_public_jobs_safe_view.test.sql` adds 22 assertions for field/role/status boundaries. SQL remains unrun.

### 2026-10-22 continuation — AAL2 admin Storage review access

The prompt requires admins to create signed URLs for videos and documents while preserving private buckets. Added migration `0071_aal2_admin_storage_read.sql`: `admin_review_media_select` permits authenticated `private.is_admin()` callers (AAL2 only) to read object metadata only in `videos` and `documents`; it grants no writes and no access to avatars, resumes, or rosters. Added `0051_aal2_admin_storage_read.test.sql` (11 assertions) for AAL1/AAL2 and bucket/role boundaries. The database test and actual Storage signed-URL flow remain unrun.

**Audit summary:** The current grouped reassessment in `DELTA_AUDIT.md` records **17 Present / 8 Partial / 0 Missing / 0 Conflicts** across the original 25 grouped items. “Present” is implementation status only—not executed verification or acceptance completion. The historical pre-edit baseline counts (0/10/13/2) are retained separately. The report below began as the submit-application report and has accumulated continuation notes; the overall backend remains incomplete.

**New migrations:**
- `0041_submit_application_atomic.sql` — service-role-only idempotency lookup and atomic application submit; creates pending university/organization and received application, idempotency receipt, audit event, and safe admin notification.

**Changed or added functions:**
- Added `supabase/functions/submit-application/index.ts` — anonymous endpoint implementing strict frozen-contract validation, key enforcement/idempotent replay, HMAC rate limits, honeypot fake success, optional Turnstile, free-mail rejection, and atomic RPC persistence.
- Added `supabase/functions/_shared/schemas/submit-application.ts` and `submit-application_test.ts` — strict union schemas, output schema, normalization/business payload helper, free-mail helper, and schema/helper tests.

**New or changed views and RPCs (exact names):**
- `public.lookup_submit_application_idempotency(uuid,text)` — service-role only.
- `public.submit_application(uuid,text,jsonb)` — service-role only, atomic write.
- No views added or changed.

**Compatibility shims kept for existing consumers:** none.

**Verification status**
- **Verified (executed):** `npm run secret:scan` passed. Static Python count confirms 15 pgTAP assertions match `plan(15)`. `unzip -t aptohire-backend-scaffold.zip` passed after rebuilding the archive. These do not validate SQL or Deno runtime behavior.
- **Inferred (from code/config):** the honeypot branch returns before persistence calls; the RPCs are not executable by `anon`/`authenticated`; only the service-role path writes applications; the SQL creates no Auth login. These are source-level observations, not runtime verification.
- **Not run (and why):** `supabase db reset`, `supabase test db`, `deno test -A`, `deno check`, and `deno lint` were not run because Supabase CLI, Deno, Docker, and `psql` are unavailable. `npm run contract:export` has since been executed via the Node exporter and generated the static inventory/schema-source package; live schema dump/types remain unavailable without Supabase CLI/local Supabase. The user reports that all local tests/checks pass after the two reported fixes: the pgTAP test resets role before querying `auth.users`, and response literals in `submit-application` and `submit-project` use `as const`. Exact command output was not supplied, so this remains user-reported rather than independently verified. SQL grammar, migration ordering/runtime, Edge compilation, captcha network behavior, and handler integration have not been verified by the assistant.
- **Manual steps for the human:** On the local Windows development machine with Docker Desktop, Supabase CLI, and Deno installed, run `npm run db:reset`, then `npm run db:test`, `npm run fn:check`, and `npm run fn:test`. Use only `.test` fixtures. Configure `RATE_LIMIT_PEPPER`, and optionally `TURNSTILE_SECRET_KEY`, in the local ignored `.env.local`; never run remote link/deploy/push/secrets commands. Inspect failed output and rerun after any fixes.

**Decisions made (`TODO(decision)`):**
- Idempotency key/body mismatch returns `409 CONFLICT`; the frozen contract requires idempotency but does not specify this conflict status.
- Contact name/role/phone, city/state, and email-domain list bounds are conservative provisional limits marked in the schema; confirm product-facing values.
- Free-mail detection uses a conservative common-provider domain list, including synthetic `.test` aliases for fixtures; extend/review the list before launch.
- When `TURNSTILE_SECRET_KEY` is absent, verification is skipped as explicitly required by the backend prompt.

**Known limitations:**
- No assistant-executed SQL or Deno checks; all new code is unverified at runtime.
- No Edge integration test currently proves rate-limit accounting, Turnstile-on/off, idempotency replay, or no-write honeypot behavior; handler behavior is source-reviewed only.
- The broader backend remains partial; contract export was not regenerated, and many required endpoints/provider modes/security-policy tests remain incomplete.
- Contact data is stored in the restricted `applications` row for review; notifications/audit metadata use only safe ids/reference/type.

**Files created or changed:**
- `supabase/functions/submit-application/index.ts`
- `supabase/functions/_shared/schemas/submit-application.ts`
- `supabase/functions/_shared/schemas/submit-application_test.ts`
- `supabase/migrations/0041_submit_application_atomic.sql`
- `supabase/tests/0024_submit_application.test.sql`
- `docs/FROZEN-CONTRACTS.md`, `docs/prompts/00-aptohire-backend-prompt.md`, `docs/prompts/00b-aptohire-backend-delta-prompt.md`
- `docs/CONTRACT.md`, `docs/RLS_MATRIX.md`, `docs/DELTA_AUDIT.md`, `docs/DELTA_PLAN.md`, `BUILD_REPORT.md`
- `docs/DELTA_REPORT.md`

## Additional implementation slice — `profile-sync` (2026-10-21)

Added migration `0042_profile_sync_vault_oauth.sql`, `profile-sync` Edge Function, strict action/output schemas and Deno schema tests, `0025_profile_sync_vault_oauth.test.sql`, `profile-sync` config, and local OAuth environment variable names. GitHub uses a short-lived, one-use HMAC state bound to student/source; tokens use service-role-only Vault RPCs. GitHub sync reads public profile/repository metadata only. LinkedIn exports accept bounded text or a student-owned CSV/TXT/ZIP source file and produce pending proposals; revocation deletes Vault token and optionally derived proposals. The user reported `db:test` failures in pgTAP assertions 15–16 because this Vault version has no `vault.delete_secret(uuid)` function; migration `0042` now deletes the referenced row from `vault.secrets` within its SECURITY DEFINER RPC, so the failed revoke had rolled back and the subsequent read had not observed revocation. This correction has not been rerun. New SQL/Deno/runtime work is not tested in the assistant workspace. Auto-apply is deliberately disabled pending a safe profile-application workflow. Subsequent additions include an internal demo-only `audit-submission` worker, signed `agent-callback` atomic finalizer, aal2 `admin-retry-run`, audited sensitive-read `admin-view-student`, and daily three-day access-expiry notifier. The user reported test `0028_access_expiring_notifications.test.sql` aborting on `access_request_active_uq` because both fixtures used the same organization/student/job tuple. The second fixture now uses a distinct synthetic job id. The user subsequently reported that all checks and tests passed, including `db:test`; this is user-reported and not assistant-verified. Migrations `0046`–`0047`, tests `0029`–`0031`, the `retention-cleanup` function, and contract-exporter enhancements and migration `0048` (submission project-link fields plus signed document URLs in the frozen reveal response) were added afterward and remain unverified. Migrations `0046`–`0060` and tests `0029`–`0041` were added after the user's report: D1 admin view completion, university projection security assertions, Vault-backed Storage-API raw-video retention with strict object-path validation, project reveal fields, private agent response cache/provenance, global security assertions, 30-day export-file cleanup, and stale-demand-signal cleanup/uniqueness. Direct Gemini/Groq/OpenRouter adapters, local-only JD extraction and assignment wording, provider daily caps, output repair, HMAC cache use, and agent-run logging were added; these are uncompiled and untested. The latest continuation removes synthetic citation of the submission record as evidence, allows empty manifests to finalize only as insufficient-evidence audits, adds a scoring guard, and changes admin retries to start with an empty manifest; migrations `0054`–`0060`, tests `0039`–`0041`, and updated tests `0026`–`0027` are unrun; callback test `0026` now checks the frozen evidence shape and generic injection-flag persistence; shared Deno locator parsing rejects traversal and unsafe URLs; `0059` replaces the keep-alive no-op with a private heartbeat log, covered by unrun test `0041`; `0060` corrects an inverted SQL line-range comparator and updates callback test `0026`. Migration `0061` extends strict demand-reason validation to six categories; `match-job` now counts opted-out, no-eligible, insufficient-evidence, not-assessed, incomplete-assessments, and skills-mismatch populations by current university, including zero candidate-profile results. Test `0042` adds service-grant/reason-shape static checks. Migration `0062` further adds validated admin-configurable match coverage and level score thresholds; `match-job` consumes these values fail-closed, and admin config schemas/view now expose them. PgTAP `0043` and updated schema tests are unrun. These edits are unverified; no tests were run. The exporter attempts a local schema-only dump and reports policy/grant/migration inventory, plus parsed handler auth/role/AAL2/input/output schema metadata and explicitly inferred portal labels. It preserves relative imports for copied contract schema sources. It remains an incomplete static/best-effort export and has not been run. The latest continuation also extracts the matching threshold parser with unrun unit coverage, and hardens `public-verify` to exclude pending-review skills, return 503 on operational query failures, and apply its short cache policy; `_shared/credential_test.ts` is unrun. The user subsequently reports `0034` passes after migration `0063`; `0036` and `0038` failed at their first assertions because pgTAP `has_function(...)` returns text and was nested in `ok(...)`. Both tests now call `has_function` directly. The user should rerun `npm run db:test`; if the parse errors persist, capture `supabase test db --debug`. Only test/documentation files changed after the user's successful reset. The user's subsequent `fn:check` first reported TS2345 in `extract-job-skills/index.ts` because `RATE_LIMIT_PEPPER` narrowing was lost inside a nested async callback; the handler now binds a typed non-optional pepper after the guard. The next run completed type checking but reported five Deno `require-await` lint violations in test mocks; those mocks now return `Promise.resolve(...)` without redundant async keywords. The updated lint fixes remain unverified; no database reset is needed. Major gaps still include complete evidence gathering, direct audit/match/profile pipeline integration, n8n adapters/workflows, admin seed-reset, full generated contract package, CI verification, and checklist completion.

## Continuation — candidate projection synchronization (2026-10-22)

Added forward-only migration `0064_candidate_projection_refresh.sql` and pgTAP test `0045_candidate_projection_refresh.test.sql`. The private security-definer projection helper refreshes shareable skill facts after score changes and after discoverability changes; when discoverability is disabled, it clears skill, study-stage, university-category, scrubbed-summary, and embedding projection data. The test exercises projection creation, score insert/update/delete, opt-out clearing and opt-back-in rebuilding, as well as helper permissions. Client roles cannot directly execute the helper.

Added forward-only migration `0065_affiliation_projection_refresh.sql` and pgTAP test `0046_affiliation_projection_refresh.test.sql`. Affiliation inserts/updates/deletes and related university approval/tier changes now refresh coarse study-stage data and a university tier bucket only when the current affiliation is roster/student-ID verified and the university is approved. The architecture plan records the bucket labels and privacy rule. Both migrations/tests are new and have not been run here. The user reports earlier checks/tests passed, but that report predates these migrations. No SQL or Deno runtime tests were run for this projection slice. Static checks for the full current edit batch are summarized in the latest continuation below. Full acceptance remains incomplete: production-grade evidence assembly/direct audit (including video/audio and live-site modalities), remaining pipeline integrations, n8n, admin seed reset, full contract export and RLS matrix, and final clean-reset verification remain outstanding.

## Continuation — local synthetic direct-audit vertical slice (2026-10-22)

Added `_shared/agents/evidence-bundle.ts` and tests for bounded public GitHub metadata/README and owned UTF-8 text documents, common PII redaction, identity-free refs, no arbitrary URL fetches, and path ownership. Added `_shared/agents/audit-direct.ts` with schema-validated direct provider output, server-owned prompt version, fairness/injection instructions, and hard guards that discard unsupported transcript/visual claims, mark communication insufficient, and withhold all criteria unless at least two distinct manifest refs support at least 50 weighted rubric points. Added `_shared/agents/process-direct-audit.ts`, which is restricted to explicit local synthetic opt-in and `.test` users, uses per-user/per-provider limits, HMAC-keyed cache/provenance, and sends a signed callback; there is no silent mock fallback. `submit-project` now allows this direct mode only under the same local-only gate, and `audit-submission` dispatches the dedicated worker. `postprocess-audit` now scales confidence down when little rubric weight has manifest-backed evidence and scrubs common direct identifiers from generated text. Migration `0066_callback_run_finish_telemetry.sql` also stamps callback-completed `agent_runs` with start, finish, and elapsed timing in the same transaction; test `0026` was extended to assert the receipt.

This remains deliberately incomplete and is not production-ready: no video/audio or live-site analysis, no PDF/binary parsing, only bounded selected repository source/commit metadata (not comprehensive code analysis), incomplete PII scrubbing and evidence-to-skill thresholding outside the local direct guard, no n8n adapter/retry, and no Deno/SQL runtime verification. Static checks for this edit batch passed: secret scan, contiguous migration/test numbering through `0066`/`0046`, TAP markers on all 46 pgTAP files, matching assertion counts in tests `0026` (18), `0045` (8), and `0046` (10), and relative TypeScript import resolution. These checks do not compile or execute SQL/Deno. The updated ZIP was rebuilt after these report/code changes and passed `unzip -t`; the earlier user-reported pass does not cover these additions.

**What the human should do next:** No action is needed yet. Do not deploy this partial backend. When the implementation batch is ready for verification, I will provide beginner-friendly local steps and identify any secrets or dashboard configuration needed.

### 2026-10-22 continuation — university membership roster scope

Found that `university_members` allowed users to see only their own membership rows (plus admins), while the university portal contract calls for access to its own university's membership roster. Added migration `0070_university_membership_scope.sql` to permit membership-row reads scoped to the caller's own university IDs, without exposing other universities. Expanded test `0048_university_base_row_isolation.test.sql` with multiple members per university and assertions for own-university roster access, cross-university denial, student denial, admin access, and policy replacement. The test now has 24 assertions; migration/test are unrun.

### 2026-10-22 continuation — profile-source secret-reference isolation

Found that `profile_sources` granted table-wide SELECT to authenticated users, which made the Vault `token_secret_id` reference selectable through the Data API. Added migration `0069_hide_profile_source_secret_reference.sql` to revoke table-wide browser-role SELECT and grant only safe metadata columns, explicitly excluding the secret reference. Added `0050_profile_source_secret_reference_privacy.test.sql` with six assertions covering column privileges, own/cross-student RLS, and denial of direct secret or wildcard reads. Existing profile-sync queries already use explicit safe column lists. Migration/test are unrun; verify them locally before relying on this protection.

### 2026-10-22 continuation — organization base-table isolation

Found the parallel exposure in `organization_public_or_member`: any authenticated user could read all columns from every approved organization base row. Added migration `0068_organization_base_row_isolation.sql` to restrict base-table reads to own organization members and aal2 admins, retaining the explicit `public_organizations` view as the approved directory. Added `0049_organization_base_row_isolation.test.sql` with 16 assertions for member-only organization and membership rows, cross-organization denial, directory access, student denial, and admin access. Updated the RLS matrix. Migration/test are unrun; local DB verification is required.

### 2026-10-22 continuation — university base-table isolation

Found that the existing `university_public_approved` base-table policy exposed every approved university row to every authenticated user, contrary to the portal boundary. Added forward-only migration `0067_university_base_row_isolation.sql` to remove that broad policy and restrict base-table reads to members of that university plus aal2 admins. The existing `public_universities` security-definer view remains the approved directory surface. Added `0048_university_base_row_isolation.test.sql` with 24 assertions covering member-only university, roster, and own-university membership rows; cross-university denial; approved public-view access; student denial; and admin access; updated `docs/RLS_MATRIX.md`. Migration/test are unrun; do not assume the security change is verified until local DB tests pass.

### 2026-10-22 continuation — core identity authorization test

Added pgTAP test `0047_identity_rls_behaviour.test.sql` and matrix rows covering profile/student self-read, cross-student denial, own-row update, denied cross-student update, no authenticated profile-role update grants, and aal1/aal2 admin gating for admin views and student/profile access. Test now has 42 assertions covering profile/student, affiliation/proposal, and profile-source own/other row isolation, profile-role grants, and aal1 denial across all seven named admin views with aal2 access checks. It is unrun and supplements rather than completes the full RLS policy-to-test matrix. It is unrun and supplements rather than completes the full RLS policy-to-test matrix.

### 2026-10-22 continuation — RLS inventory tooling

Added `scripts/export-rls-policy-inventory.js` and `npm run rls:inventory`. The generated `docs/RLS_POLICY_INVENTORY.md` lists policy definitions after simple source-order create/drop replay and explicit plus statically extractable DO-list RLS-enable statements, and flags policy-bearing relations with no detected enablement (except the Supabase-managed storage relation), and lists pgTAP files that textually mention each policy name; `docs/RLS_MATRIX.md` and README link to it, and CI checks the generated inventory stays current. The text matches are not evidence of behavioral test coverage. This is source-text inventory only, not runtime verification, and does not meet the acceptance requirement for one-to-one pgTAP coverage.

### 2026-10-22 continuation — bounded repository evidence

Extended `_shared/agents/evidence-bundle.ts` to collect a bounded public repository tree, README text, up to three selected source/test/config text excerpts, and commit count/date metadata from GitHub's public REST API. Requests have bounded response sizes and a shared overall deadline; paths reject traversal, unsafe characters, dependency/build/vendor folders, obvious secret/credential filenames, and paths that contain recognizable identity/contact strings. Source text is strict UTF-8 and student identity redaction is applied before excerpts and prompt content are created. Prompt text now keeps only excerpts that fit its character budget, includes claimed skills inside an escaped untrusted-content block, and filters evidence refs to excerpts actually included. `_shared/agents/evidence-bundle_test.ts` now covers source/test and paginated commit metadata collection, traversal/secret-path and identity/contact path filtering, and the shared end-to-end GitHub fetch deadline. `npm run secret:scan` passed when run by the assistant; Deno tests, Deno type/lint checks, SQL, and database tests were not run because the required runtime tools are absent. This is still bounded text evidence, not proof of tests running or code behavior, and all production/acceptance gaps remain.

### Phase 5 anonymous endpoints continuation (2026-10-26)
- Hardened `public-verify` name minimization: single-word names no longer gain a stray space/period; extracted the formatter and added unit cases for multi-word, single-word, and blank names. Existing response filtering still respects each `visibility.public_verify` field and excludes skills unless verified, shareable, and not pending human review.
- Expanded organization free-email rejection to common regional consumer-mail domains (including Outlook/Hotmail/Live, Yahoo, iCloud, Proton, and Yandex variants). The frozen request/response shapes are unchanged.
- Updated `docs/CONTRACT.md` with Phase 5 endpoint behavior, privacy, rate-limits, idempotency, captcha, and remaining verification status.
- Assistant-run `npm run check:static` passed on 2026-10-26. This is repository static validation only; Deno was not installed in the workspace, so `deno test -A` and `deno check`/lint could not be run. No local Supabase/Postgres integration tests were run. The user's earlier report that all checks passed applies to Phase 4 and is not treated as verification of this Phase 5 continuation.

### Phase 5 completion pass (2026-10-26)
- Extracted public credential response construction into `_shared/public-credential.ts`, which allowlists visibility labels and fields, filters the response skill set again, applies date/name minimization, and validates the frozen response schema. Added a complete 32-combination visibility matrix test plus extra-field/date assertions.
- Unified the anonymous endpoints' IP extraction in `_shared/request-ip.ts`, preferring Cloudflare's client IP then valid gateway fallbacks. Added tests for precedence, fallback, and invalid values. Both endpoints now use namespaced HMAC subjects; inability to derive an address fails closed rather than pooling all clients under `unknown`.
- Changed application idempotency ordering so an existing valid receipt replays before charging the IP/email quotas again; new submissions and honeypots remain rate-limited. This preserves useful retries after quota use without changing the frozen receipt or rate windows.
- Expanded regional consumer-email unit cases and updated the contract notes. Deno/pgTAP endpoint and SQL checks remain unrun because Deno, Supabase CLI, and Docker are not installed in this workspace. Static repository validation is run at the end of this pass; do not treat it as runtime verification.

### Phase 6 kickoff — organization matching/consent (2026-10-26)
- The user reports all Phase 5 tests and checks passed; this is user-reported, not assistant-run. Phase 5 is now closed and Phase 6 from the implementation plan is active.
- Extracted deterministic `match-job` requirement scoring into `_shared/match-scoring.ts`; weighted coverage, configured level floors, three-item reason/gap caps, and catalog-name gaps are now testable independently. `match-job` resolves the requirement skill catalog once and uses those labels in the candidate reason/gap output and demand signal slugs.
- Added `_shared/match-scoring_test.ts` for full weighted scores, partial/missing evidence, qualification thresholds, deterministic reasons, and output bounds. This and the earlier Phase 5 changes have not been run through Deno in the assistant environment; per the standing workflow, no Phase 6 tests are run until Phase 6 implementation is complete.
- Updated `docs/PLAN.md` and `docs/CONTRACT.md` to record Phase 6 status. Remaining Phase 6 work includes end-to-end matching/consent reliability and value/authorization coverage; the existing grouped audit still marks `match-job` partial. The kickoff initially changed no contract shape or migration; the continued Phase 6 work in the current pass adds forward-only migration `0094` for atomic access-request creation without changing any frozen frontend contract.

### Phase 6 consent hardening continuation (2026-10-26)
- Added migration `0094_atomic_access_request.sql` and pgTAP `0079_atomic_access_request.test.sql`. The service-only RPC revalidates organization membership/subscription, open-job state, candidate discoverability, candidate-profile visibility, and at least one verified/shareable/non-pending score while locking the job, org, student, profile and eligible score row. It atomically creates the pending request, student notification, and minimized audit event. The Edge endpoint still performs the frozen HMAC rate limit and contact-detail filter before invoking the RPC.
- `request-access` now rechecks live discoverability and an eligible score before the RPC, returning a not-found response for stale/hidden candidate refs and `CONFLICT` for closed jobs.
- `reveal-student` now uses a testable grant-validity helper, records an attempt before scoped reads, revalidates status/expiry/scopes just before returning identity-bearing data, and logs success only after that check. Added helper tests for expiry, scope narrowing, malformed grants, and withdrawal.
- `request-access` eligibility checks and deterministic match scoring have colocated tests. No Phase 6 tests or checks have been run yet, in accordance with the phase-end testing workflow. Runtime verification is not claimed.

### Phase 6 pgTAP fixture correction (2026-10-26)
- User-reported `db:test` failure: `0079_atomic_access_request.test.sql` raised a duplicate key on `candidate_profiles_pkey` before any assertions ran. The student insert trigger already creates the candidate projection row; the fixture now updates that row's `discoverable` flag rather than inserting a second row.
- Assistant-run `npm run test:plans` passed after the correction (95 contiguous migrations; 79 pgTAP plans). The database test itself was not run in this workspace and needs the user's rerun.

### Phase 6 Deno type-check corrections (2026-10-26)
- User-reported `fn:check` found TypeScript narrowing lost for `granted_scope` inside an array callback and widened literal `min_level` values in match-scoring tests. The grant helper now narrows a local array before `.includes`, and the scoring fixture explicitly uses the `MatchRequirement` type, including generated test rows.
- Deno is not installed in the assistant workspace, so these exact local type-check errors were corrected from the reported diagnostics but cannot be independently rerun here.

### Phase 7 kickoff — university contract and roster import (2026-10-26)
- The user reports all Phase 6 checks/tests passed; this is user-reported, not assistant-run. Phase 6 is closed and Phase 7 is active.
- Roster import now follows the frozen source union `{ csv_path } | { rows }` (no backend column mapping), requires canonical `program_level: ug|pg` and `status: incoming|enrolled|dropout|alumni`, normalizes CSV year strings, and leaves unknown columns invalid. Storage paths are restricted to safe university-owned `.csv` paths; object metadata size is checked before download. Duplicate detection now checks both email and HMAC ID hash across rows.
- Added forward-only migrations `0095`–`0096` to add lifecycle enum labels, normalize legacy `student`/degree labels, and update university defaults. `register-student` and `confirm-affiliation` now validate frozen program/status values; `confirm-affiliation` maps legacy DB labels at the API boundary. Synthetic seed program/status data uses canonical values.
- Added tests in roster schema/helper files, university contract helper tests, and pgTAP `0080_university_lifecycle_contract.test.sql`. No Phase 7 tests/checks have been run yet; continue implementation before the phase-end verification handoff.


### Phase 7 implementation completion — university data/roster (2026-10-26)
- Completed the implementation pass without running tests early. Added migration `0097_guard_roster_identity_collisions.sql` to reject a same-university email or student-ID hash collision at the database boundary, including cross-key cases that could otherwise merge separate roster identities. `roster-import` maps the resulting `23505` to a conflict response and maps expected invalid/not-found database codes to stable API errors.
- Corrected synthetic Uni A's `Aman Incoming` fixture to `incoming` and added a demo-state assertion for its canonical program/status, null student link, and seed identity.
- Added pgTAP `0081_roster_identity_collision_guard.test.sql`; updated `PLAN.md`/`CONTRACT.md` counts and frozen roster-import documentation. Phase 7 implementation is now at the final verification checkpoint. Assistant-run `npm run check:static` passed, including the migration/TAP-plan lint (98 migrations, 81 pgTAP plans); Deno and database runtime suites have not been run, so this does not imply runtime test success.


### Phase 7 database test failure correction (2026-10-26)
- User-reported `db:test` reached `0080_university_lifecycle_contract.test.sql` and failed because the test called nonexistent `like(text, unknown, unknown)`; two preceding assertions had passed, but the file exited before fulfilling its four-test plan. Replaced those calls with pgTAP's `matches(...)` assertion using an enrolled-default regex. The assistant reran `npm run test:plans` and it passed for 98 migrations/81 pgTAP files; that static check does not execute SQL. The user must rerun `db:test` to confirm.


### Phase 7 Deno type-check correction (2026-10-26)
- User-reported `fn:check` found the confirm-affiliation handler return inferred as only normalized `program_level`/`status` because the RPC payload was cast to a generic record and spread. The handler now explicitly assembles every frozen affiliation response field and parses it through `ConfirmAffiliationOutputSchema`, preserving the complete inferred output type while normalizing legacy values.
- Attempted assistant-run `npm run fn:check`; this workspace has no Deno binary (`deno: not found`), so the user's function check is still needed to verify the correction and related function files.


### Phase 7 lint correction — roster path validation (2026-10-26)
- User-reported `fn:check` flagged `no-control-regex` for the intentional control-character rejection regex in `roster-utils.ts`. Replaced the regex with a numeric character-code scan (`< 32` or `127`) and added a NUL-path regression assertion without embedding a control character in source. Runtime Deno lint/tests remain unverified in this workspace because Deno is unavailable.


### Phase 7 Deno test fixture correction — duplicate roster identities (2026-10-26)
- User-reported `fn:test` failed because the final “not duplicate” assertion reused `other@example.test`, which the preceding case intentionally records even while reporting a duplicate. The helper correctly tracks both identifiers from duplicate rows; updated the non-duplicate fixture to use a fresh email with a fresh ID hash. Deno is not installed in this workspace, so the user's `fn:test` rerun is required.


### Phase 7 user-reported closeout and Phase 8 kickoff (2026-10-26)
- The user now reports all tests and checks passed after the `0080` pgTAP fix, confirm-affiliation response typing correction, roster path lint correction, and roster duplicate-test fixture correction. Mark Phase 7 closed on this user report; no assistant-run Deno/PostgreSQL result is claimed.
- Phase 8 begins the remaining backend acceptance/readiness work: refresh the itemized section 15A contract and behavioral RLS audit, verify remaining demo-state requirements, then address deferred n8n/reset/live schema-type work and owner decisions. Phase 8 tests remain deferred until the implementation slice is complete.


### Phase 8 first implementation slice — contract package refresh (2026-10-26)
- Ran `npm run contract:export` (a generator, not a test). It regenerated `contract-dist/CONTRACT.md`, `FROZEN-CONTRACTS.md`, `INVENTORY.md`, and 30 schema sources from current migrations/functions. The script could not create `database-schema.sql` or `database.types.ts`: Supabase CLI/local database are unavailable in this workspace.
- Phase 8 remains incomplete. Full 15A/RLS behavioral audit, local demo-state execution, n8n host/secrets/workflows, safe admin reset design, and product-owner decisions still require work or human/environment inputs. No Phase 8 tests were run.


### Phase 8 gap triage (2026-10-26)
- Updated `DELTA_AUDIT.md` against current Phase 7 closeout and Phase 8 scope: static contract package is refreshed; behavioral RLS expansion and full current item-by-item portal audit remain; demo SQL assertions require the local Supabase stack; n8n stays fail-closed pending a complete signed dispatcher/workflow/retry integration; local `db:reset` is already APP_ENV guarded, while hosted admin reset is deliberately not added without a reviewed safe design; outstanding `TODO(decision)` choices require product/security owners.
- Phase 8 is still incomplete. No tests/checks were run in this pass, consistent with the phase-end testing constraint.


### Phase 8 implementation slice — guarded n8n audit dispatch (2026-10-26)
- Added `_shared/agents/n8n-webhook.ts` with HTTPS endpoint checks (rejecting credentials, query/fragment, localhost/private ranges), a 512 KiB payload cap, 5-second ACK deadline, redirect rejection, timestamped HMAC request signing, and no service-role key/JWT in the payload. `process-direct-audit.ts` reuses the existing redacted evidence-bundle and manifest path, records n8n provenance, and dispatches only after the run is claimed and kill switch/mode checks pass. `audit-submission` and `submit-project` now route configured `n8n` audit runs while still requiring fictional `.test` users.
- `admin-update-config` permits `AGENT_MODE=n8n` only when `N8N_AUDIT_ENABLED=true`, a safe HTTPS webhook, >=32-character webhook/callback secrets, and `SUPABASE_URL` are configured. Project assignment and job taxonomy extraction remain deterministic/local under this global mode. Added `_shared/agents/n8n-webhook_test.ts` and updated admin-config unit expectations; tests were added but not run.
- The workflow package, callback timeout monitor, automatic direct fallback/retry, local deployment integration, complete current 15A/RLS audit, and live schema/types remain outstanding. No Phase 8 tests were run.


### Phase 8 continuation — synthetic-only signed n8n dispatcher (2026-10-26)
- Routed configured `AGENT_MODE=n8n` audit runs through a new bounded webhook dispatcher using the existing evidence bundle and callback pipeline. Activation requires `N8N_AUDIT_ENABLED=true`, a public HTTPS webhook URL, HTTPS Supabase callback origin, and >=32-character webhook and callback secrets; defaults remain disabled. Webhook requests reject redirects, sign raw JSON with timestamped HMAC, contain no Supabase service-role key/user JWT, and enforce a 512 KiB payload/5-second ACK bound. Audit dispatch stays restricted to fictional `.test` accounts.
- Under global n8n mode, project assignment and taxonomy extraction remain deterministic/local rather than failing. Added Deno unit tests for endpoint checks, callback origin, signed dispatch shape, bounds and failed ACKs; updated admin-config mode tests. **No tests/checks were run** for Phase 8.
- Still incomplete: checked-in n8n workflow, callback timeout monitor and automatic retry/direct fallback; local end-to-end deployment verification; full item-level 15A and behavioral RLS coverage; clean-reset demo assertions; live types/database schema; owner decisions.


### Phase 8 continuation — n8n stale-callback timeout monitor (2026-10-26)
- Added forward-only migration `0098_n8n_audit_timeout_monitor.sql` and pgTAP `0082_n8n_audit_timeout_monitor.test.sql`. The private service-unexecutable-by-clients function bounds timeout/batch inputs, locks only stale running n8n jobs with `SKIP LOCKED`, marks them failed with a safe timeout code, updates auditing submissions, and is scheduled every minute. It does not fall back to direct automatically; the existing explicit retry path remains the safe recovery.
- Updated current source counts to 99 migrations/82 pgTAP files. No tests were run for Phase 8, as instructed; the new migration and test are unverified.


### Phase 8 reset-scope decision (2026-10-26)
- User approved the existing APP_ENV-guarded local `npm run db:reset` as the demo-reset path. This is the documented deviation from an in-app admin reset; do not add a hosted destructive reset.


### Phase 8 continuation — checked-in n8n audit workflow package (2026-10-26)
- Added `n8n/workflows/audit.json`, an inactive importable workflow that verifies the signed webhook and timestamp before ACK, requests a strict JSON audit from an operator-configured OpenAI-compatible endpoint, validates/deduplicates criterion/evidence references, and signs the existing callback contract. Added pinned `n8n/docker-compose.yml` bound to loopback with required auth/encryption/secret settings and `n8n/.env.example` with placeholders only. Workflow success/error execution storage is disabled; no keys or service-role values are committed.
- Workflow import, n8n-version compatibility, provider integration, webhook callbacks, and deployment are unverified. Automatic direct fallback is not implemented; the new SQL timeout monitor fails stale jobs visibly. No tests/checks were run for Phase 8.


### Phase 8 n8n fallback constraint (2026-10-26)
- A failed or late n8n webhook ACK now falls through to the existing direct audit path only for fictional `.test` accounts when `APP_ENV=local` and `LLM_ALLOW_SYNTHETIC_DIRECT=true`. Production and post-ACK callback-timeout fallback remain disabled; the timeout monitor marks the run failed for explicit retry. No tests/checks were run.


### Phase 8 continuation — University trends cohort coverage source (2026-10-26)
- Added pgTAP `0083_university_trends_cohort_isolation.test.sql` for the 26-week shape, exact trend columns, identity-column exclusion, per-university registration isolation, student denial, and AAL1-admin denial. This is newly added source coverage only; it has not been run.
- The grouped section 15A audit previously noted only column-shape/value-scan coverage for trend data; the new behavioral fixture addresses that specific gap, pending the single Phase 8 end-of-implementation test handoff.


### Phase 8 continuation — cohort funnel/overview behavior tests (2026-10-26)
- Added pgTAP `0084_university_cohort_views_isolation.test.sql`: verifies the frozen funnel and overview columns, absence of student identity fields, A/B cohort totals, unclaimed versus registered roster counts, activity count scope, and denial to a student with no university membership. New source coverage only; it has not been run.
- At this point in the Phase 8 timeline the test inventory contained 84 pgTAP files. It has since advanced to 87 files; no Phase 8 tests/checks have been run.


### Phase 8 demo-default decision (2026-10-26)
- User approved the current `TODO_DECISIONS.md` defaults for demo-only behavior. Updated the inventory to record that approval while explicitly leaving hosted/production review open.

### Phase 8 continuation — guarded reset runs demo assertions (2026-10-26)
- Updated `scripts/db-reset.js`: after the explicitly local/demo guarded `supabase db reset` succeeds, the wrapper now runs `scripts/assert-demo-states.js` and fails the command if any expected demo state is missing. Direct CLI reset remains discouraged; no hosted project is targeted. Updated README and runbook wording; `db:assert-demo` remains available for a separate rerun.
- This is implementation only. No Phase 8 tests or local reset were run in this workspace.

### Phase 8 continuation — employer job grants and organization-view isolation (2026-10-26)
- Expanded `supabase/tests/0052_public_jobs_safe_view.test.sql` with exact `information_schema.column_privileges` assertions for the full jobs INSERT and UPDATE allowlists, plus behavioral membership checks proving `my_organization_v` includes the caller's organizations but excludes another approved organization. The pgTAP plan is now 27. Updated the RLS matrix and audit notes.
- Implementation/source coverage only; no tests or checks were run.

### Phase 8 continuation — reveal-student storage-key validation (2026-10-26)
- Added `_shared/reveal-storage.ts` with exact student/submission-prefix validation for signed document and demo-video objects. `reveal-student` now rejects invalid keys before requesting 10-minute signed URLs. Added Deno unit test source for cross-student/submission paths, traversal/subdirectory names, invalid video names, and filename bounds.
- No tests or type checks were run. Storage SDK signing itself still needs local integration verification.

### Phase 8 continuation — organization access-request view isolation (2026-10-26)
- Extended `supabase/tests/0021_org_blind_value_scan.test.sql` with a second approved but non-member organization and its own job/match/request fixtures. The organization-scoped blind request view must exclude that other organization's request. The pgTAP plan is now 8. Updated the RLS matrix and delta audit.
- Source/test implementation only; no tests or checks were run.

### Phase 8 continuation — freeze notification-kind database contract (2026-10-26)
- Added pgTAP `0085_notification_kind_contract.test.sql` to assert all 21 frozen notification kinds are accepted, the stored set exactly equals the contract, and unknown kinds are rejected. Updated the current pgTAP count to 85 and the notification coverage status. Producer-to-payload behavior for every kind remains a separate gap.
- No tests or checks were run.

### Phase 8 continuation — exact employer-view output contracts (2026-10-26)
- Expanded pgTAP `0004_org_delta_contract.test.sql` from 10 to 13 assertions. It now checks exact column names and order for `my_organization_v`, `org_candidate_cards`, and `org_access_requests_v`; updated RLS and delta-audit mappings.
- Source/test implementation only; not run.

### Phase 8 continuation — exact university analytics view contracts (2026-10-26)
- Strengthened pgTAP assertions in `0054` and `0055` from expected-column presence/counts to exact frozen column order for the skills and demand views. Did the same for trend, funnel, and overview views in `0083`–`0084`. Assertion counts are unchanged.
- Source/test implementation only; no SQL tests or checks were run.

### Phase 8 continuation — exact university member and roster view contracts (2026-10-26)
- Expanded `0003_delta_contract.test.sql` from 12 to 15 assertions. It now verifies exact frozen output-column order for `my_university_v`, `university_students_v`, and `university_student_skills_v`. Updated the RLS and delta audit mappings. The analytics-view tests `0054`–`0055` and `0083`–`0084` now likewise assert exact column order.
- Source/test implementation only; no SQL/Deno checks were run.

### Phase 8 continuation — demo reset runtime-mode assertions (2026-10-26)
- Strengthened `scripts/assert-demo-states.sql`: a successful guarded reset must leave the seeded `AGENT_MODE=mock` and `AI_KILL_SWITCH=false` values, in addition to the existing fictional fixture assertions. Updated the current audit note. No local reset or tests were run.

### Phase 8 continuation — full university analytics metric fixtures (2026-10-26)
- Expanded `0083` to populate one synthetic audit and verified skill, then assert current-week registration, review, and cumulative verified counts are isolated to University A and absent for University B; it also tests university profile/skill view member scoping (plan: 21). Expanded `0084` to assert cohort year/program/status rows, own-university/unclaimed roster projection, student denial, and all nine overview values (plan: 27). Updated `RLS_MATRIX.md` with explicit overview/funnel/trends entries and corrected the `0052` assertion count.
- No tests or checks were run; university analytics source coverage is now recorded as present, subject to local execution.

### Phase 8 continuation — member-scoped university profile view behavior (2026-10-26)
- Extended `0083_university_trends_cohort_isolation.test.sql` to verify `my_university_v` returns exactly the caller's own university, excludes the other university, and is empty for an unrelated student and an AAL1 admin. Further expanded the same plan to 22 with own-university skill-view allow/deny assertions for university A/B, unrelated student, and AAL1 admin, plus pending-review exclusion. Updated the RLS/delta audit maps.
- No tests or checks were run.

### Phase 8 continuation — test guarded reset sequencing
- Refactored `scripts/db-reset.js` to expose a small injectable command-sequencing helper and added Node test source confirming demo assertions run only after a successful local reset, and are skipped when the reset command fails or cannot launch. CI step label updated accordingly.
- No tests were run.

### Phase 8 continuation — manual notification behavior audit
- Manually reviewed the producer event tests for all 21 stable notification kinds. Added a per-kind evidence table to `NOTIFICATION_MATRIX.md`, covering trigger/handler test source and the delivery, identity-minimization, aggregation, idempotency, or count-only assertion where applicable. The new `0085` database contract test covers the exact allowed-kind set. Updated the current grouped status to Present; this is source review only, not test execution.

### Phase 8 continuation — bounded reveal signed-URL helper
- Consolidated avatar/document/video signing through `createRevealSignedUrl`, with a fixed 600-second TTL and suppressed storage error details. Extended the Deno test source to cover TTL and error behavior alongside the previously added path checks. This improves the signed-link source contract; it is not a substitute for local Supabase Storage integration tests.
- No Deno tests or checks were run.

### Phase 8 continuation — precise borderline demo queue assertions
- Extended `scripts/assert-demo-states.sql` to require five pending synthetic audits inside the approved 40–60 borderline interval, with exactly four recent fixtures and one at least ten days old. This complements the reset-mode assertions; no local reset or tests were run.

### Phase 8 continuation — stricter match-job schemas
- Expanded `match-job_test.ts` source coverage to accept both frozen statuses, reject negative counts and unexpected identity fields in output, and reject unexpected identity fields in required-skill input. Tests remain unrun; no full mocked end-to-end matching test was added.

### Phase 8 continuation — fixture account role assertions
- Strengthened `scripts/assert-demo-states.sql` to verify that all 15 expected `.test` demo Auth accounts map to their exact student/university/organization/admin portal roles, not merely that the accounts exist. No reset or tests were run.

### Phase 8 continuation — organization membership row isolation
- Expanded `0052_public_jobs_safe_view.test.sql` with a second synthetic organization user and verifies the caller cannot read that user's membership row outside its own organizations. The assertion plan is now 29; RLS/audit notes updated. No SQL tests were run.

### Phase 8 continuation — public jobs projection contract
- Expanded `0052_public_jobs_safe_view.test.sql` to assert exact `public_jobs` column names/order, and raised its plan to 30 assertions. Updated RLS/audit references; no SQL tests were run.

### Phase 8 continuation — job requirement update validation coverage
- Expanded `0061_job_requirement_shape.test.sql` to cover both accepted and rejected `required_skills` updates in addition to insert cases; the TAP plan is now 18. This exercises the trigger's `UPDATE OF required_skills` path. No SQL tests were run.

### Phase 8 continuation — idempotent new-match notification counts
- At that historical checkpoint, extracted `countNewMatchStudents` into a shared helper and used it in `match-job`. That helper and its Deno test were later removed when the counting and writes moved into `persist_job_matches` in migration `0099`, with pgTAP coverage in `0086`; neither the SQL nor Deno suites have been run in this workspace.

### Phase 8 continuation — atomic match persistence (2026-10-26)
- Added forward-only migration `0099_atomic_match_persistence.sql` with service-only `persist_job_matches`: it validates exact row keys/types/bounds, confirms active approved organization membership and an open job, locks the job row and share-locks organization/membership state, locks eligible student rows in stable ID order while rechecking live discoverability, upserts match rows, counts only genuinely new students, enqueues identity-free count-only `new_match` notifications, and writes the audit event in one transaction.
- Replaced `match-job`'s separate existing-match scan, direct upsert, notification insert, and audit insert with the RPC call, and validates both RPC counts. Added `0086_atomic_match_persistence.test.sql` with 20 pgTAP assertions covering service-only grant, active organization/open-job gates, initial delivery/payload and cross-organization exclusion, idempotent rerun, empty and non-array batches, strict value types, malformed/duplicate rows, stale discoverability opt-out rejection, and non-member rejection. Updated `PLAN.md`, `NOTIFICATION_MATRIX.md`, and `RLS_MATRIX.md`; regenerated the static contract/RLS inventories after `0099`; removed the obsolete standalone notification helper/test and the standalone testing guide per user instruction.
- The repository source inventory currently has 100 contiguous migrations (`0000`–`0099`) and 87 pgTAP files (`0001`–`0087`). No tests or checks were run. The migration, fixture assumptions, and handler remain unverified; Phase 8 remains incomplete.

### Phase 8 continuation — n8n callback and payload boundaries (2026-10-26)
- Hardened `_shared/agents/n8n-webhook.ts`: callback bases must be clean public HTTPS origins, signed callback URLs must use the exact `agent-callback` path with no credentials/query/fragment, and obvious private/local IPv4/IPv6 destinations are rejected. Preserved exact callback URL construction by the submit-project flow. Added Deno test source for private IPv6/local callback rejection, wrong callback paths, and the 512 KB body cap before network I/O.
- Set n8n's container webhook payload cap to 1 MB, slightly above the service-side 512 KB cap, in `n8n/docker-compose.yml`; documented both bounds. n8n import/runtime and Deno tests remain unrun. This destination validation blocks obvious literal private addresses but cannot detect public DNS names that resolve to private addresses; production egress restrictions/DNS controls remain necessary.

### Phase 8 continuation — keep curated notification evidence across regeneration (2026-10-26)
- Updated `scripts/export-notification-matrix.js` to regenerate the 21-kind static source/test candidate table while preserving the manually reviewed runtime-verification and behavioral-evidence sections. Extracted the pure merge logic into `scripts/notification-matrix-output.js`, added two Node test cases in `notification-matrix-output.test.mjs`, and wired them into `check:static`. Regenerated the matrix after the atomic `new_match` producer moved to migration `0099`; current static scan finds all 21 kinds in producer and test source. These are text matches only and not behavior verification. No tests/checks were run.

### Phase 8 continuation — organization pipeline-stage RLS behavior source coverage (2026-10-26)
- Added `0087_access_request_pipeline_rls.test.sql` with 31 planned assertions for migration `0088`'s narrow `access_requests` read columns and accepted/unexpired organization-only visibility, plus the existing pipeline-stage UPDATE policy. The source covers cross-organization, pending, expired, and non-organization denial; row-stage updates; and denial of identity columns, wildcard reads, and status changes. SQL remains unrun; this covers the pipeline-stage cells, not the remaining policy-by-policy audit.
- Refreshed static RLS candidate inventory to include the new fixture. No tests/checks were run.

### Phase 8 continuation — bind reveal key validation to signed-URL creation (2026-10-26)
- Added `createSafeDocumentRevealFile` and `createSafeSubmissionVideoRevealUrl` so ownership/name validation and short-lived URL creation are one helper path; `reveal-student` now calls those helpers rather than validating and signing in separate inline blocks. Deno source tests assert invalid paths never reach the Storage bucket mock and valid keys use the 600-second TTL. This closes a source-level gate gap, not real Storage SDK integration; tests remain unrun.

### Phase 8 continuation — scoped data-export signing and cleanup (2026-10-26)
- Added `_shared/export-storage.ts` so `export-my-data` signs only safe owner-scoped UUID object keys, fixes TTL at 600 seconds, suppresses Storage errors/throws, and uses bounded best-effort cleanup if upload, signing, or subsequent audit logging fails. Prior-export listing/removal exceptions are also handled as best-effort so cleanup cannot invalidate the successful new download. Added fake-bucket Deno test source for path/TTL/error/cleanup behavior and wired the handler through the helper. No tests were run; real Storage SDK behavior remains unverified.

### Phase 8 continuation — n8n source-boundary guard (2026-10-26)
- Added `scripts/check-n8n-workflow.js` and wired `npm run n8n:check` into `check:static`. It source-checks the workflow remains inactive, contains no embedded credentials or obvious static provider token, names/IDs/connections are coherent, HMAC verification precedes a 202 ACK and provider call, n8n Code nodes use `$env` secrets rather than `process.env`, HTTP redirects are disabled, execution data is not saved, and Compose keeps auth/loopback/payload settings. This is a static source guard, not workflow import/runtime verification. `dispatchN8nAuditJob` now revalidates the endpoint itself against the supplied `APP_ENV` even though the caller also checks it, with test source rejecting private endpoint targets before network I/O.
- An accidental invocation during documentation shell quoting ran the new guard once; it failed because the first version incorrectly required a terminal node to have a connection entry. The guard was corrected to allow the explicit terminal node and was not rerun. No SQL/Deno or other tests/checks were run.

### Phase 8 continuation — active student-template read positive case (2026-10-26)
- Expanded `0053_aal2_admin_skill_catalog_write.test.sql` to 18 planned assertions with an active-template fixture and student positive-read assertion alongside inactive-template denial. This strengthens behavior coverage for `student_templates_read`; SQL remains unrun. No tests/checks were run.

### Phase 8 continuation — n8n guard and catalog read scope notes
- Reconciled the current RLS matrix with the `0053` active/inactive template positive/negative assertions, and retained the corrected n8n terminal-node guard status. No SQL/Deno tests or checks were run this turn.

### Phase 8 continuation — Storage SDK request-path coverage
- Added `_shared/export-storage_sdk_test.ts`: constructs the real Supabase Storage SDK client with an isolated fake `fetch`, then exercises the owner-path-validated 600-second signed URL request and safe delete request (method, endpoint, body), including a traversal path that must not reach fetch. This adds SDK-level request-contract coverage without contacting a live project. The test source is unrun; actual local Storage API behavior remains unverified.
- Added `_shared/export-storage_local_integration_test.ts`, an opt-in actual Supabase Storage integration test that requires `APP_ENV=local`, a clean HTTP loopback origin (`localhost`, `127.0.0.1`, or `[::1]`) with no credentials/path/query/fragment, and local service-role credentials. A pure guard test rejects remote and malformed origins. It writes a uniquely named synthetic JSON object, signs/fetches it, verifies the returned signed URL origin exactly matches the configured loopback origin before fetching, and cleans it up in `finally`; remote URLs are ignored rather than contacted. This source has not been run.

### Phase 8 continuation — close student Storage DELETE policy behavior gap (2026-10-26)
- Expanded `0071_student_storage_rls.test.sql` from 10 to 30 assertions. It now covers own/other reads across videos, documents, avatars, and resumes; own/other inserts for videos/documents/resumes plus canonical-avatar-path denials; update rekey and exact-avatar-path immutability; and own/other DELETE policy behavior for videos, avatars, and resumes. Only the `storage.protect_delete()` trigger is temporarily disabled inside the rollback-only pgTAP transaction to isolate DELETE RLS, then restored before verifying the production API-only delete safeguard. SQL remains unrun.
- Extended `0048_university_base_row_isolation.test.sql` from 48 to 53 planned assertions with own-university positive and cross-university negative DELETE and update rekey tests for roster Storage objects. Like `0071`, it disables only the `storage.protect_delete()` trigger within the rollback-only test to isolate DELETE policy behavior, then restores the trigger. SQL remains unrun.

### Phase 8.A continuation — full catalog-policy CRUD source coverage (2026-10-26)
- Expanded `0053_aal2_admin_skill_catalog_write.test.sql` from 18 to 39 planned assertions. It now exercises AAL2 skill/edge/template create-update-delete paths, AAL1 denials for update/delete (in addition to existing insert denials), and AAL1 inactive-template read denial while confirming active-template access. It also verifies student insert/update/delete denials for skills, skill edges, and active templates while retaining taxonomy reads and active-only template access. It also confirms skill-edge reads are restricted to AAL2 admins. SQL remains unrun.

### 2026-10-27 verification handoff attempt
- Assistant-run `npm run check:static` passes after correcting the n8n workflow node-options placement and narrowing notification-matrix row parsing to generated rows only. It includes the static/unit source checks listed in `BUILD_REPORT.md`; it does not execute SQL or Deno behavior.
- Attempted `npm run db:test`, `npm run fn:check`, and `npm run fn:test`; all could not start (`supabase: not found`, `deno: not found`). Docker/psql are unavailable too. No local reset, pgTAP, Deno tests/typecheck, live schema/types, or n8n import/runtime result is claimed.

### User-run `db:test` failure analysis and forward-only fixes (2026-10-27)
The attached local run reached all 87 SQL test files and reported failures in tests `0048`, `0052`, `0071`, `0083`, `0085`, `0086`, and `0087`:
- `0048`/`0071`: the tests attempted to disable Supabase Storage's delete-protection trigger, but the pgTAP role does not own `storage.objects`. Removed those unsafe trigger toggles and direct SQL DELETE expectations; retained the Storage DELETE-policy metadata checks and the API-only trigger guard. Updated plans to 49 and 24 assertions respectively. Actual Storage API deletion behavior remains for the local SDK integration path.
- `0052`: removed an unescaped apostrophe from a pgTAP description string that broke SQL parsing.
- `0083`: added forward-only migration `0101_grant_university_trends_view.sql` to grant the member-scoped aggregate view to authenticated users, and added the missing roster fixture required by `university_student_skills_v`'s roster join.
- `0085`: fixed the `unnest` output alias in the frozen notification-kind comparison.
- `0086`: replaced unsupported `jsonb_object_length` in a forward-only correction migration `0100_fix_match_jsonb_key_count.sql` using a count over `jsonb_object_keys`; changed the invalid `draft` job status fixture to valid non-open `closed`.
- `0087`: gave pending and expired access-request fixtures distinct jobs so they do not violate the active-request uniqueness constraint.
These changes are not rerun; the local project must run a guarded `npm run db:reset` before `npm run db:test` so migrations `0100` and `0101` are applied. Do not share service-role keys or `.env.local`.

### Follow-up after the attached local DB run
- Corrections above are in the workspace. I reran `npm run check:static`: it passes, with static plan integrity reporting 102 contiguous migrations and 87 pgTAP files. This is not a rerun of `db:test` and does not prove these SQL corrections execute successfully.
- `npm run contract:export` refreshed the static inventory (153 SQL object names, 28 function folders, 30 schema sources). Live `database-schema.sql` and `database.types.ts` were not generated because Supabase CLI/local DB are unavailable here.
- Required next local sequence after downloading the updated archive: `npm run db:reset` (APP_ENV must remain local; this resets the local DB and applies migrations `0100`/`0101`), then `npm run db:test`. The 0048/0071 direct SQL DELETE behavior probes were removed because the test role cannot own/disable the platform Storage trigger; the actual Storage API path must be exercised by the loopback-only SDK integration test instead.

### Follow-up to the second user-run `db:test` (2026-10-27)
The user's second output shows only `0086_atomic_match_persistence.test.sql` failing; all other 86 files reported `ok`. The first two `select is(...)` calls around nested `jsonb_build_array(jsonb_build_object(...))` were each missing one closing parenthesis for the scalar subquery, causing the parser error at the expected-value `array[...]`. Added the missing parentheses to both calls. `npm run test:plans` passes locally for 102 migrations/87 TAP files; this does not parse/execute SQL, and the database suite has not been rerun after the fix.

### User-run `fn:check` lint correction (2026-10-27)
The user reported Deno `require-await` for `createSafeSubmissionVideoRevealUrl` in `_shared/reveal-storage.ts`. Removed the unnecessary `async`; invalid paths now return `Promise.resolve(null)` without calling Storage, and valid paths return the existing signing promise directly. This preserves the helper contract and does not change runtime policy. Deno lint/typecheck was not available here; user rerun is required.

### User-reported local Deno test completion and n8n provider-endpoint guard (2026-10-27)
- The user reports the Deno test suite passes after correcting the local Storage credentials; this is user-reported, not independently run here. A previous run showed the loopback Storage integration test was ignored without local env and later failed with an invalid Compact JWS when a malformed service-role value was supplied.
- Continued 8.C source hardening: the n8n workflow's pre-ACK verifier now validates the operator-configured chat-completions URL as HTTPS with no credentials/query/fragment, default HTTPS port, a `/chat/completions` suffix, and rejects obvious literal-IP/local/reserved test hostnames. DNS resolution pinning and network egress controls remain deployment-level requirements. Static guard assertions were updated; the guard has not been rerun after this edit, and workflow import/runtime remains unverified.
- CI now runs the loopback-only Storage SDK integration instead of allowing it to silently skip: it sources `supabase status -o env`, verifies the Supabase API URL is loopback and service-role key has compact-JWT structure, then runs `fn:test` with the required local env. Added the `n8n:check` source guard to CI. README now documents the env gate and no-hosted-key rule. CI YAML has not been executed here.
- Follow-on 8.C hardening adds an explicit exact-host `N8N_LLM_ALLOWED_HOSTS` variable to the n8n host `.env` template/Compose config. The pre-ACK verifier requires the parsed provider hostname to appear in that comma-separated allowlist; wildcard hosts are unsupported. Default example pins `openrouter.ai`. This reduces accidental endpoint drift but DNS resolution pinning/egress filtering remains a deployment task. Static guard updated but not run after this edit.

### Phase 8 continuation — exact hostname allowlist and verification (2026-10-27)
Added required `N8N_LLM_ALLOWED_HOSTS` to Compose and host env template, default example `openrouter.ai`; workflow checks exact provider hostname match before ACK. The CI workflow now runs `n8n:check` and supplies locally sourced credentials to `fn:test` only after loopback/JWT-shape guards. CI YAML parsed and its shell block passed `bash -n`; GitHub Actions was not run. Assistant-run `npm run check:static` passed, including n8n guard and plans (102 migrations, 87 pgTAP files), and `npm run contract:export` refreshed the static contract inventory (153 SQL object names, 28 function folders, 30 schema sources). PostgreSQL/Deno execution, live types/schema, n8n import/runtime, DNS pinning/egress controls remain unverified. User-reported `fn:test` success remains scoped ambiguously; latest database suite fix and Deno lint change need user-local verification.

### Phase 8.C pre-ACK verifier behavior test source and execution (2026-10-27)
Added Node VM regression tests for the checked-in n8n verifier: exact allowlisted signed HTTPS endpoint success; unsafe/unapproved endpoint rejection (HTTP, other host, URL credentials/query/fragment, nonstandard port, wrong path, IP/local/test host, wildcard); stale timestamp rejection; invalid HMAC rejection. `n8n:check` now runs static graph checks plus these three tests. Assistant-run `npm run n8n:check` passed, then `npm run check:static` passed including all 102 migration/87 TAP plan source checks. This does not replace n8n import/runtime, callback-network, or DNS/egress verification.

### User-reported local verification pass (2026-10-27)
User reports all local tests and checks passed after following the testing sequence, including reset/demo assertions, `db:test`, `fn:check`, `fn:test`, types generation, contract export, and `check:static`. Exact final line: `Environment template check passed: 41 keys; all 39 prompt-required and 24 literal Edge Function env names are present. Sensitive values are blank/placeholders and operating defaults are local/mock/off; runtime credential validity is not checked.` Report is user-reported; no output artifacts were synchronized into this workspace. Remaining closeout: n8n import/runtime callback verification and deployment DNS/egress review.

### Phase 8 local implementation closeout (2026-10-27)
Based on the user's report that the full local reset/database/function/type/export/static check sequence passed, Phase 8 is closed at the implementation/local-verification scope. The n8n workflow remains intentionally inactive. Do not ask a beginner to expose endpoints or provide secrets for an optional adapter; n8n import/runtime callback and deployment DNS/egress controls are deferred to deployment readiness. No production-readiness claim is made. User-generated live types/schema artifacts were not synced to this workspace.

### Backend-only continuation — `match_reasons` direct wording slice (2026-10-27)
Added optional constrained wording to `match-job` for local synthetic direct mode only. It sends at most 20 top matches' blind aliases and deterministic skill facts; validates strict JSON and rejects any output token not grounded in the facts/approved grammar, plus contact/URL patterns. At most one LLM sentence replaces the third deterministic reason so the existing RPC's maximum-three reasons and frozen output contract stay intact. Provider cap, HMAC-keyed cache, `agent_runs` log, and deterministic fallback are included. Added Deno tests for grounded output, injection/contact/unknown alias rejection, and input minimization. `npm run check:static` passed afterward, but Deno lint/type/test and PostgreSQL tests were not run in this workspace; user-local verification is required before relying on this change.

### Static check after constrained match-reason change (2026-10-27)
Added an explicit helper/test for keeping deterministic facts first and preserving the max-three `reasons` bound. Assistant-run `npm run check:static` passed after the source/docs updates, including 102 migrations/87 TAP plans and the static security/RLS/notification/environment checks. The new Deno helper tests and Edge typecheck were not run in this workspace.

### Assistant-run Deno verification and profile-sync transport hardening (2026-10-27)
The profile sync handler now catches failed GitHub network requests as a generic service error and clears mutable bearer token/header references in `finally` (best effort only; JS strings cannot be securely zeroized). Static check passed. Deno was made available transiently via `npx --yes deno`; all function TypeScript files passed `deno check`, `deno lint supabase/functions` passed (166 files), and `deno test -A` passed **179, failed 0, ignored 1**. The ignored test requires the local Supabase Storage stack/loopback service-role credentials; no SQL tests were run in this workspace. This run includes the `match_reasons` tests and current profile-sync edits, superseding the previous pending-Deno verification note.

### Profile proposal parser tests and regression correction (2026-10-27)
Extracted existing GitHub/LinkedIn deterministic proposal parsing to `_shared/agents/profile-proposal.ts` and added tests for contact scrubbing, canonical repository URLs, and labeled LinkedIn fields. The new test caught that shared text normalization collapsed line breaks before parsing labels, causing a LinkedIn export to yield only its first labeled field. A line-preserving, bounded sanitizer now preserves labels while removing other controls and redacting emails, phones and URLs. Full assistant-run verification: Deno check passed all function TS, lint passed 168 files, `deno test -A` passed 182/0/1 ignored, and `npm run check:static` passed. Direct profile agent remains incomplete and no PostgreSQL suite was run.

### Local-only grounded LinkedIn profile agent (2026-10-27)
Implemented a narrow direct-profile extraction path for LinkedIn exports only, in opted-in local mode for fictional `.test` callers with an active consented source whose auto-approval setting is false. Strict generated output is accepted only when each field is an exact excerpt from contact-scrubbed source; prompt-injection-like excerpts are discarded. Generated proposals remain pending (never auto-applied), provider calls are capped/logged with mode/kill-switch rechecks, profile content is not cached, and the deterministic parser remains fallback. Added stub-provider tests. Assistant-run Deno check/lint passed (170 files), `deno test -A` passed 184/0/1 ignored, and `npm run check:static` passed. This is a bounded local slice, not production profile automation; no SQL tests run.

### Direct-profile safety gate and final checks (2026-10-27)
Added unit coverage for the full direct-profile eligibility gate and asserted the profile provider prompt receives redacted placeholders instead of source email/phone/URL values. Updated `docs/CONTRACT.md` to document the narrowly constrained local flow and clearly note that handler/OAuth/Vault/SQL integration is not claimed. Assistant-run Deno check and lint passed (170 files), `deno test -A` passed 185/0/1 ignored, and `npm run check:static` passed. No migration or frozen contract changed.

### Profile import secret scrub hardening (2026-10-27)
Profile text cleaning now also removes common provider/GitHub/cloud token strings, bearer credentials, password/API-token assignments, and private-key blocks before proposal creation or direct-provider prompts. Tests verify raw values are absent. The repository secret scanner initially caught a deliberately fake token-shaped literal in the new test; the fixture now assembles the token from separate strings, preserving scanner strictness. Focused Deno tests, `npm run secret:scan`, and the full `npm run check:static` pass. No migrations changed.

### Local synthetic multimodal audit path and RLS source-audit follow-up (2026-10-27)

- Added a bounded media attachment path for direct audits. It accepts only an exact owner/submission-scoped video storage key, rechecks database-configured upload size and duration bounds, confirms Storage metadata before download, caps inline Gemini media at 14 MB, validates supported video MIME types, and records a manifest `video:0` evidence reference. Remote video URLs are never fetched. Audio/transcript and frame observations can be produced from an attached video only; output remains schema-validated, post-processed, and callback-finalized. Media payloads go only to Gemini in explicitly opted-in local synthetic `.test` mode; n8n receives no media and remote/provider-independent production processing remains unfinished.
- Provider tests assert Gemini inline media encoding and assert that a multimodal request cannot silently fall back to text-only providers. Bundle tests cover owner-prefix checks, remote URL non-fetch, and manifest inclusion. Cache keys now hash media bytes instead of JSON-serializing a large `Uint8Array` into millions of number characters. Bumped the direct audit prompt version to `audit@3` and updated prompt, contract, README, runbook, TODO and security notes.
- RLS source review added the missing anonymous-role privilege denials for the authenticated-readable `feedback_options` and `skill_families` catalogs in pgTAP sources `0016` and `0053`. Their plan counts pass static verification; the local PostgreSQL/pgTAP suite was not available here, so those SQL assertions are not runtime-verified.
- Assistant-run verification after edits: full function TypeScript `deno check` passed; `deno lint supabase/functions` passed (170 files); `deno test -A` passed **189, failed 0, ignored 1**; `npm run check:static` passed, including 102 migration/87 pgTAP-plan source checks, 60/60 static policy-register integrity, `n8n:check`, and secret scan. No SQL database tests, n8n import/runtime, live Gemini call, provider billing/retention validation, or hosted deployment check was run.
- Root-prompt acceptance remains open; this local synthetic media slice does not close full media processing, the RLS behavior/runtime gate, missing n8n workflows, or production security review.

### n8n callback destination pinning hardening (2026-10-27)

The audit workflow now rejects callback destinations unless the hostname exactly matches `N8N_CALLBACK_ALLOWED_HOSTS`, the path is exactly `/functions/v1/agent-callback`, and the URL is clean HTTPS on the default port; literal IPs, local/reserved/test hosts, wildcard matching, credentials, query and fragment are rejected before HMAC dispatch/ACK. Added the host variable to the Compose requirement and `.env.example`, and added VM tests for accepted configuration, unapproved host, and wildcard. `npm run n8n:check` passed. DNS answer pinning and network egress controls remain deployment-level requirements; workflow import/runtime is still not verified.

### Synthetic-media duration enforcement and n8n local-only gate (2026-10-27)

- Added a bounded MP4/MOV/WebM container-metadata parser for actual media duration. The direct audit worker still checks the submitted duration, but now also parses the downloaded object after Storage metadata and byte limits are confirmed; missing/malformed duration and media above `VIDEO_MAX_SECONDS` are omitted from evidence and cannot receive a `video:0` reference. WebM unknown-size Segment metadata is supported; parser tests cover MP4/MOV v0, MP4 v1, WebM, malformed, unsupported and zero-duration cases. The upload remains bounded at 14 MB before parsing; this is metadata inspection, not full decode/playability validation.
- Gated n8n audit execution and `AGENT_MODE=n8n` configuration to `APP_ENV=local` plus explicit `N8N_ALLOW_SYNTHETIC=true`, independently of the direct-provider opt-in. `submit-project`, worker dispatch and admin config validation all enforce the gate; default remains false. Added tests and documented local-only behavior.
- This is source work only; no PostgreSQL migration changed. Full verification is being run after the current code sweep. n8n assign/match/profile workflows remain outside the audit adapter, and no hosted deployment is enabled.

### End-of-sweep verification (2026-10-27)

After the current video-duration parser, local-only n8n gate, callback host pinning, and env-test updates: Deno typecheck passed across all function TypeScript; Deno lint passed for 172 files; `deno test -A` passed **194, failed 0, ignored 1**. `npm run check:static` passed, including 102 contiguous migrations, 87 static pgTAP plan sources, n8n boundary tests, secret scan, RLS register (60/60 name references), and environment validation (42 keys, 41 prompt-required, 25 literal function env names). `npm run contract:export` refreshed static inventory (153 SQL names, 28 function folders, 30 schema sources), but local Supabase CLI/database was unavailable, so live schema and `database.types.ts` were not generated. PostgreSQL/pgTAP and local Storage integration were not run. This does not close the root-prompt acceptance: behavior-level RLS runtime review, non-audit n8n workflows/adapters, and deployment controls remain open.

### Latest user-reported end-of-workspace verification (2026-10-27)

The user reports that the full local sequence just provided passed on the updated bundle: guarded local reset/demo assertions, `db:test`, `fn:check`, `fn:test`, types, contract export, and static checks. Record this as user-reported only; command logs are not present in this workspace, so these results were not independently observed here. If the SQL suite included the new anon catalog assertions, it provides local-runtime evidence for those test cases, but does not by itself establish complete policy-by-policy RLS acceptance. The root prompt remains incomplete due to missing non-audit n8n workflows/adapters and deployment/security review; retain the no-production-readiness warning.

### n8n assignment, match-reason, and profile adapters (2026-10-27)

Completed source integration for the remaining local synthetic n8n agent slices. Added shared signed synchronous request/result dispatch in `_shared/agents/n8n-agent.ts`; exact-path HTTPS URL validation, 128 KB request/64 KB response bounds, 15-second timeout, HMAC signatures, run/kind matching, and local plus fictional `.test` gates fail closed. Added inactive exports `n8n/workflows/assign.json`, `match.json`, and `profile.json`; retained the audit workflow's separate asynchronous callback model. Assignment wording is passed through the immutable-template/schema validation and deterministic fallback; match reasons are added only to blind aliases from deterministic facts and failures preserve deterministic matching; profile extracts are exact-excerpt-grounded proposals and remain subject to review (no auto-apply). Admin n8n configuration now requires all four safe endpoint URLs; `.env.example`, CONTRACT, RUNBOOK, SECURITY_NOTES, README, PLAN, static workflow checks, and package scripts were updated. This sync response design is deliberately distinct from audit callbacks and needs operator review before any activation.

End-of-code-work verification in this workspace: `npm run check:static` passed in full, including `npm run n8n:check` (static workflow boundary tests and Node VM signature/response checks), 102 migration source checks, 87 pgTAP plan-source checks, secret scan, RLS-register integrity, notification/environment/source checks. After that initial run, Deno was available transiently via `npx --yes deno`: `deno check` across all `supabase/functions/**/*.ts` passed; `deno lint supabase/functions` passed (174 files); and `deno test -A` passed **200, failed 0, ignored 1**. The ignored test requires local Supabase Storage credentials. Supabase CLI and Docker/local PostgreSQL remain unavailable here, so no current `db:reset`, `db:test`, generated live types, or local Storage integration verification was run. n8n import/runtime/provider/network, DNS/egress pinning, hosted deployment, and security review remain unverified. Prior user-reported test passes predate this latest integration and are not evidence for these changes. All workflows remain inactive; no production-readiness or full root-prompt-completion claim is made.

### Current backend delta report — verification refresh and deterministic mock embeddings (2026-10-27)

**Audit summary:** `docs/DELTA_AUDIT.md`'s current grouped source reassessment records 20 Present / 5 Partial / 0 Missing / 0 Conflicts across the 25 original grouped delta items. “Present” is source implementation status, not proof of SQL/runtime acceptance; the detailed audit retains the pre-edit historical snapshot separately.

**New migrations:** Follow-on migration `0102_project_assignment_variation_fingerprint.sql` adds a nullable HMAC fingerprint column/index and insert-only column grant; no existing migration was edited. The earlier mock-embedding and near-duplicate-selection helper changes do not alter database schema.

**Changed or added functions:** `match-job` now uses new `_shared/agents/mock-embedding.ts` deterministic, hash-derived 768-dimensional vectors from job required-skill names/levels and candidate verified/shareable skill names/levels when both stored vectors are unavailable. Stored vectors are compared only when both sides are present, avoiding mixed embedding spaces. The fallback contains no names, emails, profile prose, or other identity-bearing data. Added `mock-embedding_test.ts` for deterministic output, bounds/normalization, overlap ranking, and invalid dimensions. `assign-project` now fills available deterministic template selection across candidates and uses `_shared/agents/project-similarity.ts` to reroll away from near-duplicate recent briefs where a more diverse candidate exists, while retaining 30-day template exclusion and the frozen ProjectBrief output.

**New or changed views and RPCs (exact names):** None.

**Compatibility shims kept for existing consumers:** None; frozen Edge Function request/response contracts and database objects are unchanged.

**Verification status**
- **Verified (executed):** Full assistant-run verification after both new helpers: `npx --yes deno check` across all Edge Function TypeScript passed; `npx --yes deno lint supabase/functions` passed (180 files); `npx --yes deno test -A` passed **209, failed 0, ignored 1**; `npm run check:static` passed in full, including static integrity for 103 migrations and 87 pgTAP sources. The dedicated mock-embedding, project-similarity, and project-variation tests passed 9/9.
- **Inferred (from code):** The mock fallback reads only job skill labels/levels and the candidate projection's approved skill labels/levels. It does not invoke an external provider or expose new candidate data. This is a deterministic lexical/hash similarity fallback, not semantic model output.
- **Not run (and why):** PostgreSQL/pgTAP, local Storage SDK integration, and n8n import/runtime remain unrun in this workspace due unavailable local Supabase/Docker and n8n runtime. Provider-generated embedding creation/population remains unimplemented; only deterministic mock vectors cover the no-stored-vector path.
- **Manual steps for the human:** None required for this local code change. Continue to keep n8n inactive; no hosted deployment or real user data is involved.

**Decisions made (`TODO(decision)`):** If either stored vector is missing, use the deterministic mock vector for both sides so cosine comparison does not mix provider and mock spaces. This does not change the frozen matching response shape.

**Known limitations:** Mock vectors are reproducible and skill-token-sensitive but are not semantic embeddings. Provider embedding APIs and database vector population remain an implementation gap; local SQL match behavior still needs PostgreSQL verification.

**Files created or changed:** `_shared/agents/mock-embedding.ts` and tests; `_shared/agents/project-similarity.ts` and tests; `_shared/agents/project-variation.ts` and tests; `match-job/index.ts`; `assign-project/index.ts`; migration `0102_project_assignment_variation_fingerprint.sql`; `0067_project_assignment_rls.test.sql`; `supabase/seed.sql`; `CONTRACT.md`; `PLAN.md`; `TODO_DECISIONS.md`; `DELTA_AUDIT.md`; `DELTA_PLAN.md`; `DELTA_REPORT.md`; `RUNBOOK.md`.

### Follow-on project variation implementation (2026-10-27)

Implemented the remaining assignment template variation/fingerprint path from `docs/plan/agent.md` B4. Template JSON may declare bounded `variation_slots` for domain, dataset, constraint, and twist; the server selects options from a stable seed, replaces only the matching placeholders, strips the internal slot metadata from the delivered brief, and preserves the strict frozen `ProjectBrief` shape. A one-way HMAC fingerprint is generated from the template and selected values. Before assignment creation, the handler reads only recent fingerprint values (not other students' briefs or IDs) for that template and retries slot selection to avoid overused exact combinations; no more than three same-fingerprint choices are preferred across the 90-day window, with bounded retries and least-used fallback. The fingerprint column is insert-only for authenticated role and cannot be updated later; its shape is constrained and indexed. Updated the fictional React demo template with safe synthetic variation slots and extended the existing project-assignment pgTAP source for column privileges, valid fingerprint insertion, and invalid fingerprint rejection. Also added Jaccard similarity-aware template re-roll against the requesting student's recent briefs. The initial-similarity cutoff remains a demo provisional (TODO(decision)); user approval for production is not implied.

Latest full-code verification after these additions: all Edge Function TypeScript `deno check` passed; `deno lint supabase/functions` passed (180 files); `deno test -A` passed **209, failed 0, ignored 1**; `npm run check:static` passed, validating **103 contiguous migrations** and **87 pgTAP plans** plus existing static security, n8n, secret, environment, RLS-register and notification checks. No PostgreSQL reset/test or migration runtime was possible in this workspace, so migration `0102` and its updated pgTAP assertions remain unexecuted. The local Storage integration test remains the one ignored Deno test without Supabase local credentials.

### Direct-provider transport bounds (2026-10-27; not yet verified)

Hardened the shared direct-provider adapter to reject HTTP redirects (preventing credential/query-key forwarding to alternate destinations) and to enforce a 1 MB response-body cap before JSON parsing. Oversize and invalid JSON errors stay generic and do not expose provider response bodies or secrets. Added regression cases for redirect rejection, response-body cap, and error redaction in `supabase/functions/_shared/agents/providers/direct_test.ts`. Per the user's instruction to defer verification until the end of code work, these latest edits have not been run through Deno or static checks yet.

### Local Edge Runtime bare-import fix (2026-10-27; awaiting user verification)

The user reported `BOOT_ERROR` from local `supabase functions serve public-verify`; Edge Runtime could not resolve the bare import `@supabase/supabase-js` because the repository-root Deno import map was not available to the function runtime. Replaced bare `@supabase/supabase-js`, `zod`, and `@std/assert` TypeScript imports with explicit pinned `npm:`/`jsr:` specifiers across Edge Function source/tests. This is intended to make function bundle resolution independent of the repository-root import map. The code has not yet been re-checked or re-served; user should re-download the updated ZIP and verify.

### Portal contract cleanup and user-reported local acceptance (2026-10-27)

Rewrote `docs/CONTRACT.md` as a current contract-package index and acceptance record. It points to `docs/FROZEN-CONTRACTS.md` as binding for frontend field/request/response contracts, distinguishes generated schema inventory from actual portal acceptance, and marks each of the five portal integrations **not confirmed** because no frontend source repositories are present in this workspace. It records the user's reported latest local Deno/Node/pgTAP/Storage/type/export checks and the `public-verify`/OPTIONS runtime observations without representing them as assistant-run or as proof of full feature behavior. `npm run contract:export` was rerun here to refresh the static package; this workspace lacks Supabase CLI/local DB, so its refreshed `contract-dist` does not contain `database-schema.sql` or `database.types.ts`. The user should regenerate those artifacts in their local project when needed. Portal source review, n8n import/runtime, and production/staging review remain open; do not activate n8n or deploy.
