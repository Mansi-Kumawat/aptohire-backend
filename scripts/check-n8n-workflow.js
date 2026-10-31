#!/usr/bin/env node
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const workflow = JSON.parse(await readFile(path.join(root, "n8n/workflows/audit.json"), "utf8"));
const compose = await readFile(path.join(root, "n8n/docker-compose.yml"), "utf8");
const nodes = new Map(workflow.nodes.map((node) => [node.name, node]));

assert.equal(workflow.active, false, "the imported workflow must remain inactive by default");
assert.equal(workflow.meta?.templateCredsSetupCompleted, false, "workflow must not embed configured credentials");
for (const node of workflow.nodes) assert.equal(node.credentials, undefined, `${node.name} must not embed credential material`);
assert.doesNotMatch(JSON.stringify(workflow), /(?:sk-[A-Za-z0-9]{20,}|Bearer\s+[A-Za-z0-9._-]{20,})/, "workflow JSON must not contain obvious static provider credentials");
assert.equal(nodes.size, workflow.nodes.length, "workflow node names must be unique");
assert.equal(new Set(workflow.nodes.map((node) => node.id)).size, workflow.nodes.length, "workflow node IDs must be unique");
const terminalNodeNames = ["Post Signed Callback"];
assert.deepEqual(
  Object.keys(workflow.connections).sort(),
  [...nodes.keys()].filter((name) => !terminalNodeNames.includes(name)).sort(),
  "every nonterminal workflow node must have an explicit connection entry",
);
for (const [source, outputs] of Object.entries(workflow.connections)) {
  assert.ok(nodes.has(source), `connection source ${source} must name a workflow node`);
  for (const edge of outputs.main.flat()) assert.ok(nodes.has(edge.node), `connection target ${edge.node} must name a workflow node`);
}

const receive = nodes.get("Receive Audit Job");
assert.equal(receive?.type, "n8n-nodes-base.webhook");
assert.equal(receive.parameters.httpMethod, "POST");
assert.equal(receive.parameters.path, "aptohire-audit");

const code = (name) => {
  const node = nodes.get(name);
  assert.equal(node?.type, "n8n-nodes-base.code", `${name} must be a Code node`);
  return node.parameters.jsCode;
};
const verifyCode = code("Verify HMAC and Contract");
const callbackCode = code("Validate and Sign Callback");
assert.match(verifyCode, /\$env\.N8N_WEBHOOK_SECRET/);
assert.match(callbackCode, /\$env\.CALLBACK_SECRET/);
assert.doesNotMatch(`${verifyCode}\n${callbackCode}`, /process\.env\./, "workflow Code nodes must use n8n $env access");
assert.match(verifyCode, /timingSafeEqual/);
assert.match(verifyCode, /body\.callback_url/);
assert.ok(verifyCode.includes("String($env.N8N_CALLBACK_ALLOWED_HOSTS || '')"), "callback host must be operator-allowlisted");
assert.ok(verifyCode.includes("allowedCallbackHosts.includes(callbackHost)"), "callback URL hostname must match the exact allowlist");
assert.ok(verifyCode.includes("const provider = new URL($env.N8N_LLM_CHAT_COMPLETIONS_URL);"), "provider URL must be parsed before ACK");
assert.ok(verifyCode.includes("provider.protocol !== 'https:'"), "provider endpoint must require HTTPS");
assert.ok(verifyCode.includes("provider.pathname.endsWith('/chat/completions')"), "provider endpoint must target a chat-completions path");
assert.ok(verifyCode.includes("String($env.N8N_LLM_ALLOWED_HOSTS || '')"), "provider host must be operator-allowlisted");
assert.ok(verifyCode.includes("allowedProviderHosts.includes(providerHost)"), "provider URL hostname must match the exact allowlist");
assert.ok(verifyCode.includes("providerHost.includes(':')"), "provider endpoint must reject IPv6 literal hosts");
assert.match(callbackCode, /evidence_refs/);

