# AptoHire shared backend

This repository contains the shared Supabase backend for the five AptoHire portals. It contains no frontend; the frozen contracts define the portal boundary.

> **Implementation status (2026-10-27):** substantial fictional-demo backend implementation is present. Assistant-run Deno check across all function TypeScript files passed, Deno lint passed (172 files), and `npx --yes deno test -A` passed 194 tests with 1 local Storage integration test ignored because local Supabase credentials/stack were not configured. The user now reports the local reset, `db:test`, demo assertions, function checks/tests, type generation, contract export, and static checks all passed on the latest bundle; those results are user-reported and the logs are not independently available here. The root prompt is not fully satisfied and the backend is not production-ready. No SQL tests were independently run in this workspace.

## Current backend status

### Implemented

- 102 forward-only migrations, 87 pgTAP files, 28 Edge Function folders, fictional seed/reset assertions, frozen contract sources, and CI workflow.
- Static RLS/notification/contract inventories and security guard scripts. Static policy-name matches are candidates, not proof of behavior for every role/operation.
- Mock agent paths, selected direct-provider paths restricted to explicitly opted-in fictional `.test` users in local mode, structured matching, signed synthetic audit dispatch/callback, and an inactive n8n audit workflow.
- User-reported local verification pass before the latest match-reason wording change; assistant-run static suite passed after that change.

### Root-prompt work still open

- Complete a policy-by-policy behavioral RLS audit; the 60-policy static candidate map does not establish full positive/negative authorization coverage.
- Direct profile extraction is now limited to consented LinkedIn exports in opted-in local `.test` mode, with exact-excerpt grounding and deterministic fallback; comprehensive profile assistance, production/general-purpose video/audio processing, and several broader agent workflows remain incomplete or local/synthetic-only. A bounded owner-scoped video path parses MP4/MOV/WebM duration metadata and can send up to 14 MB inline to Gemini only in local synthetic mode; malformed/over-limit media is omitted, remote URL fetching and n8n media remain disabled. The n8n implementation now includes inactive audit, assignment, match-reason, and profile-extraction workflow exports; agent workflows remain local-synthetic-only, and workflow import/runtime is not verified.
- `admin-invite-member` remains an optional P2 item; its verified-email/single-use invitation contract needs review before implementation.
- Product/security defaults in `docs/TODO_DECISIONS.md` are approved for fictional demo use only, not for real users.
- Staging configuration, hosted dashboard review, DNS/egress controls for any activated n8n service, and an independent security audit remain outside local test completion.

The new `match_reasons` direct wording path sends only job-scoped blind aliases and deterministic skill facts to a provider, only in explicit local synthetic mode; provider failures fall back to deterministic reasons. Its Deno tests and all current Deno unit tests passed in the assistant workspace; the loopback-only Storage integration test was ignored. This does not replace local SQL tests or deployment/security review. Do not deploy or use real student data based only on green unit tests.

### You must run locally (browser workspace cannot currently run these)

The current implementation is still incomplete. For local validation only, install Docker Desktop, Supabase CLI, Deno, and Node LTS on a local development machine. From this directory run, in order:

```sh
npm install
npm run db:start
npm run db:reset
npm run db:test
npm run db:assert-demo
npm run fn:check
npm run fn:test
npm run check:static
npm run types
npm run contract:export
```

