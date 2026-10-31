import { assertEquals } from "@std/assert";
import { hmacHex } from "../hash.ts";
import { dispatchN8nAgentJson, isSafeN8nAgentWebhookUrl } from "./n8n-agent.ts";

const runId = "11111111-1111-4111-8111-111111111111";
const requestSecret = "request-secret-used-only-in-test-123456";
const responseSecret = "response-secret-used-only-in-test-123456";

Deno.test("n8n agent endpoint requires exact HTTPS path and public hostname", () => {
  assertEquals(isSafeN8nAgentWebhookUrl("https://workflow.example.com/webhook/aptohire-assign", "assign"), true);
  assertEquals(isSafeN8nAgentWebhookUrl("https://workflow.example.com/webhook/aptohire-match", "match"), true);
  assertEquals(isSafeN8nAgentWebhookUrl("https://workflow.example.com/webhook/aptohire-profile", "profile"), true);
  assertEquals(isSafeN8nAgentWebhookUrl("http://workflow.example.com/webhook/aptohire-assign", "assign"), false);
  assertEquals(isSafeN8nAgentWebhookUrl("https://workflow.example.com/webhook/aptohire-audit", "assign"), false);
  assertEquals(isSafeN8nAgentWebhookUrl("https://workflow.example.com/webhook/aptohire-assign?x=1", "assign"), false);
  assertEquals(isSafeN8nAgentWebhookUrl("https://127.0.0.1/webhook/aptohire-assign", "assign"), false);
  assertEquals(isSafeN8nAgentWebhookUrl("https://workflow.example.test/webhook/aptohire-profile", "profile"), false);
  assertEquals(isSafeN8nAgentWebhookUrl("https://user:pass@workflow.example.com/webhook/aptohire-match", "match"), false);
});

Deno.test("n8n synchronous agent call signs minimized input and verifies signed response", async () => {
  let receivedUrl = "";
  let receivedBody = "";
  const run_id = runId;
  const kind = "assign" as const;
  const result = { title: "Fictional title", scenario: "Fictional scenario", video_guidance: "Show the work", originality_questions: ["What changed?", "Why this design?"] };
  const responseBody = JSON.stringify({ run_id, kind, result });
  const responseTimestamp = String(Math.floor(Date.now() / 1000));
  const responseSignature = await hmacHex(responseSecret, `${responseTimestamp}.${responseBody}`);
  const output = await dispatchN8nAgentJson({
    endpoint: "https://workflow.example.com/webhook/aptohire-assign", appEnv: "local", syntheticOptIn: "true",
    requestSecret, responseSecret, runId, kind, promptVersion: "assign@1", payload: { template: "synthetic only" },
  }, (input, init) => {
    receivedUrl = String(input);
    receivedBody = String(init?.body);
    return Promise.resolve(new Response(responseBody, { status: 200, headers: {
      "content-type": "application/json", "content-length": String(new TextEncoder().encode(responseBody).byteLength),
      "X-Aptohire-Timestamp": responseTimestamp, "X-Aptohire-Signature": `sha256=${responseSignature}`,
    } }));
  });
  assertEquals(output, result);
  assertEquals(receivedUrl, "https://workflow.example.com/webhook/aptohire-assign");
  const request = JSON.parse(receivedBody);
  assertEquals(Object.keys(request).sort(), ["kind", "payload", "prompt_version", "run_id"]);
  assertEquals(request.run_id, runId);
  assertEquals(request.kind, "assign");
});

Deno.test("n8n synchronous agent rejects nonlocal, unsigned, malformed, oversized, and mismatched responses", async () => {
  const base = {
    endpoint: "https://workflow.example.com/webhook/aptohire-match", appEnv: "local", syntheticOptIn: "true",
    requestSecret, responseSecret, runId, kind: "match" as const, promptVersion: "match-reasons@1", payload: { facts: ["React"] },
  };
  let called = false;
  const fetcher: typeof fetch = () => { called = true; return Promise.resolve(new Response("{}", { status: 200 })); };
  assertEquals(await dispatchN8nAgentJson({ ...base, appEnv: "production" }, fetcher), null);
  assertEquals(await dispatchN8nAgentJson({ ...base, syntheticOptIn: "false" }, fetcher), null);
  assertEquals(await dispatchN8nAgentJson({ ...base, endpoint: "https://127.0.0.1/webhook/aptohire-match" }, fetcher), null);
  assertEquals(called, false);

  const mismatch = JSON.stringify({ run_id: runId, kind: "profile", result: { skills: [] } });
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await hmacHex(responseSecret, `${timestamp}.${mismatch}`);
  const wrongResponse: typeof fetch = () => Promise.resolve(new Response(mismatch, { status: 200, headers: {
    "X-Aptohire-Timestamp": timestamp, "X-Aptohire-Signature": `sha256=${signature}`,
  } }));
  assertEquals(await dispatchN8nAgentJson(base, wrongResponse), null);

  const unsigned: typeof fetch = () => Promise.resolve(new Response(JSON.stringify({ run_id: runId, kind: "match", result: {} }), { status: 200 }));
  assertEquals(await dispatchN8nAgentJson(base, unsigned), null);
});
