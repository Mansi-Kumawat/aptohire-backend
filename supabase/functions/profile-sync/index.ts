import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import type { AuthContext } from "../_shared/auth.ts";
import { withHandler } from "../_shared/handler.ts";
import { ProfileSyncInputSchema, ProfileSyncOutputSchema, type ProfileProposal } from "../_shared/schemas/profile-sync.ts";
import { boundedGitHubJson } from "../_shared/github-profile.ts";
import { githubProposal, linkedinProposal } from "../_shared/agents/profile-proposal.ts";
import { extractProfileProposal, profileProposalFromOutput } from "../_shared/agents/profile-agent.ts";
import { cleanProfileText } from "../_shared/agents/profile-proposal.ts";
import { dispatchN8nAgentJson, isSafeN8nAgentWebhookUrl } from "../_shared/agents/n8n-agent.ts";
import { isLocalSyntheticN8nOptedIn } from "../_shared/agents/n8n-webhook.ts";
import { providerConfigFingerprint } from "../_shared/agents/providers/direct.ts";
import { isFictionalTestAccountEmail, isLocalSyntheticProfileDirectAllowed } from "../_shared/agents/synthetic-direct.ts";

const MAX_EXPORT_BYTES = 20 * 1024 * 1024;
const MAX_GITHUB_RESPONSE_BYTES = 1_000_000;
type Student = { id: string };
type Source = { id: string; student_id: string; source_type: string; auto_approve: boolean; revoked_at: string | null };
type GitHubUser = { name?: string | null; bio?: string | null; html_url?: string; login?: string };
type GitHubRepo = { name?: string; description?: string | null; html_url?: string; language?: string | null; fork?: boolean; archived?: boolean };