`npm run rls:coverage` regenerates the policy inventory, relation-name test candidate map, and a generated one-row-per-policy register inside `docs/RLS_MATRIX.md`; `npm run check:rls-register` verifies the register contains each inventory relation/policy pair exactly once. `npm run notifications:matrix` regenerates `docs/NOTIFICATION_MATRIX.md` from prompt §15A with producer/test file text candidates, and `npm run check:notifications` verifies every prompt kind and referenced file is present; these matches are not proof of runtime notification delivery. `npm run n8n:check` source-checks the inactive workflow graph, secret access, ACK ordering, redirect policy, exact operator-allowlisted provider and callback host boundaries, and Compose security bounds, then runs Node VM tests of the pre-ACK verifier for signed-contract, host-allowlist, endpoint rejection, timestamp, and HMAC behavior. It does not import or run n8n itself. The Deno suite's `export-storage_local_integration_test.ts` is ignored unless `APP_ENV=local`, `SUPABASE_URL` is an HTTP loopback origin, and `SUPABASE_SERVICE_ROLE_KEY` is a valid local compact JWT. `.env.local` is not automatically loaded by `deno test`; use process environment values from `supabase status -o env` if you want that local Storage integration test to run. Never use a hosted key or URL. CI now sources the local Supabase environment and fails closed unless its API URL is loopback and its service-role key has compact-JWT structure. These static artifacts do not prove RLS behavior or replace positive/negative policy-by-policy pgTAP assertions. `npm run check:views` also source-scans SQL view declarations to reject `SELECT *`, preserving explicit column lists; local migration execution remains the authoritative parser check. `npm run check:env-example` checks that `.env.example` contains every prompt-required key and literal `Deno.env.get()` reference, sensitive-value fields are blank or obvious placeholders, and operational defaults remain local/mock/off (including a loopback Supabase URL); it does not validate runtime credentials. `npm run security:admin-aal2` statically checks every `admin-*` handler for JWT auth, admin role, and `aal2: true`; this is source lint, not runtime authorization proof. `npm run security:definers` statically checks every migration SECURITY DEFINER declaration for an explicitly empty search_path and a matching-arity REVOKE ALL that explicitly names PUBLIC; it is a source lint, not runtime authorization proof. `npm run test:plans` checks four-digit contiguous migration and pgTAP numbering, compares each declared TAP plan with recognized assertion calls, and requires every test to contain one transaction start, one `finish()`, and one rollback; it is static lint, not SQL test execution. `npm run todo:decisions` ensures every source file carrying a `TODO(decision)` marker is referenced in `docs/TODO_DECISIONS.md`; owners must still review each provisional default. `npm run contract:export` generates the static contract inventory and copies schema sources using Node; it also adds the live SQL schema dump and `database.types.ts` only when the local Supabase CLI/stack are available. Fix all failures and rerun the full sequence. Share only redacted error output if you want help diagnosing failures. Never share `.env.local`, keys, student data, or service-role credentials. Do not run remote Supabase commands as a substitute for local verification.

### Manual hosted-dashboard work (only after local tests and independent review)

- [ ] Set and verify auth URLs for all five production hosts and local callback URLs.
- [ ] Verify TOTP MFA, confirmation/SMTP, password rules, auth rate limits, storage bucket size/MIME settings, and that only `public` is exposed via the Data API.
- [ ] Disable unused APIs and check hosted backup/retention/free-tier limits.
- [ ] Configure production secrets through the dashboard/CLI yourself; never put them in this repo or chat.
- [ ] First deploy deliberately to a separate demo project and follow the documented manual deployment steps. Never use production for initial migration testing.

## Windows 10 setup guide (free local development)

This setup uses the local Supabase stack; you do not need a Supabase Cloud project or paid subscription to develop locally. Docker Desktop is free for personal use, education, non-commercial open-source work, and qualifying small businesses; check Docker's current terms if this is commercial work. Local development still uses your PC's disk, memory, electricity, and internet for initial downloads.

**Windows 10 support warning (important):** Standard Windows 10 support ended on October 14, 2025. Prefer upgrading to a supported Windows 11 version if your PC qualifies, or confirm that your Windows 10 installation has applicable Extended Security Updates. Docker Desktop's Windows 10 requirements specify 64-bit Windows 10 version 22H2 (build 19045), WSL 2, and hardware virtualization; Docker says it supports Windows versions still within Microsoft's servicing timeline. Thus Windows 10 22H2 without ongoing security support may not be an officially supported Docker host. Do not disable security controls to force installation.

### A. Check the PC first

1. Press `Win + R`, type `winver`, press Enter. Check edition, version, and OS build. For Docker's listed Windows 10 baseline, expect 22H2/build 19045 and 64-bit Windows.
2. Open **Task Manager → Performance → CPU**. Confirm **Virtualization: Enabled**. If disabled, enable Intel VT-x/Virtualization Technology or AMD-V/SVM in BIOS/UEFI. If the setting is unavailable, ask your PC manufacturer; do not change firmware settings you are unsure about.
3. Supabase's local stack runs several containers. Close other heavy programs and make sure you have several GB of free disk space. More memory/disk makes it smoother.

