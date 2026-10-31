# AptoHire hosted-demo backend source

This is a source package from the audited backend workspace, provided because the user does not have a standalone backend checkout on their computer. It contains the Supabase migrations, Edge Functions, scripts, and contract documentation needed for CLI work. It has no Git history and no local credentials; it does not contact Supabase when extracted.

## Scope for the demo

- Use this only for the hosted **demo** project, after reviewing the migration list and target project reference.
- `APP_ENV` must be `demo` for this demo configuration. Keep the agent mode set to `mock` in the backend database configuration. Do not turn on direct AI or n8n as part of Step 2.
- Deploy only the 16 allowed functions named in the AptoHire 2-hour finish guide: `complete-signup`, `register-student`, `public-verify`, `submit-application`, `assign-project`, `submit-project`, `audit-submission`, `roster-import`, `match-job`, `request-access`, `respond-access`, `withdraw-access`, `reveal-student`, `admin-approve-university`, `admin-approve-org`, and `admin-review-audit`.
- Do not run `db reset` against a hosted project. Never put service-role credentials in a frontend or chat. Keep private secret files outside Git.

## First hosted-project sequence

From this extracted directory, install/use Supabase CLI via `npx`, authenticate in the CLI, link to the new project, and inspect `npx supabase migration list --linked` before considering `npx supabase db push`. Check the project ref carefully. Enter access tokens and database passwords only into the local CLI prompts; never send them to an assistant.

After migrations, follow the guide for the permitted Edge Function secrets and function deployments. This package does not claim that a live Supabase project has been migrated, seeded, configured, or tested.

## Verification notes

The contract docs record earlier backend checks as user-reported, not independently verified here. No remote Supabase request or deployment was made in preparing this ZIP. This source package is not a production-readiness certification.
