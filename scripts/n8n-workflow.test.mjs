import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const workflow = JSON.parse(await readFile(path.join(root, "n8n/workflows/audit.json"), "utf8"));
const verifySource = workflow.nodes.find((node) => node.name === "Verify HMAC and Contract").parameters.jsCode;
const nodeRequire = createRequire(import.meta.url);
const secret = "local-test-webhook-secret-not-a-real-key";
const timestamp = String(Math.floor(Date.now() / 1000));
const body = {
  run_id: "11111111-1111-4111-8111-111111111111",
  callback_url: "https://project.example/functions/v1/agent-callback",
  evidence: { evidence_refs: ["evidence-1"], text: "synthetic-only fixture" },
};
const raw = JSON.stringify(body);
const signature = createHmac("sha256", secret).update(`${timestamp}.${raw}`).digest("hex");

function runVerifier(providerUrl, allowedHosts = "openrouter.ai", callbackAllowedHosts = "project.example") {
  const context = {
    Buffer,
    Date,
    Math,
    URL,
    require: nodeRequire,
    $env: {
      N8N_WEBHOOK_SECRET: secret,
      N8N_LLM_CHAT_COMPLETIONS_URL: providerUrl,
      N8N_LLM_ALLOWED_HOSTS: allowedHosts,
      N8N_CALLBACK_ALLOWED_HOSTS: callbackAllowedHosts,
    },
    $input: {
      first: () => ({
        json: {
          headers: {
            "X-Aptohire-Timestamp": timestamp,
            "X-Aptohire-Signature": `sha256=${signature}`,
          },
          body,
        },
      }),
    },
  };
  return new vm.Script(`(function () {\n${verifySource}\n})()`).runInNewContext(context, { timeout: 1000 });
}

test("pre-ACK verifier accepts a valid signed contract for an exact allowlisted HTTPS provider", () => {
  const result = runVerifier("https://openrouter.ai/api/v1/chat/completions");
  assert.equal(result.length, 1);
  assert.equal(result[0].json.run_id, body.run_id);
  assert.deepEqual(JSON.parse(JSON.stringify(result[0].json.evidence)), body.evidence);
  assert.throws(() => runVerifier("https://openrouter.ai/api/v1/chat/completions", "openrouter.ai", "other.example"), /invalid callback URL/);
  assert.throws(() => runVerifier("https://openrouter.ai/api/v1/chat/completions", "openrouter.ai", "*.example"), /invalid callback URL/);
});

test("pre-ACK verifier rejects unsafe or unapproved provider endpoints before HMAC dispatch", () => {
  const rejected = [
    ["http://openrouter.ai/api/v1/chat/completions", "openrouter.ai"],
    ["https://other.example/api/v1/chat/completions", "openrouter.ai"],
    ["https://openrouter.ai/api/v1/chat/completions?model=x", "openrouter.ai"],
    ["https://openrouter.ai/api/v1/chat/completions#fragment", "openrouter.ai"],
    ["https://user:pass@openrouter.ai/api/v1/chat/completions", "openrouter.ai"],
    ["https://openrouter.ai:8443/api/v1/chat/completions", "openrouter.ai"],
    ["https://openrouter.ai/v1/completions", "openrouter.ai"],
    ["https://127.0.0.1/v1/chat/completions", "127.0.0.1"],
    ["https://localhost/v1/chat/completions", "localhost"],
    ["https://provider.internal/v1/chat/completions", "provider.internal"],
    ["https://provider.example.test/v1/chat/completions", "provider.example.test"],
    ["https://openrouter.ai/api/v1/chat/completions", "*.openrouter.ai"],
  ];
  for (const [url, hosts] of rejected) {
    assert.throws(() => runVerifier(url, hosts), /invalid provider endpoint configuration/, url);
  }
});

test("pre-ACK verifier rejects stale timestamps and invalid HMAC signatures", () => {
  const staleContext = {
    Buffer,
    Date,
    Math,
    URL,
    require: nodeRequire,
    $env: {
      N8N_WEBHOOK_SECRET: secret,
      N8N_LLM_CHAT_COMPLETIONS_URL: "https://openrouter.ai/api/v1/chat/completions",
      N8N_LLM_ALLOWED_HOSTS: "openrouter.ai",
      N8N_CALLBACK_ALLOWED_HOSTS: "project.example",
    },
    $input: {
      first: () => ({
        json: {
          headers: {
            "X-Aptohire-Timestamp": "1000000000",
            "X-Aptohire-Signature": `sha256=${signature}`,
          },
          body,
        },
      }),
    },
  };
  assert.throws(() => new vm.Script(`(function () {\n${verifySource}\n})()`).runInNewContext(staleContext), /stale or invalid timestamp/);

  const badContext = {
    Buffer,
    Date,
    Math,
    URL,
    require: nodeRequire,
    $env: {
      N8N_WEBHOOK_SECRET: secret,
      N8N_LLM_CHAT_COMPLETIONS_URL: "https://openrouter.ai/api/v1/chat/completions",
      N8N_LLM_ALLOWED_HOSTS: "openrouter.ai",
      N8N_CALLBACK_ALLOWED_HOSTS: "project.example",
    },
    $input: {
      first: () => ({
        json: {
          headers: {
            "X-Aptohire-Timestamp": timestamp,
            "X-Aptohire-Signature": "sha256=" + "0".repeat(64),
          },
          body,
        },
      }),
    },
  };
  assert.throws(() => new vm.Script(`(function () {\n${verifySource}\n})()`).runInNewContext(badContext), /invalid HMAC/);
});
