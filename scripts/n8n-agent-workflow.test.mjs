import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
const requestSecret = "synthetic-test-webhook-secret-not-real";
const responseSecret = "synthetic-test-callback-secret-not-real";
const host = "project.example.com";
const workflows = new Map();
for (const kind of ["assign", "match", "profile"]) {
  workflows.set(kind, JSON.parse(await readFile(path.join(root, `n8n/workflows/${kind}.json`), "utf8")));
}
const samples = {
  assign: { title: "Fictional project", scenario: "Build a clear interface", video_guidance: "Show a short demo", originality_questions: ["What changed?", "Why this approach?"] },
  match: { reasons: [{ alias: "Candidate A1", reason: "Verified React skill matches role" }] },
  profile: { headline: "Frontend developer", skills: ["React"], experience: "Built React interfaces" },
};
const expectedVersions = { assign: "assign@1", match: "match-reasons@1", profile: "profile@1" };

function executeVerify(kind, bodyOverride = null, options = {}) {
  const workflow = workflows.get(kind);
  const code = workflow.nodes.find((node) => node.name === "Verify Request").parameters.jsCode;
  const body = bodyOverride ?? { run_id: "11111111-1111-4111-8111-111111111111", kind, prompt_version: expectedVersions[kind], payload: { synthetic: true } };
  const raw = JSON.stringify(body);
  const timestamp = options.timestamp ?? String(Math.floor(Date.now() / 1000));
  const signature = options.signature ?? createHmac("sha256", requestSecret).update(`${timestamp}.${raw}`).digest("hex");
  const context = {
    Buffer, Date, Math, URL, require,
    $env: {
      N8N_WEBHOOK_SECRET: requestSecret,
      N8N_LLM_CHAT_COMPLETIONS_URL: "https://openrouter.ai/api/v1/chat/completions",
      N8N_LLM_ALLOWED_HOSTS: "openrouter.ai",
    },
    $input: { first: () => ({ json: { headers: { "X-Aptohire-Timestamp": timestamp, "X-Aptohire-Signature": `sha256=${signature}` }, body } }) },
  };
  return new vm.Script(`(function(){\n${code}\n})()`).runInNewContext(context, { timeout: 1000 });
}

function executeSign(kind, result, runId = "11111111-1111-4111-8111-111111111111") {
  const workflow = workflows.get(kind);
  const code = workflow.nodes.find((node) => node.name === "Validate and Sign Result").parameters.jsCode;
  const context = {
    Buffer, Date, Math, require,
    $env: { CALLBACK_SECRET: responseSecret },
    $: (name) => ({ first: () => ({ json: { run_id: runId, kind, payload: { source_text: "Frontend developer React" } } }) }),
    $input: { first: () => ({ json: { choices: [{ message: { content: JSON.stringify(result) } }] } }) },
  };
  return new vm.Script(`(function(){\n${code}\n})()`).runInNewContext(context, { timeout: 1000 });
}

test("all n8n agent workflow exports are inactive, no-retention, uniquely wired, and secret-free", () => {
  for (const [kind, workflow] of workflows) {
    assert.equal(workflow.active, false, `${kind} workflow must remain inactive`);
    assert.equal(workflow.settings.saveDataSuccessExecution, "none");
    assert.equal(workflow.settings.saveDataErrorExecution, "none");
    assert.equal(new Set(workflow.nodes.map((node) => node.id)).size, workflow.nodes.length);
    assert.equal(new Set(workflow.nodes.map((node) => node.name)).size, workflow.nodes.length);
    assert.doesNotMatch(JSON.stringify(workflow), /(?:sk-[A-Za-z0-9]{20,}|Bearer\s+[A-Za-z0-9._-]{20,})/);
    for (const node of workflow.nodes) assert.equal(node.credentials, undefined);
    assert.equal(workflow.nodes.find((node) => node.name === "Receive Agent Job").parameters.path, `aptohire-${kind}`);
    assert.ok(workflow.nodes.find((node) => node.name === "Verify Request").parameters.jsCode.includes("N8N_WEBHOOK_SECRET"));
    assert.ok(workflow.nodes.find((node) => node.name === "Validate and Sign Result").parameters.jsCode.includes("CALLBACK_SECRET"));
    assert.equal(workflow.connections["Verify Request"].main[0][0].node, "Generate Agent Result");
    assert.equal(workflow.connections["Validate and Sign Result"].main[0][0].node, "Return Signed Result");
    for (const name of ["Generate Agent Result"]) assert.equal(workflow.nodes.find((node) => node.name === name).parameters.options.redirect.redirect.followRedirects, false);
  }
});

test("agent workflow preflight rejects bad signature, wrong kind/version, stale time, and unsafe provider", () => {
  for (const kind of workflows.keys()) {
    assert.equal(executeVerify(kind).length, 1);
    assert.throws(() => executeVerify(kind, null, { signature: "0".repeat(64) }), /invalid HMAC/);
    assert.throws(() => executeVerify(kind, null, { timestamp: "1000000000" }), /stale or invalid timestamp/);
    const wrongKind = { run_id: "run", kind: "audit", prompt_version: expectedVersions[kind], payload: {} };
    assert.throws(() => executeVerify(kind, wrongKind), /invalid job contract/);
    const wrongVersion = { run_id: "run", kind, prompt_version: "unknown@9", payload: {} };
    assert.throws(() => executeVerify(kind, wrongVersion), /invalid job contract/);
  }
  const workflow = workflows.get("assign");
  const code = workflow.nodes.find((node) => node.name === "Verify Request").parameters.jsCode;
  const body = { run_id: "run", kind: "assign", prompt_version: "assign@1", payload: {} };
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = createHmac("sha256", requestSecret).update(`${timestamp}.${JSON.stringify(body)}`).digest("hex");
  const context = {
    Buffer, Date, Math, URL, require,
    $env: { N8N_WEBHOOK_SECRET: requestSecret, N8N_LLM_CHAT_COMPLETIONS_URL: "https://other.example/api/v1/chat/completions", N8N_LLM_ALLOWED_HOSTS: "openrouter.ai" },
    $input: { first: () => ({ json: { headers: { "X-Aptohire-Timestamp": timestamp, "X-Aptohire-Signature": `sha256=${signature}` }, body } }) },
  };
  assert.throws(() => new vm.Script(`(function(){\n${code}\n})()`).runInNewContext(context), /invalid provider endpoint configuration/);
});

test("each agent workflow validates its result and returns an HMAC-signed response", () => {
  for (const [kind, sample] of Object.entries(samples)) {
    const signed = executeSign(kind, sample)[0].json;
    const body = JSON.parse(signed.response_body);
    assert.equal(body.kind, kind);
    assert.equal(body.run_id, "11111111-1111-4111-8111-111111111111");
    assert.deepEqual(JSON.parse(JSON.stringify(body.result)), sample);
    assert.equal(createHmac("sha256", responseSecret).update(`${signed.timestamp}.${signed.response_body}`).digest("hex"), signed.signature);
  }
  assert.throws(() => executeSign("assign", { title: "missing fields" }), /invalid assignment result/);
  assert.throws(() => executeSign("match", { reasons: [{ alias: "A", reason: "x" }], extra: true }), /invalid match result/);
  assert.throws(() => executeSign("profile", { skills: "React" }), /invalid profile result/);
});