### B. Install WSL 2

1. Open **PowerShell as Administrator** (Start menu → type PowerShell → right-click → Run as administrator).
2. Run:

   ```powershell
   wsl --install -d Ubuntu
   ```

3. Restart Windows if prompted. Open Ubuntu from Start. On first launch, create a Linux username and password (the password is for local Ubuntu only; typing it shows no characters).
4. Open PowerShell and verify:

   ```powershell
   wsl --update
   wsl --set-default-version 2
   wsl --list --verbose
   ```

   Ubuntu should show version `2`. If `wsl --install` is not recognized, your Windows build may be too old; update Windows first. If it says WSL is already installed, run the update and list commands instead.

### C. Install Docker Desktop

1. Download **Docker Desktop for Windows** only from [Docker's official Windows installation page](https://docs.docker.com/desktop/setup/install/windows-install/).
2. Run the installer. Select/use the **WSL 2 backend** when offered. Do not enable Windows containers; Supabase uses Linux containers.
3. Start Docker Desktop from the Start menu and accept the displayed terms. If asked, enable integration for Ubuntu under **Settings → Resources → WSL Integration**.
4. Open a new PowerShell window and check:

   ```powershell
   docker version
   docker info
   ```

   Both should return information without a daemon/engine error. If Docker cannot start, check virtualization, WSL version, Windows support status, and Docker Desktop's troubleshooting page.

### D. Install Node.js LTS and Deno

Open a normal (non-admin) PowerShell window. If `winget` is available, run:

```powershell
winget install --exact --id OpenJS.NodeJS.LTS
winget install --exact --id DenoLand.Deno
```

Close and reopen PowerShell. Verify:

```powershell
node --version
npm --version
deno --version
```

If `winget` is unavailable, use the official [Node.js downloads page](https://nodejs.org/en/download/) and [Deno installation page](https://docs.deno.com/runtime/getting_started/installation/) instead. Do not install random repackaged binaries.

### E. Install the Supabase CLI (Scoop method)

In normal PowerShell, install Scoop using its official instructions at [scoop.sh](https://scoop.sh/). Then run the Supabase CLI's official Windows commands:

```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
supabase --version
```

The Supabase CLI is free/open source. Avoid `npm install -g supabase`; global npm installation is not the supported Windows method. The project `package.json` may separately install npm dependencies later.

### F. Get and open the project

1. Download the project archive from this workspace and extract it somewhere simple, for example `C:\Users\YOUR_NAME\Projects\aptohire-backend`. Avoid OneDrive-synced folders while running Docker if you encounter slow file access.
2. In PowerShell, change into the extracted project directory, for example:

   ```powershell
   cd "$HOME\Projects\aptohire-backend"
   ```

3. Verify the expected files exist:

   ```powershell
   Get-ChildItem
   Get-ChildItem .\supabase\migrations
   ```

4. Read `docs\plan\` and this README. The project is still incomplete and unverified: **do not run it with real data or deploy it**. When the implementation is ready, continue with the local command checklist below.

### G. Local-only environment and commands (after implementation is ready)

Copy `.env.example` to `.env.local` before resetting; the guarded reset requires `APP_ENV=local` or `APP_ENV=demo` explicitly and refuses production, missing, or other values. Keep placeholder/local values; never put a production secret there. PowerShell copy command:

```powershell
Copy-Item .env.example .env.local
```

Then from the project root, after reviewing the current incomplete scaffold:

```powershell
npm install
npm run db:start
npm run db:reset
npm run db:test
npm run db:assert-demo
npm run fn:check
npm run fn:test
npm run rls:coverage
npm run test:seed-guard
npm run test:secret-scan
npm run secret:scan
npm run check:static
npm run types
npm run contract:export
```

`npm run db:start` downloads several container images the first time. `npm run db:reset` is destructive to the **local Supabase database only**; it recreates local schema and seed state, then automatically runs the demo-state assertions. Never point it at a remote database. Stop the stack when finished with `npm run db:stop`.

### Optional direct-provider sandbox

Keep the database `app_config.AGENT_MODE` at `mock` unless you are deliberately testing the unfinished direct-provider code with fictional local fixtures. The `AGENT_MODE` line in `.env.example` is a reminder; Edge functions read the database setting, changed through the MFA-protected `admin-update-config` action. Direct mode works only when `APP_ENV` is exactly `local`, `LLM_ALLOW_SYNTHETIC_DIRECT=true`, and the signed-in account uses a fictional `.test` email; it fails closed otherwise. Keep the direct opt-in false by default. n8n audit separately requires `APP_ENV=local`, `N8N_ALLOW_SYNTHETIC=true`, and `N8N_AUDIT_ENABLED=true`; all are false/off by default and do not make n8n assignment/match/profile workflows available. Direct mode is wired for job-description extraction, assignment wording, a constrained audit path, grounded `match_reasons` wording, and pending-only profile extraction for synthetic `.test` projects. The audit path can attach an owner-scoped video up to 14 MB to Gemini for multimodal scoring in local synthetic mode after parsing MP4/MOV/WebM duration metadata against config; malformed or over-limit media is omitted, remote video URLs are never fetched, and n8n/direct providers other than Gemini do not receive media. This remains a local demo slice, not the production Proof Audit Engine or production media pipeline. If deliberately testing, set the opt-in and add a provider key/model only in your ignored `.env.local`, choose a low-cost test model, and set `LLM_DAILY_CAP_PER_PROVIDER` to a small value such as `5`. Never paste or send provider keys to anyone. Provider retention/billing settings are your responsibility. Assistant-run Deno typecheck/lint and unit tests pass; provider billing, live network integration, and the local Storage integration test still require deliberate local setup.

## Prerequisites

1. Install Docker Desktop, Supabase CLI, Deno, and Node.js LTS using the Windows steps above.
2. Use `.env.local` only for local development; never commit it.
3. Run the local commands only after the incomplete migrations have been reviewed and completed.
4. Run database and function tests; fix failures before considering a deployment.

No production credentials belong in this repository. Never run remote commands from an automated agent. When a human is ready to deliberately deploy, they must review the environment and manually use `supabase link`, `supabase db push`, `supabase functions deploy`, and `supabase secrets set --env-file` against a non-production demo project first.

## Demo identities

The local-only seed now creates fictional Auth accounts for the admin/reviewers, five student examples, three university TPOs, and four organization recruiters. All use reserved `.test` addresses; the shared, intentionally public demo password is `aptohire-demo-only` (also shown as `DEMO_PASSWORD` in `.env.example`). **Never reuse it or deploy these seed accounts to any hosted project.** Admins must enroll TOTP/MFA in the local UI before admin routes will work. Example logins include `aarav@unia.edu.test`, `sohan@demo.aptohire.test`, `tpo@unib.edu.test`, `recruiter@orgc.demo.test`, and `reviewer2@demo.aptohire.test`. The seed also creates synthetic human-review outcomes and one resolved appeal; these are demo fixtures, not real human judgments. Uni A's intended seeded funnel is 90 roster entries → 58 linked → 31 submitted → 19 verified. The SQL seed uses a fixed local-only password literal; keep it synchronized with `DEMO_PASSWORD` if you change it. `npm run db:reset` runs these assertions automatically after a successful reset; `npm run db:assert-demo` remains available for a separate manual recheck.

## Security setup to verify manually

Hosted dashboard settings, auth redirect URLs, TOTP MFA, SMTP, password rules, rate limits, bucket limits, disabled APIs, and project pausing behavior must be reviewed in the dashboard. See `docs/SECURITY_NOTES.md`.

## Common issues

- If local migrations fail, check Docker is running and run `supabase status`.
- If Deno cannot resolve imports, verify network access or use a local dependency cache.
- Do not work around authorization failures by disabling RLS.

## Glossary

- **RLS:** Postgres row-level security, the data authorization boundary.
- **Blind candidate card:** job-scoped candidate data without direct identity fields.
- **Grant:** time-limited student consent for a defined organization access scope.
