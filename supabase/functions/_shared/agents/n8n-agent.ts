import { hmacHex } from "../hash.ts";
import { verifyHmacCallback } from "../hmac-callback.ts";

export type N8nAgentKind = "assign" | "match" | "profile";

export type N8nAgentDispatchInput = {
  endpoint: string;
  appEnv: string | undefined;
  syntheticOptIn: string | undefined;
  requestSecret: string;
  responseSecret: string;
  runId: string;
  kind: N8nAgentKind;
  promptVersion: string;
  payload: unknown;
};

function isPrivateHost(hostname: string): boolean {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, "").replace(/\.$/, "");
  return !host || host === "localhost" || host.endsWith(".localhost") || host.endsWith(".local") || host.endsWith(".internal") ||
    host.endsWith(".test") || host.endsWith(".invalid") || host === "127.0.0.1" || host.startsWith("127.") ||
    host.startsWith("0.") || host.startsWith("10.") || host.startsWith("169.254.") || host.startsWith("192.168.") ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host) || /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(host) ||
    /^f[cd][0-9a-f]{2}:/i.test(host) || host.startsWith("fe80:") || host === "::" || host === "::1" || host.startsWith("::ffff:");
}

export function isSafeN8nAgentWebhookUrl(value: string, kind: N8nAgentKind): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password && !url.search && !url.hash &&
      (!url.port || url.port === "443") && url.pathname === `/webhook/aptohire-${kind}` && !isPrivateHost(url.hostname);
  } catch {
    return false;
  }
}

/** Synchronous, signed, local-synthetic n8n call. Only schema-validated minimized payloads belong here. */
export async function dispatchN8nAgentJson(
  input: N8nAgentDispatchInput,
  fetcher: typeof fetch = fetch,
): Promise<unknown | null> {
  if (input.appEnv !== "local" || input.syntheticOptIn !== "true" || input.requestSecret.length < 32 ||
      input.responseSecret.length < 32 || !input.runId || !input.promptVersion || !isSafeN8nAgentWebhookUrl(input.endpoint, input.kind)) return null;
  const body = JSON.stringify({ run_id: input.runId, kind: input.kind, prompt_version: input.promptVersion, payload: input.payload });
  if (new TextEncoder().encode(body).byteLength > 128_000) return null;
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await hmacHex(input.requestSecret, `${timestamp}.${body}`);
  try {
    const response = await fetcher(input.endpoint, {
      method: "POST",
      redirect: "error",
      headers: { "content-type": "application/json", "X-Aptohire-Timestamp": timestamp, "X-Aptohire-Signature": `sha256=${signature}` },
      body,
      signal: AbortSignal.timeout(15_000),
    });
    if (response.status !== 200 || Number(response.headers.get("content-length") ?? "0") > 64_000) {
      try { await response.body?.cancel(); } catch { /* best-effort close */ }
      return null;
    }
    const rawBody = await response.text();
    if (new TextEncoder().encode(rawBody).byteLength > 64_000) return null;
    const responseTimestamp = response.headers.get("X-Aptohire-Timestamp") ?? "";
    const responseSignature = response.headers.get("X-Aptohire-Signature") ?? "";
    if (!await verifyHmacCallback(input.responseSecret, responseTimestamp, rawBody, responseSignature)) return null;
    let parsed: unknown;
    try { parsed = JSON.parse(rawBody); } catch { return null; }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    const result = parsed as { run_id?: unknown; kind?: unknown; result?: unknown };
    if (result.run_id !== input.runId || result.kind !== input.kind || !Object.hasOwn(result, "result")) return null;
    return result.result;
  } catch {
    return null;
  }
}