function baseUrl(value: string, variable: string): URL {
  let url: URL;
  try { url = new URL(value); } catch { throw new HttpError("SERVICE_UNAVAILABLE", `${variable} is not configured`); }
  if (url.protocol !== "https:" && url.hostname !== "localhost") throw new HttpError("SERVICE_UNAVAILABLE", `${variable} must use HTTPS`);
  return url;
}
async function studentFor(auth: AuthContext): Promise<Student> {
  const { data, error } = await auth.client.from("students").select("id").eq("user_id", auth.user.id).maybeSingle();
  if (error || !data) throw new HttpError("FORBIDDEN", "Complete student registration first");
  return data as Student;
}
async function consumeLimit(admin: ReturnType<typeof createAdminClient>, studentId: string): Promise<void> {
  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Profile sync is not configured");
  const key = await hmacHex(pepper, `profile-sync:${studentId}`);
  const { data, error } = await admin.rpc("consume_rate_limit", { p_bucket: "profile-sync", p_key_hash: key, p_max: 30, p_window_seconds: 86400 });
  if (error || !data?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Profile sync rate limiter is unavailable");
  if (!data[0].allowed) throw new HttpError("RATE_LIMITED", "Profile sync limit reached", undefined, data[0].retry_after);
}
async function ownedSource(auth: AuthContext, sourceId: string, type: string): Promise<Source> {
  const { data, error } = await auth.client.from("profile_sources")
    .select("id,student_id,source_type,auto_approve,revoked_at").eq("id", sourceId).maybeSingle();
  if (error || !data || data.source_type !== type || data.revoked_at) throw new HttpError("NOT_FOUND", "Active profile source not found");
  return data as Source;
}
async function readLinkedInExport(admin: ReturnType<typeof createAdminClient>, studentId: string, filePath: string): Promise<string> {
  const parts = filePath.split("/");
  if (parts.length < 3 || parts[0] !== studentId || parts[1] !== "sources" || parts.some((p) => !p || p === "." || p === "..") || filePath.includes("\\")) {
    throw new HttpError("FORBIDDEN", "Source export path is not owned by this student");
  }
  const parent = parts.slice(0, -1).join("/"); const basename = parts.at(-1)!;
  const { data: entries, error: listError } = await admin.storage.from("documents").list(parent, { limit: 100, search: basename });
  const item = (entries ?? []).find((entry) => entry.name === basename);
  const bytes = Number(item?.metadata?.size);
  if (listError || !item || !Number.isFinite(bytes) || bytes < 0 || bytes > MAX_EXPORT_BYTES) throw new HttpError("VALIDATION_FAILED", "Export file is missing or exceeds 20 MB", { file_path: "Choose a file up to 20 MB in your sources folder." });
  const { data: blob, error } = await admin.storage.from("documents").download(filePath);
  if (error || !blob || blob.size > MAX_EXPORT_BYTES) throw new HttpError("VALIDATION_FAILED", "Could not read export file");
  const raw = new Uint8Array(await blob.arrayBuffer());
  if (basename.toLowerCase().endsWith(".zip")) return await extractZipText(raw);
  if (!/\.(csv|txt)$/i.test(basename)) throw new HttpError("VALIDATION_FAILED", "Upload a CSV, text, or ZIP export", { file_path: "Supported formats are CSV, TXT, or ZIP." });
  return new TextDecoder("utf-8", { fatal: false }).decode(raw).slice(0, 20_000);
}
async function inflateRaw(bytes: Uint8Array, maxBytes: number): Promise<Uint8Array> {
  const stream = new Blob([bytes.slice().buffer as ArrayBuffer]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  const reader = stream.getReader(); const chunks: Uint8Array[] = []; let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read(); if (done) break;
      total += value.byteLength;
      if (total > maxBytes) { await reader.cancel(); throw new HttpError("VALIDATION_FAILED", "Expanded ZIP export exceeds 20 MB"); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const result = new Uint8Array(total); let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.length; }
  return result;
}
async function extractZipText(bytes: Uint8Array): Promise<string> {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let eocd = -1;
  for (let i = Math.max(0, bytes.length - 65_557); i <= bytes.length - 22; i++) if (view.getUint32(i, true) === 0x06054b50) eocd = i;
  if (eocd < 0) throw new HttpError("VALIDATION_FAILED", "ZIP export is invalid");
  const count = view.getUint16(eocd + 10, true); let cursor = view.getUint32(eocd + 16, true); const chunks: string[] = []; let total = 0;
  for (let i = 0; i < count; i++) {
    if (view.getUint32(cursor, true) !== 0x02014b50) throw new HttpError("VALIDATION_FAILED", "ZIP export is invalid");
    const method = view.getUint16(cursor + 10, true); const compressedSize = view.getUint32(cursor + 20, true); const expandedSize = view.getUint32(cursor + 24, true);
    const nameLength = view.getUint16(cursor + 28, true); const extraLength = view.getUint16(cursor + 30, true); const commentLength = view.getUint16(cursor + 32, true); const localOffset = view.getUint32(cursor + 42, true);
    const name = new TextDecoder().decode(bytes.slice(cursor + 46, cursor + 46 + nameLength)); cursor += 46 + nameLength + extraLength + commentLength;
    if (!/\.(csv|txt)$/i.test(name) || name.includes("..")) continue;
    total += expandedSize; if (total > MAX_EXPORT_BYTES) throw new HttpError("VALIDATION_FAILED", "Expanded ZIP export exceeds 20 MB");
    if (view.getUint32(localOffset, true) !== 0x04034b50) throw new HttpError("VALIDATION_FAILED", "ZIP entry is invalid");
    const localName = view.getUint16(localOffset + 26, true); const localExtra = view.getUint16(localOffset + 28, true); const start = localOffset + 30 + localName + localExtra;
    let entry: Uint8Array<ArrayBufferLike> = bytes.slice(start, start + compressedSize);
    if (method === 8) {
      try { entry = await inflateRaw(entry, MAX_EXPORT_BYTES - (total - expandedSize)); }
      catch (error) { if (error instanceof HttpError) throw error; throw new HttpError("VALIDATION_FAILED", "ZIP compression method is not supported"); }
    } else if (method !== 0) throw new HttpError("VALIDATION_FAILED", "ZIP compression method is not supported");
    if (entry.length !== expandedSize) throw new HttpError("VALIDATION_FAILED", "ZIP entry size is invalid");
    chunks.push(new TextDecoder("utf-8", { fatal: false }).decode(entry));
  }
  if (!chunks.length) throw new HttpError("VALIDATION_FAILED", "ZIP contains no CSV or text profile export");
  return chunks.join("\n").slice(0, 20_000);
}
async function persistProposal(admin: ReturnType<typeof createAdminClient>, studentId: string, sourceId: string, proposal: ProfileProposal): Promise<void> {
  const { error } = await admin.rpc("persist_profile_proposal", {
    p_student_id: studentId,
    p_source_id: sourceId,
    p_source_type: proposal.source,
    p_changes: proposal.changes,
  });
  if (error?.code === "P0002") throw new HttpError("CONFLICT", "Profile source was revoked before sync completed");
  if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not save profile proposal");
}

const PROFILE_PROMPT_VERSION = "profile@1";

/** Optional local-synthetic direct or n8n extraction; deterministic parsing always remains the fallback. */
async function assistedLinkedInProposal(
  admin: ReturnType<typeof createAdminClient>,
  userId: string,
  email: string | undefined,
  source: Source,
  content: string,
  ratePepper: string,
): Promise<ProfileProposal | null> {
  if (source.auto_approve !== false) return null;
  const { data: configRows, error: configError } = await admin.from("app_config").select("key,value").in("key", ["AGENT_MODE", "AI_KILL_SWITCH"]);
  if (configError || !configRows || configRows.length !== 2) return null;
  const config = new Map<string, unknown>(configRows.map((row) => [row.key, row.value as unknown]));
  const mode = typeof config.get("AGENT_MODE") === "string" ? config.get("AGENT_MODE") as string : "mock";
  const directEnabled = isLocalSyntheticProfileDirectAllowed({
    agentMode: mode, killSwitch: config.get("AI_KILL_SWITCH"), sourceAutoApprove: source.auto_approve,
    appEnv: Deno.env.get("APP_ENV"), optIn: Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"), email,
  });
  const endpoint = Deno.env.get("N8N_PROFILE_WEBHOOK_URL") ?? "";
  const requestSecret = Deno.env.get("N8N_WEBHOOK_SECRET") ?? "";
  const responseSecret = Deno.env.get("CALLBACK_SECRET") ?? "";
  const n8nEnabled = mode === "n8n" && config.get("AI_KILL_SWITCH") !== true && config.get("AI_KILL_SWITCH") !== "true" &&
    source.auto_approve === false && isLocalSyntheticN8nOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("N8N_ALLOW_SYNTHETIC")) &&
    isFictionalTestAccountEmail(email) && isSafeN8nAgentWebhookUrl(endpoint, "profile") && requestSecret.length >= 32 && responseSecret.length >= 32;
  if (!directEnabled && !n8nEnabled) return null;

  const safeContent = cleanProfileText(content, 20_000);
  const inputHash = await hmacHex(ratePepper, `${PROFILE_PROMPT_VERSION}\n${source.id}\n${safeContent}\n${n8nEnabled ? "n8n" : providerConfigFingerprint("fast")}`);
  const startedAt = Date.now();
  const { data: run, error: runError } = await admin.from("agent_runs").insert({
    user_id: userId, kind: "profile", mode: n8nEnabled ? "n8n" : "direct", status: "running", stage: "writing",
    prompt_version: PROFILE_PROMPT_VERSION, input_hash: inputHash, started_at: new Date(startedAt).toISOString(),
  }).select("id").single();
  if (runError || !run?.id) return null;
  const runId = run.id as string;
  let provider = n8nEnabled ? "n8n" : "gemini";
  let model = n8nEnabled ? "configured-n8n-profile" : Deno.env.get("LLM_MODEL_FAST") ?? "configured-fast-model";
  let tokenEstimate: number | null = null;
  try {
    let proposal: ProfileProposal | null;
    if (n8nEnabled) {
      const generated = await dispatchN8nAgentJson({
        endpoint, appEnv: Deno.env.get("APP_ENV"), syntheticOptIn: Deno.env.get("N8N_ALLOW_SYNTHETIC"),
        requestSecret, responseSecret, runId, kind: "profile", promptVersion: PROFILE_PROMPT_VERSION,
        payload: { source_text: safeContent },
      });
      if (generated === null) throw new Error("N8N_PROFILE_UNAVAILABLE");
      proposal = profileProposalFromOutput(safeContent, generated);
    } else {
      const generated = await extractProfileProposal(safeContent, undefined, async (providerName) => {
        const { data: currentRows, error: currentError } = await admin.from("app_config").select("key,value").in("key", ["AGENT_MODE", "AI_KILL_SWITCH"]);
        if (currentError || !currentRows || currentRows.length !== 2) throw new Error("AGENT_CONFIGURATION_UNAVAILABLE");
        const currentConfig = new Map<string, unknown>(currentRows.map((row) => [row.key, row.value as unknown]));
        if (currentConfig.get("AGENT_MODE") !== "direct" || currentConfig.get("AI_KILL_SWITCH") === true || currentConfig.get("AI_KILL_SWITCH") === "true") return false;
        const rawCap = Number(Deno.env.get("LLM_DAILY_CAP_PER_PROVIDER") ?? 1000);
        const max = Number.isInteger(rawCap) && rawCap > 0 ? Math.min(rawCap, 100_000) : 1000;
        const providerHash = await hmacHex(ratePepper, `llm-provider:${providerName}`);
        const { data, error } = await admin.rpc("consume_rate_limit", {
          p_bucket: `llm-provider:${providerName}`, p_key_hash: providerHash, p_max: max, p_window_seconds: 86400,
        });
        if (error || !data?.[0]) throw new Error("PROVIDER_CAP_UNAVAILABLE");
        return data[0].allowed === true;
      });
      provider = generated.provider;
      model = generated.model;
      tokenEstimate = generated.tokenEstimate;
      proposal = generated.proposal;
    }
    await admin.from("agent_runs").update({ status: "completed", stage: "done", provider, model, token_estimate: tokenEstimate,
      latency_ms: Date.now() - startedAt, finished_at: new Date().toISOString() }).eq("id", runId);
    return proposal;
  } catch {
    await admin.from("agent_runs").update({ status: "failed", error_code: n8nEnabled ? "N8N_PROFILE_FAILED" : "DIRECT_PROVIDER_FAILED",
      latency_ms: Date.now() - startedAt, finished_at: new Date().toISOString() }).eq("id", runId);
    return null;
  }
}

async function callback(request: Request): Promise<Response> {
  const url = new URL(request.url); const code = url.searchParams.get("code"); const state = url.searchParams.get("state");
  const studentPortal = baseUrl(Deno.env.get("STUDENT_PORTAL_URL") ?? "", "STUDENT_PORTAL_URL");
  const fail = (reason: string) => { const target = new URL("/profile?tab=sources&connected=github&error=" + encodeURIComponent(reason), studentPortal); return Response.redirect(target, 303); };
  if (!code || !state || code.length > 2048 || state.length > 512) return fail("oauth_failed");
  const pepper = Deno.env.get("OAUTH_STATE_PEPPER"); const clientId = Deno.env.get("GITHUB_CLIENT_ID"); const clientSecret = Deno.env.get("GITHUB_CLIENT_SECRET"); const callbackUrl = Deno.env.get("GITHUB_REDIRECT_URI");
  if (!pepper || !clientId || !clientSecret || !callbackUrl) return fail("oauth_unavailable");
  const admin = createAdminClient(); const stateHash = await hmacHex(pepper, state);
  const { data: consumed, error: stateError } = await admin.rpc("consume_github_oauth_state", { p_state_hash: stateHash });
  const row = (consumed as Array<{ student_id: string; user_id: string; source_id: string }> | null)?.[0];
  if (stateError || !row) return fail("oauth_expired");
  let token: string;
  try {
    const response = await fetch("https://github.com/login/oauth/access_token", {
      method: "POST", headers: { accept: "application/json", "content-type": "application/json" },
      body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, code, redirect_uri: callbackUrl, state }), redirect: "error", signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) return fail("oauth_exchange_failed");
    const body = await boundedGitHubJson(response, 16_000) as { access_token?: string; token_type?: string };
    if (!body || typeof body !== "object" || typeof body.access_token !== "string" || body.access_token.length > 4096 || body.token_type?.toLowerCase() !== "bearer") return fail("oauth_exchange_failed");
    token = body.access_token;
  } catch { return fail("oauth_exchange_failed"); }
  const { error: storeError } = await admin.rpc("store_profile_source_token", { p_source_id: row.source_id, p_student_id: row.student_id, p_token: token });
  token = "";
  if (storeError) return fail("oauth_store_failed");
  const target = new URL("/profile?tab=sources&connected=github", studentPortal);
  return Response.redirect(target, 303);
}

