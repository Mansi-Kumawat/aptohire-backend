import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { withHandler } from "../_shared/handler.ts";
import { hmacHex } from "../_shared/hash.ts";
import { SubmitProjectInputSchema, SubmitProjectOutputSchema } from "../_shared/schemas/submit-project.ts";
import { isFictionalTestAccountEmail, isLocalSyntheticDirectOptedIn } from "../_shared/agents/synthetic-direct.ts";
import { isOwnedVideoObjectPath } from "../_shared/retention-path.ts";
import { isLocalSyntheticN8nOptedIn, isSafeN8nCallbackBaseUrl, isSafeN8nWebhookUrl } from "../_shared/agents/n8n-webhook.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };

type ConfigRow = { key: string; value: unknown };
type SubmissionRow = {
  id: string;
  title: string;
  status: string;
  claimed_skill_ids: string[];
  video_path: string | null;
  video_url: string | null;
  video_seconds: number | null;
  originality_answers: unknown;
};

function configNumber(config: Map<string, unknown>, key: string, fallback: number): number {
  const value = config.get(key);
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function configBoolean(config: Map<string, unknown>, key: string, fallback: boolean): boolean {
  const value = config.get(key);
  return typeof value === "boolean" ? value : fallback;
}
function configString(config: Map<string, unknown>, key: string): string | null {
  const value = config.get(key);
  return typeof value === "string" ? value : null;
}
function isSafeHttpsUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password && url.hostname.length > 0;
  } catch {
    return false;
  }
}

async function dispatchAudit(runId: string, submissionId: string): Promise<void> {
  const admin = createAdminClient();
  const baseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  let dispatched = false;
  try {
    if (!baseUrl || !serviceKey) throw new Error("INTERNAL_AUDIT_CONFIG_MISSING");
    const endpoint = new URL("/functions/v1/audit-submission", baseUrl);
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { authorization: `Bearer ${serviceKey}`, apikey: serviceKey, "content-type": "application/json" },
      body: JSON.stringify({ run_id: runId }),
      signal: AbortSignal.timeout(8_000),
    });
    dispatched = response.ok;
  } catch {
    dispatched = false;
  }
  if (dispatched) return;
  const { data: failed } = await admin.from("agent_runs").update({ status: "failed", error_code: "AUDIT_DISPATCH_FAILED" })
    .eq("id", runId).eq("status", "queued").select("id").maybeSingle();
  if (failed) await admin.from("submissions").update({ status: "failed", updated_at: new Date().toISOString() })
    .eq("id", submissionId).eq("status", "auditing");
}