const ack = nodes.get("ACK Verified Job");
assert.equal(ack?.type, "n8n-nodes-base.respondToWebhook");
assert.equal(ack.parameters.options.responseCode, 202);
const targets = (name) => (workflow.connections[name]?.main ?? []).flat().map((edge) => edge.node);
assert.deepEqual(targets("Verify HMAC and Contract"), ["ACK Verified Job"], "only verified jobs may be ACKed");
assert.deepEqual(targets("ACK Verified Job"), ["Score Evidence"], "ACK must precede provider work");

for (const name of ["Score Evidence", "Post Signed Callback"]) {
  const node = nodes.get(name);
  assert.equal(node?.type, "n8n-nodes-base.httpRequest");
  assert.equal(node.options, undefined, `${name} options must be nested in the node parameters`);
  assert.equal(node.parameters.options.redirect.redirect.followRedirects, false, `${name} must not follow redirects`);
}
assert.match(nodes.get("Score Evidence").parameters.url, /\$env\.N8N_LLM_CHAT_COMPLETIONS_URL/);
assert.match(nodes.get("Post Signed Callback").parameters.url, /callback_url/);
assert.equal(workflow.settings.saveDataSuccessExecution, "none");
assert.equal(workflow.settings.saveDataErrorExecution, "none");

assert.match(compose, /N8N_BLOCK_ENV_ACCESS_IN_NODE:\s*"false"/);
assert.match(compose, /NODE_FUNCTION_ALLOW_BUILTIN:\s*crypto/);
assert.match(compose, /N8N_PAYLOAD_SIZE_MAX:\s*"1"/);
assert.match(compose, /N8N_LLM_ALLOWED_HOSTS:\s*\$\{N8N_LLM_ALLOWED_HOSTS:\?set exact comma-separated provider hostnames; no wildcards\}/);
assert.match(compose, /N8N_CALLBACK_ALLOWED_HOSTS:\s*\$\{N8N_CALLBACK_ALLOWED_HOSTS:\?set exact comma-separated Supabase Edge Function hostnames; no wildcards\}/);
assert.match(compose, /N8N_BASIC_AUTH_ACTIVE:\s*"true"/);
assert.match(compose, /127\.0\.0\.1:5678:5678/);

for (const kind of ["assign", "match", "profile"]) {
  const extra = JSON.parse(await readFile(path.join(root, `n8n/workflows/${kind}.json`), "utf8"));
  const extraNodes = new Map(extra.nodes.map((node) => [node.name, node]));
  assert.equal(extra.active, false, `${kind} workflow must remain inactive by default`);
  assert.equal(extra.settings.saveDataSuccessExecution, "none");
  assert.equal(extra.settings.saveDataErrorExecution, "none");
  assert.equal(extraNodes.size, extra.nodes.length, `${kind} node names must be unique`);
  assert.equal(new Set(extra.nodes.map((node) => node.id)).size, extra.nodes.length, `${kind} node IDs must be unique`);
  for (const node of extra.nodes) assert.equal(node.credentials, undefined, `${kind}/${node.name} must not embed credentials`);
  assert.doesNotMatch(JSON.stringify(extra), /(?:sk-[A-Za-z0-9]{20,}|Bearer\s+[A-Za-z0-9._-]{20,})/);
  assert.equal(extraNodes.get("Receive Agent Job")?.parameters.path, `aptohire-${kind}`);
  const verify = extraNodes.get("Verify Request")?.parameters.jsCode ?? "";
  const sign = extraNodes.get("Validate and Sign Result")?.parameters.jsCode ?? "";
  assert.ok(verify.includes("N8N_WEBHOOK_SECRET") && verify.includes("timingSafeEqual"));
  assert.ok(verify.includes(`body.kind !== '${kind}'`));
  assert.ok(verify.includes("N8N_LLM_ALLOWED_HOSTS"));
  assert.ok(sign.includes("CALLBACK_SECRET"));
  assert.equal(extraNodes.get("Generate Agent Result")?.parameters.options.redirect.redirect.followRedirects, false);
}
console.log("Static n8n workflow boundary review passed (source structure only; import/runtime not verified).");
