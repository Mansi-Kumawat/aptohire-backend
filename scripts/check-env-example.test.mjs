import test from "node:test";
import assert from "node:assert/strict";
import { requiredEnvKeys, validateEnvTemplate } from "./check-env-example.js";

function validTemplate() {
  return requiredEnvKeys.map((key) => {
    const secret = /(?:_KEY|_SECRET|_PEPPER|_PASSWORD)$/.test(key);
    const value = key === "DEMO_PASSWORD" ? "aptohire-demo-only"
      : key === "APP_ENV" ? "local"
      : key === "AGENT_MODE" ? "mock"
      : ["LLM_ALLOW_SYNTHETIC_DIRECT", "N8N_ALLOW_SYNTHETIC", "N8N_AUDIT_ENABLED"].includes(key) ? "false"
      : key === "SUPABASE_URL" ? "http://127.0.0.1:54321"
      : secret ? "placeholder" : "local-value";
    return `${key}=${value}`;
  }).join("\n");
}

test("environment template accepts required keys and literal references with placeholders", () => {
  const result = validateEnvTemplate(`${validTemplate()}\nCUSTOM_RUNTIME_KEY=placeholder`, ["CALLBACK_SECRET", "CUSTOM_RUNTIME_KEY"]);
  assert.deepEqual(result.missingRequired, []);
  assert.deepEqual(result.missingReferences, []);
  assert.deepEqual(result.unsafeTemplateValues, []);
});

test("environment template rejects unsafe production, remote, direct, and LLM defaults", () => {
  const env = validTemplate()
    .replace("APP_ENV=local", "APP_ENV=production")
    .replace("AGENT_MODE=mock", "AGENT_MODE=direct")
    .replace("LLM_ALLOW_SYNTHETIC_DIRECT=false", "LLM_ALLOW_SYNTHETIC_DIRECT=true")
    .replace("N8N_ALLOW_SYNTHETIC=false", "N8N_ALLOW_SYNTHETIC=true")
    .replace("N8N_AUDIT_ENABLED=false", "N8N_AUDIT_ENABLED=true")
    .replace("SUPABASE_URL=http://127.0.0.1:54321", "SUPABASE_URL=https://hosted.example.test");
  const result = validateEnvTemplate(env);
  assert.deepEqual(result.unsafeOperationalDefaults, ["APP_ENV", "AGENT_MODE", "LLM_ALLOW_SYNTHETIC_DIRECT", "N8N_ALLOW_SYNTHETIC", "N8N_AUDIT_ENABLED", "SUPABASE_URL"]);
});

test("environment template reports missing keys and rejects non-placeholder secrets", () => {
  const env = validTemplate().split("\n").filter((line) => !line.startsWith("N8N_BASE_URL=")).join("\n")
    .replace("CALLBACK_SECRET=placeholder", "CALLBACK_SECRET=not-a-placeholder");
  const result = validateEnvTemplate(env, ["MISSING_LITERAL_KEY"]);
  assert.deepEqual(result.missingRequired, ["N8N_BASE_URL"]);
  assert.deepEqual(result.missingReferences, ["MISSING_LITERAL_KEY"]);
  assert.deepEqual(result.unsafeTemplateValues, ["CALLBACK_SECRET"]);
});
