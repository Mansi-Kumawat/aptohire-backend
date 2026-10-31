# AptoHire backend ↔ portal contract

**Status as of 2026-10-27: backend local verification is user-reported as passing; frontend integration acceptance is not yet confirmed.** This file is the contract-package index and acceptance record. It does not claim production readiness.

## Authoritative sources

- [`FROZEN-CONTRACTS.md`](./FROZEN-CONTRACTS.md) is the binding frontend request/response, field, enum, bound, and error contract transcribed from the five portal prompts. Do not rename or reinterpret it without an explicit product decision.
- `supabase/functions/_shared/schemas/` contains server-side request/response validators; the generated export copies public schema sources under `contract-dist/schemas/`.
- The current database object/column inventory is generated in `contract-dist/INVENTORY.md`; live local PostgreSQL schema and TypeScript types are emitted as `contract-dist/database-schema.sql` and `contract-dist/database.types.ts` when `npm run contract:export` runs successfully against the local stack.
- `docs/prompts/00-aptohire-backend-prompt.md` and `docs/prompts/00b-aptohire-backend-delta-prompt.md` remain the requirements sources. `docs/PLAN.md`, `docs/DELTA_AUDIT.md`, and `docs/TODO_DECISIONS.md` track implementation scope and open limitations.

**Important distinction:** a generated schema/inventory describes backend source and database shape; it does not prove that a portal calls the API correctly or that authorization is correct. The frozen prompt contract is the required interface; portal source review and acceptance tests are still needed.

## Backend verification record

The user reports that the latest local run passed:

- `deno check`, `deno lint`, and `deno test -A`;
- `npm run check:static` and `npm run db:test`;
- the local Supabase Storage integration test (not ignored);
- `npm run types` and `npm run contract:export`;
- local Edge Function serving, including the `public-verify` synthetic non-existent-id request returning the expected `404 NOT_FOUND`, and a read-only OPTIONS route sweep with no `BOOT_ERROR`.

These are **user-reported results**, not independently executed by the assistant. The `OPTIONS` sweep confirms routes can be reached without a worker boot error; it is not a behavioral/authenticated integration test for each function. Do not treat it as proof that every portal flow or every RLS policy has been accepted.

## Shared calling rules

- Edge Function base: `${SUPABASE_URL}/functions/v1`.
- Use the public anon key only as the public API key for anonymous functions. User-facing functions use the signed-in user's JWT. Admin functions require an admin JWT with `aal2` (MFA). Never put a service-role key in a browser or portal project.
- Common error envelope: `{ "error": { "code": "…", "message": "…", "fields"?: { "field": "…" } } }`. Render safe, user-facing messages; do not show raw backend/provider messages.
- Validate with the exact frozen request/response schemas. Render only response fields actually present; optional or ungranted fields must not be fabricated.
- Treat student-provided text and uploaded content as untrusted. Do not send real student data to direct providers or n8n during local verification.

## Portal API map from the frozen contract

| Portal | Contracted functions / surfaces | Integration acceptance |
|---|---|---|
| Root site | `public-verify`, `submit-application` | **Not confirmed:** portal source is not present in this workspace. |
| Student | `complete-signup`, `register-student`, `confirm-affiliation`, `assign-project`, `submit-project`, `respond-access`, `withdraw-access`, `profile-sync`, `export-my-data`, `delete-my-account`; student views/RPCs in `FROZEN-CONTRACTS.md` | **Not confirmed:** portal source is not present in this workspace. |
| University | `complete-signup`, `roster-import`; university views, roster and Storage paths | **Not confirmed:** portal source is not present in this workspace. |
| Organization | `complete-signup`, `extract-job-skills`, `match-job`, `request-access`, `reveal-student`; blind candidate/request views | **Not confirmed:** portal source is not present in this workspace. |
| Admin | `admin-approve-university`, `admin-approve-org`, `admin-set-subscription`, `admin-review-audit`, `admin-decide-ticket`, `admin-update-config`, `admin-retry-run`, `admin-view-student`; admin views | **Not confirmed:** portal source is not present in this workspace. |

The portal directories/repos themselves were not included in the backend workspace inspected for this contract cleanup. Therefore, this document cannot truthfully say that each frontend currently uses the frozen requests, responses, fields, or permissions. Backend implementations and schemas can be compared against the frozen prompt, but the frontend call sites, generated types, UI handling, and permission assumptions require the corresponding portal source.

## Portal integration acceptance checklist

For each of the five portals, acceptance is complete only after reviewing that portal's actual source and verifying all of the following against `FROZEN-CONTRACTS.md`:

1. Function name, HTTP method, URL, headers, authentication, and role/MFA requirements match.
2. Request payloads are validated against the exact field names, enum values, bounds, and strictness; sensitive values are not logged, persisted in browser logs, or placed in URLs.
3. Responses and optional fields are parsed with the frozen schemas; the UI does not invent data or render fields the user is not authorized to see.
4. Error codes, rate limits, loading/retry behavior, and conflict/expired/unauthorized states are handled without leaking raw server messages.
5. Database views/RPCs and Storage paths use only the documented projections and owner/member scopes; browser code never uses service-role credentials or bypasses RLS.
6. The portal's build/tests and local synthetic end-to-end checks pass against this backend. Any mismatch is reported as a discrepancy; do not silently change the frozen contract.

## Contract package handoff

1. In the local backend checkout with the local Supabase stack running, regenerate the package after this contract file changes: `npm run types` and `npm run contract:export`. This makes the exported `contract-dist/CONTRACT.md` and generated schema/types correspond to the local migrations. These commands do not reset the database.
2. For an **audit-only first pass**, upload to each relevant portal workspace: `contract-dist/CONTRACT.md`, `contract-dist/FROZEN-CONTRACTS.md`, only that portal's relevant files under `contract-dist/schemas/`, and `contract-dist/database.types.ts` if the portal uses generated Supabase types. `INVENTORY.md` is a static inventory, not a substitute for the contract. Ask the portal/code assistant to produce a mismatch report only—do not edit the frozen contract or make code changes yet.
3. Review the mismatch reports against the actual portal source. Integration acceptance is complete only after the actual call sites, permissions, UI behavior, and portal build/tests have been checked. The contract upload alone is not acceptance.

Never upload `.env`, `.env.local`, anon/service-role keys, provider keys, HMAC/pepper values, OAuth credentials, real account credentials, or student data. Keep all n8n workflows inactive. Do not point portals at a hosted project until a deliberate staging review and security approval are complete.

## Known backend/frozen-contract discrepancy

- The frozen admin contract includes `admin-seed-reset`; that Edge Function is intentionally **not implemented**. The repository instead provides `npm run db:reset`, guarded by `APP_ENV=local|demo`, for the local fictional fixture database. Do not add a hosted reset action or direct a portal to invoke a database reset. This discrepancy needs an explicit product decision or a revised frozen contract before any admin portal is considered accepted.

## Remaining acceptance limits

- Actual portal source comparison and portal build/integration acceptance are pending because no frontend source is present here.
- n8n import/runtime/operator review is pending; workflow exports remain inactive and local-synthetic-only.
- Provider-generated semantic embeddings are not implemented; current missing-vector fallback is deterministic mock embedding, not semantic embedding.
- Broader agent/media capabilities and a separate policy-by-policy security review are not established by the reported test pass.
- Hosted staging, deployment, and production security review are deferred. No production-readiness claim is made.
