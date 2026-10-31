import { assertEquals } from "@std/assert";
import { dispatchN8nAuditJob, isLocalSyntheticN8nOptedIn, isSafeN8nCallbackBaseUrl, isSafeN8nWebhookUrl } from "./n8n-webhook.ts";

Deno.test("n8n synthetic execution is local-only and requires explicit opt-in", () => {
  assertEquals(isLocalSyntheticN8nOptedIn("local", "true"), true);
  assertEquals(isLocalSyntheticN8nOptedIn("local", "false"), false);
  assertEquals(isLocalSyntheticN8nOptedIn("demo", "true"), false);
  assertEquals(isLocalSyntheticN8nOptedIn("production", "true"), false);
});

Deno.test("n8n callback base URL requires a clean public HTTPS project origin", () => {
  assertEquals(isSafeN8nCallbackBaseUrl("https://project.example.test"), true);
  assertEquals(isSafeN8nCallbackBaseUrl("http://127.0.0.1:54321"), false);
  assertEquals(isSafeN8nCallbackBaseUrl("https://user:pass@project.example.test"), false);
  assertEquals(isSafeN8nCallbackBaseUrl("https://project.example.test/?key=x"), false);
  assertEquals(isSafeN8nCallbackBaseUrl("https://localhost"), false);
  assertEquals(isSafeN8nCallbackBaseUrl("https://[fd00::1]"), false);
  assertEquals(isSafeN8nCallbackBaseUrl("https://fc01.example.test"), true);
  assertEquals(isSafeN8nCallbackBaseUrl("https://project.example.test/prefix"), false);
});

Deno.test("n8n webhook URL requires HTTPS and rejects obvious private destinations", () => {
  assertEquals(isSafeN8nWebhookUrl("https://workflow.example.test/webhook/aptohire-audit", "local"), true);
  assertEquals(isSafeN8nWebhookUrl("http://workflow.example.test/webhook/aptohire-audit", "local"), false);
  assertEquals(isSafeN8nWebhookUrl("https://workflow.example.test/other", "local"), false);
  assertEquals(isSafeN8nWebhookUrl("https://127.0.0.1/webhook/aptohire-audit", "local"), false);
  assertEquals(isSafeN8nWebhookUrl("https://10.0.0.2/webhook/aptohire-audit", "production"), false);
  assertEquals(isSafeN8nWebhookUrl("https://user:pass@workflow.example.test/audit", "production"), false);
  assertEquals(isSafeN8nWebhookUrl("https://workflow.example.test/audit#secret", "production"), false);
});

Deno.test("signed n8n dispatch sends only run, callback and evidence and accepts 202", async () => {
  let requestUrl = "";
  let requestInit: RequestInit | undefined;
  const accepted = await dispatchN8nAuditJob({
    endpoint: "https://workflow.example.test/webhook/aptohire-audit",
    appEnv: "local",
    secret: "x".repeat(40),
    runId: "run-123",
    callbackUrl: "https://project.example.test/functions/v1/agent-callback",
    evidence: { evidence: [{ ref: "doc:readme", text: "synthetic" }] },
  }, (input, init) => {
    requestUrl = String(input);
    requestInit = init;
    return Promise.resolve(new Response("accepted", { status: 202 }));
  });
  assertEquals(accepted, true);
  assertEquals(requestUrl, "https://workflow.example.test/webhook/aptohire-audit");
  assertEquals(requestInit?.redirect, "error");
  assertEquals((requestInit?.headers as Record<string, string>)["X-Aptohire-Signature"].startsWith("sha256="), true);
  const body = JSON.parse(String(requestInit?.body));
  assertEquals(Object.keys(body).sort(), ["callback_url", "evidence", "run_id"]);
  assertEquals(body.run_id, "run-123");
});

Deno.test("n8n dispatch rejects short secrets and non-accepted response codes", async () => {
  assertEquals(await dispatchN8nAuditJob({
    endpoint: "https://workflow.example.test/webhook/aptohire-audit", appEnv: "local", secret: "short", runId: "run-123",
    callbackUrl: "https://project.example.test/functions/v1/agent-callback", evidence: {},
  }, () => Promise.resolve(new Response(null, { status: 202 }))), false);
  assertEquals(await dispatchN8nAuditJob({
    endpoint: "https://workflow.example.test/webhook/aptohire-audit", appEnv: "local", secret: "x".repeat(40), runId: "run-123",
    callbackUrl: "https://project.example.test/functions/v1/agent-callback", evidence: {},
  }, () => Promise.resolve(new Response(null, { status: 500 }))), false);
});

Deno.test("n8n dispatch rejects untrusted callback paths and over-limit payloads before network I/O", async () => {
  let fetchCalled = false;
  const fetcher: typeof fetch = () => {
    fetchCalled = true;
    return Promise.resolve(new Response(null, { status: 202 }));
  };
  const base = {
    endpoint: "https://workflow.example.test/webhook/aptohire-audit",
    appEnv: "local",
    secret: "x".repeat(40),
    runId: "run-123",
    callbackUrl: "https://project.example.test/functions/v1/agent-callback",
    evidence: {},
  };
  assertEquals(await dispatchN8nAuditJob({ ...base, callbackUrl: "https://project.example.test/other" }, fetcher), false);
  assertEquals(await dispatchN8nAuditJob({ ...base, endpoint: "https://127.0.0.1/webhook/aptohire-audit" }, fetcher), false);
  assertEquals(await dispatchN8nAuditJob({ ...base, evidence: { text: "x".repeat(512_000) } }, fetcher), false);
  assertEquals(fetchCalled, false);
});
