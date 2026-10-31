import { hmacHex } from "../hash.ts";

export type N8nDispatchInput = {
  endpoint: string;
  appEnv: string | undefined;
  secret: string;
  runId: string;
  callbackUrl: string;
  evidence: unknown;
};

function isObviouslyPrivateHost(value: string): boolean {
  const host = value.toLowerCase().replace(/^\[|\]$/g, "").replace(/\.$/, "");
  return !host || host === "localhost" || host.endsWith(".localhost") || host.endsWith(".local") || host.endsWith(".internal") ||
    host === "127.0.0.1" || host.startsWith("127.") || /^f[cd][0-9a-f]{2}:/i.test(host) ||
    host.startsWith("fe80:") || host === "::" || host === "::1" || host.startsWith("::ffff:") ||
    host.startsWith("0.") || host.startsWith("10.") || host.startsWith("169.254.") || host.startsWith("192.168.") ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host) || /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(host);
}

export function isLocalSyntheticN8nOptedIn(appEnv: string | undefined, optIn: string | undefined): boolean {
  return appEnv === "local" && optIn === "true";
}

export function isSafeN8nCallbackBaseUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !url.username && !url.password && !url.search && !url.hash && url.pathname === "/" &&
      !isObviouslyPrivateHost(url.hostname);
  } catch {
    return false;
  }
}

function isSafeAgentCallbackUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.pathname === "/functions/v1/agent-callback" &&
      !url.username && !url.password && !url.search && !url.hash && !isObviouslyPrivateHost(url.hostname);
  } catch {
    return false;
  }
}

export function isSafeN8nWebhookUrl(value: string, appEnv: string | undefined): boolean {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.hash || url.search || url.pathname !== "/webhook/aptohire-audit") return false;
    if (isObviouslyPrivateHost(url.hostname)) return false;
    return appEnv === "local" || appEnv === "demo" || appEnv === "production";
  } catch {
    return false;
  }
}

/** Send a minimized signed job to n8n. No Supabase credentials or user JWT are ever included. */
export async function dispatchN8nAuditJob(
  input: N8nDispatchInput,
  fetcher: typeof fetch = fetch,
): Promise<boolean> {
  if (!input.secret || input.secret.length < 32 || !input.runId ||
      !isSafeN8nWebhookUrl(input.endpoint, input.appEnv) || !isSafeAgentCallbackUrl(input.callbackUrl)) return false;
  const body = JSON.stringify({ run_id: input.runId, callback_url: input.callbackUrl, evidence: input.evidence });
  if (new TextEncoder().encode(body).byteLength > 512_000) return false;
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await hmacHex(input.secret, `${timestamp}.${body}`);
  try {
    const response = await fetcher(input.endpoint, {
      method: "POST",
      redirect: "error",
      headers: {
        "content-type": "application/json",
        "X-Aptohire-Timestamp": timestamp,
        "X-Aptohire-Signature": `sha256=${signature}`,
      },
      body,
      signal: AbortSignal.timeout(5_000),
    });
    return response.status === 200 || response.status === 202;
  } catch {
    return false;
  }
}