const handler = withHandler({ auth: "jwt", roles: ["student"], input: ProfileSyncInputSchema, output: ProfileSyncOutputSchema }, async (input, context) => {
  const auth = context.auth; if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const student = await studentFor(auth); const admin = createAdminClient(); await consumeLimit(admin, student.id);
  if (input.action === "github_start") {
    const clientId = Deno.env.get("GITHUB_CLIENT_ID"); const callbackUrl = Deno.env.get("GITHUB_REDIRECT_URI"); const statePepper = Deno.env.get("OAUTH_STATE_PEPPER");
    if (!clientId || !callbackUrl || !statePepper) throw new HttpError("SERVICE_UNAVAILABLE", "GitHub profile sync is not configured");
    baseUrl(callbackUrl, "GITHUB_REDIRECT_URI");
    const { data: existing } = await admin.from("profile_sources").select("id").eq("student_id", student.id).eq("source_type", "github").is("revoked_at", null).limit(1).maybeSingle();
    let sourceId = existing?.id as string | undefined;
    if (!sourceId) {
      const { data, error } = await admin.from("profile_sources").insert({ student_id: student.id, source_type: "github", auto_approve: false, consented_at: new Date().toISOString() }).select("id").single();
      if (error || !data) throw new HttpError("SERVICE_UNAVAILABLE", "Could not create GitHub source consent");
      sourceId = data.id as string;
    }
    const state = Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) => b.toString(16).padStart(2, "0")).join("");
    const stateHash = await hmacHex(statePepper, state);
    const { error } = await admin.rpc("issue_github_oauth_state", { p_user_id: auth.user.id, p_student_id: student.id, p_source_id: sourceId, p_state_hash: stateHash });
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not start GitHub authorization");
    const authorize = new URL("https://github.com/login/oauth/authorize");
    authorize.searchParams.set("client_id", clientId); authorize.searchParams.set("redirect_uri", callbackUrl); authorize.searchParams.set("scope", "read:user"); authorize.searchParams.set("state", state);
    return { body: { authorize_url: authorize.toString() } };
  }
  if (input.action === "github_sync") {
    const source = await ownedSource(auth, input.source_id, "github");
    const { data: tokenData, error: tokenError } = await admin.rpc("read_profile_source_token", { p_source_id: source.id, p_student_id: student.id });
    let token = tokenData as string | null;
    if (tokenError || !token) throw new HttpError("CONFLICT", "Reconnect the GitHub source before syncing");
    const headers: Record<string, string> = { authorization: `Bearer ${token}`, accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28" };
    let userResponse: Response;
    let reposResponse: Response;
    try {
      [userResponse, reposResponse] = await Promise.all([
        fetch("https://api.github.com/user", { headers, redirect: "error", signal: AbortSignal.timeout(8_000) }),
        fetch("https://api.github.com/user/repos?visibility=public&per_page=100&sort=updated", { headers, redirect: "error", signal: AbortSignal.timeout(8_000) }),
      ]);
    } catch {
      throw new HttpError("SERVICE_UNAVAILABLE", "GitHub is temporarily unavailable");
    } finally {
      // Best-effort reduce the lifetime of the bearer string in this function's mutable references.
      headers.authorization = "";
      token = "";
    }
    if (!userResponse.ok || !reposResponse.ok) throw new HttpError("SERVICE_UNAVAILABLE", "GitHub is temporarily unavailable");
    let userValue: unknown;
    let reposValue: unknown;
    try {
      [userValue, reposValue] = await Promise.all([
        boundedGitHubJson(userResponse, MAX_GITHUB_RESPONSE_BYTES),
        boundedGitHubJson(reposResponse, MAX_GITHUB_RESPONSE_BYTES),
      ]);
    } catch {
      throw new HttpError("SERVICE_UNAVAILABLE", "GitHub returned an invalid or oversized response");
    }
    if (!userValue || typeof userValue !== "object" || Array.isArray(userValue) || !Array.isArray(reposValue)) {
      throw new HttpError("SERVICE_UNAVAILABLE", "GitHub returned an invalid response");
    }
    const user = userValue as GitHubUser;
    const repos = reposValue as GitHubRepo[];
    const proposal = githubProposal(user, repos.slice(0, 100)); await persistProposal(admin, student.id, source.id, proposal);
    const lastSynced = new Date().toISOString();
    return { body: { proposals: proposal.changes.length ? [proposal] : [], last_synced_at: lastSynced } };
  }
  if (input.action === "linkedin_parse") {
    let sourceId = input.source_id; let source: Source | null = null;
    if (sourceId) source = await ownedSource(auth, sourceId, "linkedin_export");
    if (!source) {
      const { data, error } = await admin.from("profile_sources").insert({ student_id: student.id, source_type: "linkedin_export", auto_approve: false, consented_at: new Date().toISOString() }).select("id,student_id,source_type,auto_approve,revoked_at").single();
      if (error || !data) throw new HttpError("SERVICE_UNAVAILABLE", "Could not record LinkedIn export consent");
      source = data as Source; sourceId = source.id;
    }
    const content = input.text ?? await readLinkedInExport(admin, student.id, input.file_path!);
    let proposal = linkedinProposal(content);
    const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
    if (ratePepper && source.auto_approve === false) {
      const directProposal = await assistedLinkedInProposal(admin, auth.user.id, auth.user.email, source, content, ratePepper);
      if (directProposal?.changes.length) proposal = directProposal;
    }
    await persistProposal(admin, student.id, sourceId!, proposal);
    const lastSynced = new Date().toISOString();
    return { body: { proposals: proposal.changes.length ? [proposal] : [], last_synced_at: lastSynced } };
  }
  const source = await ownedSource(auth, input.source_id, "github").catch(async (error) => {
    const linkedin = await ownedSource(auth, input.source_id, "linkedin_export").catch(() => null);
    if (linkedin) return linkedin;
    throw error;
  });
  const { error } = await admin.rpc("revoke_profile_source", { p_user_id: auth.user.id, p_source_id: source.id, p_student_id: student.id, p_delete_data: input.delete_data ?? false });
  if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not revoke profile source");
  return { body: { last_synced_at: new Date().toISOString() } };
});

Deno.serve(async (request) => {
  const url = new URL(request.url);
  if (request.method === "GET" && (url.searchParams.has("state") || url.searchParams.has("error"))) return await callback(request);
  return await handler(request);
});