const handler = withHandler({
  auth: "jwt",
  roles: ["student"],
  input: SubmitProjectInputSchema,
  output: SubmitProjectOutputSchema,
}, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const admin = createAdminClient();
  const { data: student, error: studentError } = await auth.client.from("students")
    .select("id").eq("user_id", auth.user.id).maybeSingle();
  if (studentError || !student) throw new HttpError("FORBIDDEN", "Complete student registration first");

  const { data: submissionData, error: submissionError } = await auth.client.from("submissions")
    .select("id,title,status,claimed_skill_ids,video_path,video_url,video_seconds,originality_answers")
    .eq("id", input.submission_id).eq("student_id", student.id).maybeSingle();
  if (submissionError || !submissionData) throw new HttpError("NOT_FOUND", "Submission not found");
  const submission = submissionData as SubmissionRow;
  if (!(["draft", "failed"] as string[]).includes(submission.status)) throw new HttpError("CONFLICT", "Submission cannot be submitted in its current state");
  if (!submission.claimed_skill_ids?.length) throw new HttpError("MISSING_SKILLS", "Claim at least one skill before submitting");

  const { data: configRows, error: configError } = await admin.from("app_config").select("key,value")
    .in("key", ["AGENT_MODE", "AI_KILL_SWITCH", "AI_DAILY_CAP_PER_USER", "REQUIRE_VIDEO", "VIDEO_MAX_MB", "VIDEO_MAX_SECONDS"]);
  if (configError) throw new HttpError("SERVICE_UNAVAILABLE", "Submission settings are unavailable");
  const config = new Map<string, unknown>(((configRows ?? []) as ConfigRow[]).map((item) => [item.key, item.value]));
  if (configBoolean(config, "AI_KILL_SWITCH", false)) throw new HttpError("KILL_SWITCH", "Project review is temporarily paused");
  const configuredMode = configString(config, "AGENT_MODE");
  if (configuredMode !== "mock" && configuredMode !== "direct" && configuredMode !== "n8n") throw new HttpError("SERVICE_UNAVAILABLE", "Configured audit adapter is not available");
  const mode: "mock" | "direct" | "n8n" = configuredMode;
  if (!isFictionalTestAccountEmail(auth.user.email)) throw new HttpError("FORBIDDEN", "Synthetic audits are restricted to fictional demo accounts");
  if (mode === "direct" && !isLocalSyntheticDirectOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"))) {
    throw new HttpError("FORBIDDEN", "Direct audits require explicit local synthetic-data opt-in");
  }
  if (mode === "n8n" && (!isLocalSyntheticN8nOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("N8N_ALLOW_SYNTHETIC")) ||
    Deno.env.get("N8N_AUDIT_ENABLED") !== "true" || !isSafeN8nWebhookUrl(Deno.env.get("N8N_AUDIT_WEBHOOK_URL") ?? "", Deno.env.get("APP_ENV")) ||
    (Deno.env.get("N8N_WEBHOOK_SECRET")?.length ?? 0) < 32 || (Deno.env.get("CALLBACK_SECRET")?.length ?? 0) < 32 ||
    !isSafeN8nCallbackBaseUrl(Deno.env.get("SUPABASE_URL") ?? ""))) {
    throw new HttpError("SERVICE_UNAVAILABLE", "The n8n audit adapter is not configured");
  }

  const hasVideo = Boolean(submission.video_path || submission.video_url);
  if (configBoolean(config, "REQUIRE_VIDEO", true) && !hasVideo) throw new HttpError("VIDEO_REQUIRED", "Add a video before submitting");
  if (submission.video_url && !isSafeHttpsUrl(submission.video_url)) {
    throw new HttpError("VALIDATION_FAILED", "Video URL must be a valid HTTPS link", { video_url: "Use a valid HTTPS URL without embedded credentials." });
  }
  if (submission.video_path) {
    if (!isOwnedVideoObjectPath(submission.video_path, student.id, submission.id)) {
      throw new HttpError("FORBIDDEN", "Video object is not owned by this submission");
    }
    const segments = submission.video_path.split("/");
    const parent = segments.slice(0, -1).join("/");
    const basename = segments[segments.length - 1];
    const { data: objects, error: objectError } = await admin.storage.from("videos").list(parent, { limit: 100, search: basename });
    const object = (objects ?? []).find((entry) => entry.name === basename);
    if (objectError || !object) throw new HttpError("VALIDATION_FAILED", "Uploaded video object was not found", { video_path: "Upload the video before submitting." });
    const metadata = object.metadata && typeof object.metadata === "object" ? object.metadata as Record<string, unknown> : {};
    const byteSize = Number(metadata.size);
    const maxBytes = configNumber(config, "VIDEO_MAX_MB", 50) * 1024 * 1024;
    if (!Number.isFinite(byteSize) || byteSize < 0 || byteSize > maxBytes) {
      throw new HttpError("VALIDATION_FAILED", "Uploaded video exceeds the configured size limit", { video_path: "Video file is too large or its size could not be verified." });
    }
  }
  const maxSeconds = configNumber(config, "VIDEO_MAX_SECONDS", 190);
  if (submission.video_seconds !== null && submission.video_seconds > maxSeconds) {
    throw new HttpError("VIDEO_TOO_LONG", "Video exceeds the configured duration limit");
  }
  if (submission.video_url && !submission.video_path) {
    // TODO(decision): remote URL byte-size probing needs an allowlisted fetcher to avoid SSRF.
  }

  const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!ratePepper) throw new HttpError("SERVICE_UNAVAILABLE", "Submission rate limiter is unavailable");
  const userHash = await hmacHex(ratePepper, `submit-project:${auth.user.id}`);
  const dailyCap = Math.max(1, Math.min(100, Math.floor(configNumber(config, "AI_DAILY_CAP_PER_USER", 5))));
  const { data: limitRows, error: limitError } = await admin.rpc("consume_rate_limit", {
    p_bucket: "submit-project",
    p_key_hash: userHash,
    p_max: dailyCap,
    p_window_seconds: 86400,
  });
  if (limitError || !limitRows?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Submission rate limiter is unavailable");
  if (!limitRows[0].allowed) throw new HttpError("QUOTA_EXCEEDED", "Daily submission limit reached", undefined, limitRows[0].retry_after);

  const { data: result, error: submitError } = await admin.rpc("submit_project", {
    p_actor_id: auth.user.id,
    p_submission_id: submission.id,
    p_mode: mode,
  });
  if (submitError || !result?.[0]) {
    if (submitError?.code === "40001") throw new HttpError("CONFLICT", "Submission state or audit mode changed; reload and retry");
    if (submitError?.code === "23514") throw new HttpError("MISSING_SKILLS", "Claim at least one skill before submitting");
    if (submitError?.code === "42501") throw new HttpError("FORBIDDEN", "Student submission is not authorized");
    if (submitError?.code === "P0002") throw new HttpError("NOT_FOUND", "Submission not found");
    if (submitError?.code === "55000") throw new HttpError("KILL_SWITCH", "Project review is temporarily paused");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not queue the project for review");
  }
  const runId = result[0].run_id as string;
  try {
    EdgeRuntime.waitUntil(dispatchAudit(runId, submission.id));
  } catch {
    await admin.from("agent_runs").update({ status: "failed", error_code: "AUDIT_PIPELINE_FAILED" }).eq("id", runId);
    await admin.from("submissions").update({ status: "failed", updated_at: new Date().toISOString() }).eq("id", submission.id).eq("status", "auditing");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not start the demo audit worker");
  }
  return { status: 202, body: { run_id: runId, status: "queued" as const, mode } };
});

Deno.serve(handler);
