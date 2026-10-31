import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { verifyHmacCallback } from "../_shared/hmac-callback.ts";
import { postprocessAudit } from "../_shared/agents/postprocess-audit.ts";
import { AgentCallbackInputSchema, AgentCallbackOutputSchema } from "../_shared/schemas/agent-callback.ts";

type RunRow = { id: string; submission_id: string | null; mode: string; status: string; evidence_manifest: string[] | null };
type SubmissionRow = { id: string; title: string; originality_answers: unknown };
type ConfigRow = { key: string; value: unknown };
function errorResponse(error: HttpError): Response { return error.toResponse({ "cache-control": "no-store" }); }

Deno.serve(async (request) => {
  if (request.method !== "POST") return errorResponse(new HttpError("VALIDATION_FAILED", "Method not allowed"));
  const secret = Deno.env.get("CALLBACK_SECRET");
  const timestamp = request.headers.get("X-Aptohire-Timestamp") ?? "";
  const suppliedSignature = request.headers.get("X-Aptohire-Signature") ?? "";
  if (!secret || !/^\d{10}$/.test(timestamp) || !/^(?:sha256=)?[a-f0-9]{64}$/i.test(suppliedSignature)) {
    return errorResponse(new HttpError("UNAUTHENTICATED", "Callback signature is invalid"));
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > 256 * 1024) return errorResponse(new HttpError("VALIDATION_FAILED", "Callback body is too large"));
  if (!await verifyHmacCallback(secret, timestamp, rawBody, suppliedSignature)) {
    return errorResponse(new HttpError("UNAUTHENTICATED", "Callback signature or timestamp is invalid"));
  }
  let body: unknown;
  try { body = JSON.parse(rawBody); } catch { return errorResponse(new HttpError("VALIDATION_FAILED", "Callback body must be valid JSON")); }
  const parsed = AgentCallbackInputSchema.safeParse(body);
  if (!parsed.success) return errorResponse(new HttpError("VALIDATION_FAILED", "Callback output did not match the audit contract"));

  const admin = createAdminClient();
  const { data: runData, error: runError } = await admin.from("agent_runs")
    .select("id,submission_id,mode,status,evidence_manifest").eq("id", parsed.data.run_id).maybeSingle();
  const run = runData as RunRow | null;
  if (runError || !run || !run.submission_id) return errorResponse(new HttpError("NOT_FOUND", "Agent run not found"));
  if (run.status !== "running" || !["direct", "n8n"].includes(run.mode)) return errorResponse(new HttpError("CONFLICT", "Agent run is not awaiting a callback"));
  // Empty means the trusted worker found no evidence bundle. Such a callback may complete
  // only as insufficient-evidence output; post-processing and apply_audit enforce that path.
  const manifest = run.evidence_manifest ?? [];
  const { data: configRows, error: configError } = await admin.from("app_config").select("key,value").in("key", ["BORDERLINE", "AI_KILL_SWITCH"]);
  if (configError) return errorResponse(new HttpError("SERVICE_UNAVAILABLE", "Scoring configuration is unavailable"));
  const config = new Map<string, unknown>(((configRows ?? []) as ConfigRow[]).map((item) => [item.key, item.value]));
  const killSwitch = config.get("AI_KILL_SWITCH");
  if (typeof killSwitch !== "boolean") return errorResponse(new HttpError("SERVICE_UNAVAILABLE", "Audit configuration is invalid"));
  if (killSwitch) return errorResponse(new HttpError("KILL_SWITCH", "Audit processing is temporarily paused"));
  const borderline = config.get("BORDERLINE");
  if (!Array.isArray(borderline) || borderline.length !== 2 ||
    !borderline.every((value) => typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 100) ||
    borderline[0] > borderline[1]) {
    return errorResponse(new HttpError("SERVICE_UNAVAILABLE", "Scoring configuration is invalid"));
  }
  const { data: submissionData, error: submissionError } = await admin.from("submissions")
    .select("id,title,originality_answers").eq("id", run.submission_id).maybeSingle();
  const submission = submissionData as SubmissionRow | null;
  if (submissionError || !submission) return errorResponse(new HttpError("NOT_FOUND", "Audit submission not found"));
  const untrusted = `${submission.title}\n${JSON.stringify(submission.originality_answers ?? {})}`.slice(0, 20_000);
  const processed = (() => {
    try { return postprocessAudit(parsed.data.output, new Set(manifest), untrusted, borderline[0] as number, borderline[1] as number); }
    catch { return null; }
  })();
  if (!processed) return errorResponse(new HttpError("VALIDATION_FAILED", "Audit output could not be post-processed"));
  const { data, error } = await admin.rpc("complete_agent_run", {
    p_run_id: run.id,
    p_output: processed,
    p_evidence_refs: parsed.data.evidence_refs,
  });
  if (error) {
    if (error.code === "40001") return errorResponse(new HttpError("CONFLICT", "Agent run has already been completed or is no longer active"));
    if (error.code === "22023") return errorResponse(new HttpError("VALIDATION_FAILED", "Callback evidence does not match the job manifest"));
    if (error.code === "P0002") return errorResponse(new HttpError("NOT_FOUND", "Agent run not found"));
    if (error.code === "55000") return errorResponse(new HttpError("KILL_SWITCH", "Audit processing is temporarily paused"));
    return errorResponse(new HttpError("SERVICE_UNAVAILABLE", "Could not complete the agent run"));
  }
  const result = (data as Array<{ audit_id: string; status: string }> | null)?.[0];
  const output = AgentCallbackOutputSchema.safeParse({ run_id: run.id, audit_id: result?.audit_id, status: result?.status });
  if (!output.success) return errorResponse(new HttpError("SERVICE_UNAVAILABLE", "Agent callback did not return a valid receipt"));
  return Response.json(output.data, { status: 200, headers: { "cache-control": "no-store" } });
});
