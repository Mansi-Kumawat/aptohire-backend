# Runbook (instructions only)

## Guarded local database reset and fictional seed

Run `npm run db:reset`, not the raw Supabase reset command. The wrapper requires `APP_ENV=local` or `demo` from the process environment or `.env.local`/`.env`, and refuses `production`, missing, or unknown values before invoking Supabase. `.env.example` supplies the local default; copy it to ignored `.env.local` before reset. CI explicitly sets `APP_ENV=local` and runs `npm run test:seed-guard`. The SQL seed independently rejects a database whose `app_config.APP_ENV` is explicitly `production`. The reset is destructive to the local database and re-applies only fictional `.test` fixtures; after a successful reset, the wrapper automatically runs `scripts/assert-demo-states.js` and fails if expected demo states are missing. `npm run db:assert-demo` remains available for a separate recheck. Do not link this repository to a hosted project or bypass the wrapper.

## Kill switch

`AI_KILL_SWITCH` is enforced by submission, retry, matching, local-only direct JD/assignment, and callback finalization (the finalizer also rechecks the flag inside the service-only RPC). For an immediate local stop, set the kill switch through `admin-update-config` with an aal2 admin or stop the local Edge Function process. A constrained direct audit, match-reason wording, LinkedIn profile-proposal, JD extraction, and assignment-wording slice exists only for explicitly opted-in local fictional `.test` use; the main matching/scoring logic remains deterministic. The n8n audit adapter/workflow is implemented as source but inactive and not import/runtime-verified; code requires `APP_ENV=local`, `N8N_ALLOW_SYNTHETIC=true`, and `N8N_AUDIT_ENABLED=true` before dispatch. Inactive `assign.json`, `match.json`, and `profile.json` workflows now use synchronous HMAC-signed request/result envelopes and are wired to the corresponding local-synthetic Edge Function paths; their n8n import/runtime and provider integration remain unverified. This synchronous request/result pattern differs from the audit workflow's async callback pattern. Verify each workflow before activation and run the full deployment/security review before any hosted use.

## Audit evidence status

The mock audit worker does not extract repository, live-site, uploaded-document, or video evidence and must not treat the submission UUID as evidence. A constrained direct audit path exists for fictional `.test` accounts only, with explicit local opt-in; it can inspect bounded public GitHub metadata/README/source excerpts, student-owned text documents, and an owner-scoped video file up to 14 MB sent inline to Gemini after its MP4/MOV/WebM container duration is parsed and checked against config. It does not execute code or test suites, fetch remote video/live-site URLs, or provide production-grade media analysis. n8n audit does not receive video bytes. With an empty evidence manifest, post-processing marks criteria insufficient, lowers confidence, applies no skill score, and leaves the submission pending human review. Inactive audit, assign, match-reason, and profile workflows are exported. The audit uses an asynchronous signed callback; assign/match/profile use synchronous HMAC-signed results. None has been imported or runtime-validated in n8n; keep them inactive. Do not interpret mock/direct demo results as validated evaluations of real work.

## Key and pepper rotation

Rotation workflows are not implemented. Plan coordinated migrations and invalidation before rotating ID, alias, rate-limit, callback, or provider secrets. Never print key values or perform rotation through an automated agent.

## Local profile-sync OAuth

`profile-sync` requires local-only `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_REDIRECT_URI`, `STUDENT_PORTAL_URL`, and `OAUTH_STATE_PEPPER` in the ignored `.env.local`. Register only the local function callback during development. The GitHub callback state is one-use and expires after ten minutes. Do not place tokens or OAuth client secrets in browser configuration or commit them.

## Local raw-video retention schedule

Migration `0047_storage_retention_jobs.sql` runs the safe database purges already present, registers a daily keep-alive, and schedules a Vault-backed HTTP dispatch for `retention-cleanup`. The function removes only `videos/{student_uuid}/{submission_uuid}/demo.{mp4|webm|mov}` objects older than 90 days via the Storage API; the SQL migration never deletes `storage.objects` rows directly. It clears matching `video_path`, `video_url`, and `video_bytes` references only after Storage removal succeeds. Migration `0050_data_export_retention.sql` also lists safely shaped `data-exports/{student_uuid}/exports/{export_uuid}.json` files older than 30 days and deletes them via the Storage API, recording only an aggregate count. Transcripts, scores, and evidence pointers are retained.

To enable the local daily dispatch, first set a long random `RETENTION_CLEANUP_SECRET` in ignored `.env.local` and pass the same value to local Edge Functions. In the local Supabase SQL editor, store only the function base URL and this dedicated cleanup secret in Vault (names: `aptohire_functions_url` and `aptohire_retention_secret`). For the local stack the base URL is normally `http://kong:8000`. Do not use or store the service-role key for this job. If the Vault values are absent, the cron job intentionally does nothing; you can invoke the function manually with `x-retention-secret` for local verification. Never configure a hosted URL or run this cleanup against a remote project from this repo.

## Paused project and backups

Restore/restart via the Supabase dashboard after reviewing project health. Free-tier projects may pause after inactivity and may have limited backup/PITR options. A weekly logical export is a human-run operational task; `scripts/export-snapshot.sh` is documentation-only at this stage.
