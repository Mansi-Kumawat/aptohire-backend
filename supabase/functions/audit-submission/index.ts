import { createAdminClient } from "../_shared/admin.ts";
import { processDemoAudit } from "../_shared/agents/process-demo-audit.ts";
import { processDirectAudit } from "../_shared/agents/process-direct-audit.ts";
import { isFictionalTestAccountEmail, isLocalSyntheticDirectOptedIn } from "../_shared/agents/synthetic-direct.ts";
import { HttpError } from "../_shared/errors.ts";
import { AuditSubmissionInputSchema, AuditSubmissionOutputSchema } from "../_shared/schemas/audit-submission.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };
type RunRow = { id: string; submission_id: string | null; user_id: string | null; mode: string; status: string };

function sameSecret(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left); const b = new TextEncoder().encode(right);
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return difference === 0;
}
function response(error: HttpError): Response { return error.toResponse({ "cache-control": "no-store" }); }
async function failRun(admin: ReturnType<typeof createAdminClient>, runId: string, submissionId: string, code: string): Promise<void> {
  await admin.from("agent_runs").update({ status: "failed", error_code: code }).eq("id", runId).eq("status", "queued");
  await admin.from("submissions").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", submissionId).eq("status", "auditing");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return response(new HttpError("VALIDATION_FAILED", "Method not allowed"));
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const bearer = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1] ?? "";
  if (!serviceKey || !sameSecret(bearer, serviceKey)) return response(new HttpError("UNAUTHENTICATED", "Internal service authorization required"));
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > 2048) return response(new HttpError("VALIDATION_FAILED", "Request is too large"));
  let raw: unknown;
  try {
    const body = await request.text();
    if (new TextEncoder().encode(body).byteLength > 2048) return response(new HttpError("VALIDATION_FAILED", "Request is too large"));
    raw = JSON.parse(body);
  } catch { return response(new HttpError("VALIDATION_FAILED", "Request body must be JSON")); }
  const parsed = AuditSubmissionInputSchema.safeParse(raw);
  if (!parsed.success) return response(new HttpError("VALIDATION_FAILED", "Invalid internal audit request"));
  const admin = createAdminClient();
  const { data, error } = await admin.from("agent_runs").select("id,submission_id,user_id,mode,status").eq("id", parsed.data.run_id).maybeSingle();
  const run = data as RunRow | null;
  if (error || !run || !run.submission_id || !run.user_id) return response(new HttpError("NOT_FOUND", "Queued run not found"));
  if (run.status !== "queued") return response(new HttpError("CONFLICT", "Run is no longer queued"));
  if (run.mode !== "mock" && run.mode !== "direct" && run.mode !== "n8n") {
    await failRun(admin, run.id, run.submission_id, "PROVIDER_UNAVAILABLE");
    return response(new HttpError("SERVICE_UNAVAILABLE", "Configured audit adapter is not available"));
  }
  const { data: authUser, error: authError } = await admin.auth.admin.getUserById(run.user_id);
  if (authError || !isFictionalTestAccountEmail(authUser.user?.email)) {
    await failRun(admin, run.id, run.submission_id, "SYNTHETIC_ACCOUNT_REQUIRED");
    return response(new HttpError("FORBIDDEN", "Synthetic audits are restricted to fictional demo accounts"));
  }
  if (run.mode === "direct" && !isLocalSyntheticDirectOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"))) {
    await failRun(admin, run.id, run.submission_id, "DIRECT_MODE_DISABLED");
    return response(new HttpError("FORBIDDEN", "Direct audits require explicit local synthetic-data opt-in"));
  }
  const checked = AuditSubmissionOutputSchema.safeParse({ run_id: run.id, status: "running" });
  if (!checked.success) return response(new HttpError("SERVICE_UNAVAILABLE", "Could not prepare audit response"));
  if (run.mode === "mock") EdgeRuntime.waitUntil(processDemoAudit(run.id, run.submission_id));
  else EdgeRuntime.waitUntil(processDirectAudit(run.id, run.submission_id));
  return Response.json(checked.data, { status: 202, headers: { "cache-control": "no-store" } });
});
