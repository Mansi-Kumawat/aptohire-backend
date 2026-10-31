import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { AdminRetryRunInputSchema, AdminRetryRunOutputSchema } from "../_shared/schemas/admin-retry-run.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };
type RetryRow = { run_id: string; status: string; mode: string };
async function dispatchAudit(runId: string, failedRunId: string): Promise<void> {
  const admin = createAdminClient(); const baseUrl = Deno.env.get("SUPABASE_URL"); const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  let ok = false;
  try {
    if (!baseUrl || !key) throw new Error("INTERNAL_CONFIG_MISSING");
    const result = await fetch(new URL("/functions/v1/audit-submission", baseUrl), {
      method: "POST", headers: { authorization: `Bearer ${key}`, apikey: key, "content-type": "application/json" },
      body: JSON.stringify({ run_id: runId }), signal: AbortSignal.timeout(8_000),
    });
    ok = result.ok;
  } catch { ok = false; }
  if (ok) return;
  const { data: failed } = await admin.from("agent_runs").update({ status: "failed", error_code: "AUDIT_DISPATCH_FAILED" })
    .eq("id", runId).eq("status", "queued").select("submission_id").maybeSingle();
  if (failed?.submission_id) await admin.from("submissions").update({ status: "failed", updated_at: new Date().toISOString() })
    .eq("id", failed.submission_id).eq("status", "auditing");
  await admin.from("audit_log").insert({ actor_id: null, action: "agent_retry_dispatch_failed", target_type: "agent_run", target_id: failedRunId, metadata: { new_run_id: runId } });
}
const handler = withHandler({ auth: "jwt", roles: ["admin"], aal2: true, input: AdminRetryRunInputSchema, output: AdminRetryRunOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: gate, error: gateError } = await auth.client.from("admin_counts_v").select("failed_runs_24h").limit(1);
  if (gateError || !gate?.length) throw new HttpError("FORBIDDEN", "A current MFA-verified admin session is required");
  const admin = createAdminClient(); const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  const actorHash = await hmacHex(pepper, auth.user.id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", { p_bucket: "admin-retry-run", p_key_hash: actorHash, p_max: 10, p_window_seconds: 60 });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Retry limit reached", undefined, limits[0].retry_after);
  const { data, error } = await admin.rpc("admin_retry_run", { p_actor_id: auth.user.id, p_failed_run_id: input.run_id });
  if (error) {
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "Admin authorization or demo-account restriction failed");
    if (error.code === "40001") throw new HttpError("CONFLICT", "Run or submission is no longer retryable");
    if (error.code === "23514") throw new HttpError("MISSING_SKILLS", "Submission has no claimed skills");
    if (error.code === "55000") throw new HttpError("KILL_SWITCH", "Retry is unavailable while processing is paused or unsupported");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not retry run");
  }
  const row = (data as RetryRow[] | null)?.[0];
  if (!row) throw new HttpError("SERVICE_UNAVAILABLE", "Retry did not return a run");
  EdgeRuntime.waitUntil(dispatchAudit(row.run_id, input.run_id));
  return { status: 202, body: { run_id: row.run_id, status: "queued" as const, mode: "mock" as const } };
});
Deno.serve(handler);
