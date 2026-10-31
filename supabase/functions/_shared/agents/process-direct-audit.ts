import { createAdminClient } from "../admin.ts";
import { hmacHex } from "../hash.ts";
import { AuditOutputSchema } from "./audit-schema.ts";
import { buildAuditEvidenceBundle, type AuditEvidenceBundle } from "./evidence-bundle.ts";
import { runDirectAudit, enforceTextOnlyAuditOutput, AUDIT_PROMPT_VERSION } from "./audit-direct.ts";
import { providerConfigFingerprint, type ProviderName } from "./providers/direct.ts";
import { isFictionalTestAccountEmail, isLocalSyntheticDirectOptedIn } from "./synthetic-direct.ts";
import { isOwnedVideoObjectPath } from "../retention-path.ts";
import { dispatchN8nAuditJob, isLocalSyntheticN8nOptedIn, isSafeN8nCallbackBaseUrl, isSafeN8nWebhookUrl } from "./n8n-webhook.ts";
import { parseVideoDurationSeconds } from "./video-duration.ts";

type RunRow = { id: string; submission_id: string | null; user_id: string | null; mode: string; status: string };
type SubmissionRow = {
  id: string; student_id: string; title: string; description: string | null; github_url: string | null;
  document_paths: string[] | null; video_path: string | null; video_url: string | null; video_seconds: number | null; live_url: string | null;
  claimed_skill_ids: string[]; originality_answers: unknown; status: string;
};
type ConfigRow = { key: string; value: unknown };

function utcDayStart(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
}
function validDailyCap(value: string | undefined, fallback: number): number {
  if (!value) return fallback;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed >= 1 && parsed <= 10_000 ? parsed : fallback;
}
function boundedConfigNumber(value: unknown, fallback: number, minimum: number, maximum: number): number {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) && parsed >= minimum && parsed <= maximum ? parsed : fallback;
}
async function evidenceCacheMaterial(bundle: AuditEvidenceBundle): Promise<string> {
  const { media, ...textBundle } = bundle;
  const mediaDigests = await Promise.all(media.map(async (item) => {
    const bytes = new ArrayBuffer(item.bytes.byteLength);
    new Uint8Array(bytes).set(item.bytes);
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
    const sha256 = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
    return { ref: item.ref, mimeType: item.mimeType, sha256 };
  }));
  return JSON.stringify({ ...textBundle, media: mediaDigests });
}
async function failRun(runId: string, submissionId: string): Promise<void> {
  const admin = createAdminClient();
  await admin.from("agent_runs").update({ status: "failed", error_code: "DIRECT_AUDIT_FAILED", finished_at: new Date().toISOString() })
    .eq("id", runId).eq("status", "running");
  await admin.from("submissions").update({ status: "failed", updated_at: new Date().toISOString() })
    .eq("id", submissionId).eq("status", "auditing");
}
async function invokeSignedCallback(runId: string, output: unknown, evidenceRefs: string[]): Promise<void> {
  const baseUrl = Deno.env.get("SUPABASE_URL");
  const secret = Deno.env.get("CALLBACK_SECRET");
  if (!baseUrl || !secret) throw new Error("CALLBACK_CONFIG_MISSING");
  const timestamp = String(Math.floor(Date.now() / 1000));
  const body = JSON.stringify({ run_id: runId, output, evidence_refs: evidenceRefs });
  const signature = await hmacHex(secret, `${timestamp}.${body}`);
  const endpoint = new URL("/functions/v1/agent-callback", baseUrl);
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "X-Aptohire-Timestamp": timestamp,
      "X-Aptohire-Signature": `sha256=${signature}`,
    },
    body,
    signal: AbortSignal.timeout(12_000),
  });
  if (!response.ok) throw new Error("AUDIT_CALLBACK_REJECTED");
}

