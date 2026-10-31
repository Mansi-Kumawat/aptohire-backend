# Organization portal CORS fix and redeploy

## What the browser evidence showed

The Supabase Auth signup request returned HTTP 200, creating the Auth user. The browser then sent an OPTIONS preflight to `complete-signup`; the function returned 204, but its `Access-Control-Allow-Headers` did not include `x-client-info`. The browser therefore blocked the POST before it reached the function. This prevented the signup bootstrap from completing. The same shared CORS helper is used by several Edge Functions.

## Source change

`supabase/functions/_shared/cors.ts` now includes `x-client-info` in `Access-Control-Allow-Headers`. Existing allowed origins and other allowed headers are unchanged.

## Apply the role-RPC repair and deploy the Organization functions

The signup error response `Could not initialize account role` is emitted when the service-side RPC returns an error. This package adds a forward-only migration that reasserts the existing `set_profile_role_once` implementation and its service-role-only grant, plus a server log entry containing only the PostgREST error code. It does not bypass the role-once protection or log user identifiers.

Run from the real backend repository root after copying this source into that checkout. The migration is forward-only; do not run database reset.

1. In Supabase Dashboard, select the dedicated demo project used by the deployed Organization portal.
2. Open **Project Settings → General** and copy the **Reference ID** for local use. Do not share keys or tokens.
3. Open a terminal in the backend repository root. Confirm the Supabase CLI is available with `npx supabase --version`. If not authenticated, run `npx supabase login` and complete the secure CLI flow locally; never put an access token in chat or source files.
4. If this checkout is not linked to the intended project, run `npx supabase link --project-ref <PROJECT_REF>`. Confirm the linked project reference before continuing. Then inspect and apply pending forward migrations:

```sh
npx supabase migration list --linked
npx supabase db push --linked
```

This applies migration `0103_repair_signup_role_initializer.sql`; it does not reset the database. Do not continue if the linked ref is not your dedicated demo project or if the migration list shows unexpected divergence.

5. Deploy the Organization functions that use the shared CORS helper. Replace `<PROJECT_REF>` locally with the Reference ID. Run each command separately:

```sh
npx supabase functions deploy complete-signup --project-ref <PROJECT_REF>
npx supabase functions deploy extract-job-skills --project-ref <PROJECT_REF>
npx supabase functions deploy match-job --project-ref <PROJECT_REF>
npx supabase functions deploy request-access --project-ref <PROJECT_REF>
npx supabase functions deploy reveal-student --project-ref <PROJECT_REF>
```

If your deployment process already deploys these functions together from this backend checkout, use that established process instead. Do not deploy an unrelated or older backend checkout over the demo functions.

## Seed the fictional demo workspace (demo project only)

The repo already contains fictional demo fixtures in `supabase/seed.sql`, including the Organization demo accounts, jobs, and blind matches. The demo login shortcuts do not generate these records themselves. The seed now clears the deterministic Aarti/Niya lifecycle affiliation rows before replaying their state transitions, making reruns safe after the duplicate `one_current_affiliation` failure.

1. Confirm in Supabase Dashboard → **Project Settings → General** that this is the dedicated AptoHire demo project, not a database containing real users or students.
2. In Supabase **SQL Editor**, run `select value from public.app_config where key='APP_ENV';`. If it returns `production`, stop. Never bypass the guard in `supabase/seed.sql`.
3. Open the local `supabase/seed.sql` from this backend checkout, copy its contents, paste into Supabase **SQL Editor → New query**, and click **Run**. Do this only on the dedicated fictional demo project, as directed in the 2-hour guide.
4. Check that the seeded Organization demo account has a profile and membership, and that its organization has jobs. The newly signed-up email is a separate account; it will not inherit a demo organization's rows unless a matching verified application exists.

Never run `supabase/seed.sql` against a project containing real production data. Do not use `db reset` on a hosted project.

## Verify signup without creating another Auth user

The failed browser attempt already created an Auth user. Do not sign up again with that email.

1. Keep the same browser/profile used for the failed attempt so its Supabase session and signup reference remain available.
2. After the function deployment finishes, open the Organization site's `/auth/callback` route.
3. Expected: the callback completes and redirects to the Organization dashboard.
4. In Supabase **Edge Functions → complete-signup → Logs**, expected: a POST invocation is visible (not only OPTIONS), with a successful response. The browser console should no longer report that `x-client-info` is disallowed.
5. Confirm that the account has an Organization `profiles.role` and expected organization membership. If it does not, inspect the POST's safe error code in the function logs; do not recreate/delete the Auth user as a workaround.

Then open Candidates and Pipeline. Their Edge Function requests should pass CORS too. A successful `match-job` response with `candidate_count: 0` means the CORS issue is fixed but no eligible synthetic candidate match exists for that job; it is a separate data/eligibility issue.


## Repair signup role initialization and recover already-created users (2026-10-31)

The Organization signup can create the Supabase Auth user and then fail with HTTP 503 while `complete-signup` initializes `profiles.role`. The profile role-protection trigger originally checked `current_user`; inside a `SECURITY DEFINER` RPC that is the function owner, not the caller's verified Supabase service-role JWT. Thus the trigger can block the trusted role-initializer RPC. A second signup attempt then correctly reports that the Auth identity already exists.

Apply the new forward migrations `0103_repair_signup_role_initializer.sql` and `0105_fix_signup_role_trigger_guard.sql` to the dedicated hosted demo project before retrying. `0104_add_reviewed_pipeline_stage.sql` is also required for the Organization Pipeline's new internal Reviewed stage. These are forward-only migrations; do not delete the Auth user or profile, and do not seed a real production database. The updated Organization portal auto-retries `complete-signup` at sign-in for a verified user with a missing role, so the user should sign in with the password already chosen rather than attempting Create account again.

After applying migrations, test with one fictional organization account in the dedicated demo project: create the account, verify email if confirmations are enabled, sign in, and confirm the organization portal opens. This hosted verification has not been performed by the assistant.