export async function processDirectAudit(runId: string, submissionId: string): Promise<void> {
  const admin = createAdminClient();
  let claimed = false;
  try {
    const { data: runData, error: runError } = await admin.from("agent_runs")
      .select("id,submission_id,user_id,mode,status").eq("id", runId).maybeSingle();
    const run = runData as RunRow | null;
    if (runError || !run || run.submission_id !== submissionId || !run.user_id || !["direct", "n8n"].includes(run.mode) || run.status !== "queued") {
      throw new Error("RUN_NOT_QUEUEABLE");
    }
    if (run.mode === "direct" && !isLocalSyntheticDirectOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"))) {
      throw new Error("SYNTHETIC_DIRECT_NOT_ENABLED");
    }
    const { data: authUser, error: authError } = await admin.auth.admin.getUserById(run.user_id);
    if (authError || !isFictionalTestAccountEmail(authUser.user?.email)) throw new Error("DIRECT_RESTRICTED_TO_SYNTHETIC_ACCOUNT");

    const { data: submissionData, error: submissionError } = await admin.from("submissions")
      .select("id,student_id,title,description,github_url,document_paths,video_path,video_url,video_seconds,live_url,claimed_skill_ids,originality_answers,status")
      .eq("id", submissionId).maybeSingle();
    const submission = submissionData as SubmissionRow | null;
    if (submissionError || !submission || submission.status !== "auditing" || !submission.claimed_skill_ids?.length) {
      throw new Error("SUBMISSION_NOT_AUDITING");
    }
    const { data: claimedRun, error: claimError } = await admin.from("agent_runs").update({ status: "running", stage: "reading", started_at: new Date().toISOString() })
      .eq("id", runId).eq("status", "queued").select("id").maybeSingle();
    if (claimError || !claimedRun) throw new Error("RUN_NOT_CLAIMABLE");
    claimed = true;

    const { data: settingsRows, error: settingsError } = await admin.from("app_config").select("key,value")
      .in("key", ["AGENT_MODE", "AI_KILL_SWITCH", "AI_DAILY_CAP_PER_USER", "BORDERLINE", "VIDEO_MAX_MB", "VIDEO_MAX_SECONDS"]);
    if (settingsError) throw new Error("AUDIT_CONFIG_UNAVAILABLE");
    const settings = new Map<string, unknown>(((settingsRows ?? []) as ConfigRow[]).map((row) => [row.key, row.value]));
    const maxUploadMb = boundedConfigNumber(settings.get("VIDEO_MAX_MB"), 50, 1, 100);
    const maxInlineVideoBytes = Math.min(14_000_000, Math.floor(maxUploadMb * 1024 * 1024));
    const maxVideoSeconds = boundedConfigNumber(settings.get("VIDEO_MAX_SECONDS"), 190, 1, 600);
    if (submission.video_seconds !== null && (!Number.isFinite(submission.video_seconds) || submission.video_seconds < 0 || submission.video_seconds > maxVideoSeconds)) {
      throw new Error("VIDEO_DURATION_OUT_OF_BOUNDS");
    }
    if (settings.get("AGENT_MODE") !== run.mode || settings.get("AI_KILL_SWITCH") !== false) throw new Error("AUDIT_MODE_DISABLED");
    const border = settings.get("BORDERLINE");
    if (!Array.isArray(border) || border.length !== 2 || !border.every((item) => typeof item === "number" && Number.isFinite(item)) || border[0] > border[1]) {
      throw new Error("AUDIT_CONFIG_INVALID");
    }

    const capValue = settings.get("AI_DAILY_CAP_PER_USER");
    const userCap = typeof capValue === "number" && Number.isSafeInteger(capValue) && capValue >= 1 ? capValue : 5;
    const { count, error: countError } = await admin.from("agent_runs").select("id", { count: "exact", head: true })
      .eq("user_id", run.user_id).gte("created_at", utcDayStart());
    if (countError || count === null) throw new Error("USER_DAILY_CAP_UNAVAILABLE");
    if (count > userCap) throw new Error("USER_DAILY_CAP_REACHED");

    const { data: studentData, error: studentError } = await admin.from("students").select("id,full_name,primary_email,location")
      .eq("id", submission.student_id).maybeSingle();
    if (studentError || !studentData) throw new Error("STUDENT_NOT_FOUND");
    const { data: affiliationRows, error: affiliationError } = await admin.from("affiliations").select("university_id,university_name_text")
      .eq("student_id", submission.student_id).eq("is_current", true);
    if (affiliationError) throw new Error("AFFILIATION_LOOKUP_FAILED");
    const sensitiveTerms: string[] = (affiliationRows ?? []).flatMap((item) =>
      typeof item.university_name_text === "string" && item.university_name_text.trim().length >= 3 ? [item.university_name_text] : []);
    const studentNames: string[] = [];
    for (let offset = 0; offset <= 2_000; offset += 500) {
      const { data: students, error: studentsError } = await admin.from("students")
        .select("full_name,primary_email,location").order("id", { ascending: true }).range(offset, offset + 499);
      if (studentsError) throw new Error("STUDENT_DICTIONARY_UNAVAILABLE");
      const page = students ?? [];
      studentNames.push(...page.flatMap((item) => [item.full_name, item.primary_email, item.location]
        .filter((term): term is string => typeof term === "string" && term.trim().length >= 3)));
      if (offset >= 2_000 && page.length > 0) throw new Error("STUDENT_DICTIONARY_LIMIT_EXCEEDED");
      if (page.length < 500) break;
    }
    sensitiveTerms.push(...studentNames);
    const universityNames: string[] = [];
    for (let offset = 0; offset <= 2_000; offset += 500) {
      const { data: universities, error: universityError } = await admin.from("universities")
        .select("name,short_name,city,state").order("id", { ascending: true }).range(offset, offset + 499);
      if (universityError) throw new Error("UNIVERSITY_DICTIONARY_UNAVAILABLE");
      const page = universities ?? [];
      universityNames.push(...page.flatMap((item) => [item.name, item.short_name]
        .filter((term): term is string => typeof term === "string" && term.trim().length >= 3)));
      sensitiveTerms.push(...page.flatMap((item) => [item.city, item.state]
        .filter((term): term is string => typeof term === "string" && term.trim().length >= 3)));
      if (offset >= 2_000 && page.length > 0) throw new Error("UNIVERSITY_DICTIONARY_LIMIT_EXCEEDED");
      if (page.length < 500) break;
    }
    const organizationNames: string[] = [];
    for (let offset = 0; offset <= 2_000; offset += 500) {
      const { data: organizations, error: organizationsError } = await admin.from("organizations")
        .select("name").order("id", { ascending: true }).range(offset, offset + 499);
      if (organizationsError) throw new Error("ORGANIZATION_DICTIONARY_UNAVAILABLE");
      const page = (organizations ?? []).flatMap((item) => typeof item.name === "string" ? [item.name] : []);
      organizationNames.push(...page);
      if (offset >= 2_000 && page.length > 0) throw new Error("ORGANIZATION_DICTIONARY_LIMIT_EXCEEDED");
      if (page.length < 500) break;
    }
    sensitiveTerms.push(...organizationNames);
    const { data: skills, error: skillsError } = await admin.from("skills").select("slug").in("id", submission.claimed_skill_ids);
    if (skillsError) throw new Error("SKILLS_LOOKUP_FAILED");

    const bundle = await buildAuditEvidenceBundle({
      submissionId: submission.id,
      studentId: submission.student_id,
      title: submission.title,
      description: submission.description,
      githubUrl: submission.github_url,
      documentPaths: submission.document_paths ?? [],
      originalityAnswers: submission.originality_answers,
      claimedSkills: (skills ?? []).flatMap((item) => typeof item.slug === "string" ? [item.slug] : []),
      videoAvailable: Boolean(submission.video_path || submission.video_url),
      videoPath: submission.video_path,
      liveUrlAvailable: Boolean(submission.live_url),
      studentName: studentData.full_name,
      studentEmail: studentData.primary_email ?? authUser.user?.email,
      universityNames,
      sensitiveTerms,
    }, {
      fetcher: fetch,
      downloadDocument: async (path) => {
        const { data, error } = await admin.storage.from("documents").download(path);
        if (error || !data || data.size > 100_000) return null;
        return new Uint8Array(await data.arrayBuffer());
      },
      maxVideoDurationSeconds: maxVideoSeconds,
      downloadVideo: async (path) => {
        if (!isOwnedVideoObjectPath(path, submission.student_id, submission.id)) return null;
        const segments = path.split("/");
        const parent = segments.slice(0, -1).join("/");
        const basename = segments.at(-1);
        if (!basename) return null;
        const { data: entries, error: listError } = await admin.storage.from("videos").list(parent, { limit: 20, search: basename });
        const entry = (entries ?? []).find((item) => item.name === basename);
        const declaredSize = Number(entry?.metadata?.size);
        if (listError || !entry || !Number.isFinite(declaredSize) || declaredSize <= 0 || declaredSize > maxInlineVideoBytes) return null;
        const { data, error } = await admin.storage.from("videos").download(path);
        if (error || !data || data.size === 0 || data.size > maxInlineVideoBytes || data.size !== declaredSize) return null;
        const mimeType = data.type.toLowerCase().split(";")[0].trim();
        const bytes = new Uint8Array(await data.arrayBuffer());
        const durationSeconds = parseVideoDurationSeconds(bytes, mimeType);
        if (durationSeconds === null || durationSeconds > maxVideoSeconds) return null;
        return { bytes, mimeType, durationSeconds };
      },
    });
    const evidenceRefs = bundle.evidence.map((item) => item.ref).slice(0, 500);
    const { error: manifestError } = await admin.from("agent_runs").update({ evidence_manifest: evidenceRefs, stage: "scoring" })
      .eq("id", runId).eq("status", "running");
    if (manifestError) throw new Error("EVIDENCE_MANIFEST_WRITE_FAILED");

    if (run.mode === "n8n") {
      const endpoint = Deno.env.get("N8N_AUDIT_WEBHOOK_URL") ?? "";
      const webhookSecret = Deno.env.get("N8N_WEBHOOK_SECRET") ?? "";
      const appEnv = Deno.env.get("APP_ENV");
      if (!isLocalSyntheticN8nOptedIn(appEnv, Deno.env.get("N8N_ALLOW_SYNTHETIC")) || Deno.env.get("N8N_AUDIT_ENABLED") !== "true") {
        throw new Error("N8N_AUDIT_DISABLED_OR_UNSAFE");
      }
      const callbackBase = Deno.env.get("SUPABASE_URL") ?? "";
      const callbackUrl = isSafeN8nCallbackBaseUrl(callbackBase) ? new URL("/functions/v1/agent-callback", callbackBase).toString() : "";
      if (!isSafeN8nWebhookUrl(endpoint, appEnv) || !callbackUrl) throw new Error("N8N_CONFIG_INVALID");
      const { error: provenanceError } = await admin.from("agent_runs").update({
        provider: "n8n", model: "configured-workflow", kind: "audit", prompt_version: AUDIT_PROMPT_VERSION,
        latency_ms: null, stage: "scoring",
      }).eq("id", runId).eq("status", "running");
      if (provenanceError) throw new Error("N8N_PROVENANCE_WRITE_FAILED");
      const accepted = bundle.media.length === 0 && await dispatchN8nAuditJob({ endpoint, appEnv, secret: webhookSecret, runId, callbackUrl, evidence: bundle });
      if (accepted) return;
      // Direct fallback is allowed only for local synthetic tests, never for real users.
      if (!isLocalSyntheticDirectOptedIn(appEnv, Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"))) {
        throw new Error("N8N_DISPATCH_FAILED_NO_SAFE_FALLBACK");
      }
      // Continue through the existing direct provider path with the same evidence manifest.
    }

    const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
    if (!pepper) throw new Error("RATE_LIMITER_UNAVAILABLE");
    const configFingerprint = providerConfigFingerprint("audit");
    const cacheMaterial = await evidenceCacheMaterial(bundle);
    const inputHash = await hmacHex(pepper, `${AUDIT_PROMPT_VERSION}\n${configFingerprint}\n${cacheMaterial}`);
    let output: unknown = null;
    let provider: string | null = null;
    let model: string | null = null;
    let inputTokens: number | null = null;
    let outputTokens: number | null = null;
    let providerLatency: number | null = null;
    const cache = await admin.rpc("read_agent_response_cache", {
      p_kind: "audit", p_input_hash: inputHash, p_prompt_version: AUDIT_PROMPT_VERSION,
    });
    if (cache.error) throw new Error("AUDIT_CACHE_UNAVAILABLE");
    const cached = cache.data?.[0] as { output?: unknown; provider?: string; model?: string } | undefined;
    const parsedCached = cached ? AuditOutputSchema.safeParse(cached.output) : null;
    if (cached && parsedCached?.success && typeof cached.provider === "string" && typeof cached.model === "string") {
      output = { ...parsedCached.data, prompt_version: AUDIT_PROMPT_VERSION };
      provider = cached.provider;
      model = cached.model;
    } else {
      const startedAt = Date.now();
      const direct = await runDirectAudit(bundle, async (providerName: ProviderName) => {
        const providerDate = new Date().toISOString().slice(0, 10);
        const providerHash = await hmacHex(pepper, `audit-provider:${providerName}:${providerDate}`);
        const maxProviderCalls = validDailyCap(Deno.env.get("LLM_DAILY_CAP_PER_PROVIDER"), 50);
        const { data: capRows, error: capError } = await admin.rpc("consume_rate_limit", {
          p_bucket: `audit-provider-${providerName}`,
          p_key_hash: providerHash,
          p_max: maxProviderCalls,
          p_window_seconds: 86_400,
        });
        if (capError || !capRows?.[0]) throw new Error("PROVIDER_CAP_UNAVAILABLE");
        return Boolean(capRows[0].allowed);
      });
      output = direct.output;
      provider = direct.provider;
      model = direct.model;
      inputTokens = direct.inputTokens;
      outputTokens = direct.outputTokens;
      providerLatency = Date.now() - startedAt;
      const { error: cacheWriteError } = await admin.rpc("store_agent_response_cache", {
        p_kind: "audit", p_input_hash: inputHash, p_prompt_version: AUDIT_PROMPT_VERSION,
        p_output: direct.output, p_provider: direct.provider, p_model: direct.model,
      });
      if (cacheWriteError) throw new Error("AUDIT_CACHE_WRITE_FAILED");
    }

    const { error: killSwitchError, data: killSwitchRows } = await admin.from("app_config").select("value").eq("key", "AI_KILL_SWITCH").maybeSingle();
    if (killSwitchError || killSwitchRows?.value !== false) throw new Error("AUDIT_KILL_SWITCH_ACTIVE");
    const checkedOutput = AuditOutputSchema.parse(output);
    const callbackOutput = bundle.media.length
      ? AuditOutputSchema.parse({
        ...checkedOutput,
        criteria: checkedOutput.criteria.map((criterion) => ({
          ...criterion,
          evidence: criterion.evidence.filter((item) => evidenceRefs.includes(item.evidence_ref)),
        })),
      })
      : enforceTextOnlyAuditOutput(checkedOutput, bundle.untrusted_content, new Set(evidenceRefs));
    const { error: provenanceError } = await admin.from("agent_runs").update({
      provider, model, kind: "audit", prompt_version: AUDIT_PROMPT_VERSION, input_hash: inputHash,
      token_estimate: inputTokens === null || outputTokens === null ? null : inputTokens + outputTokens,
      latency_ms: providerLatency,
      stage: "writing",
    }).eq("id", runId).eq("status", "running");
    if (provenanceError) throw new Error("AUDIT_PROVENANCE_WRITE_FAILED");
    await invokeSignedCallback(runId, callbackOutput, evidenceRefs);
  } catch {
    if (claimed) await failRun(runId, submissionId);
  }
}
