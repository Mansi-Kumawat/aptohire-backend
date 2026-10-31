#!/usr/bin/env node
// Keep the documented local env template aligned with both the backend prompt
// and literal Deno.env.get() references. Value checks only enforce placeholders.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const templatePath = path.join(root, ".env.example");
const functionRoot = path.join(root, "supabase/functions");
export const requiredEnvKeys = [
  "SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "APP_ENV", "ALLOWED_ORIGINS",
  "AGENT_MODE", "N8N_BASE_URL", "N8N_WEBHOOK_SECRET", "N8N_ALLOW_SYNTHETIC", "N8N_AUDIT_ENABLED", "CALLBACK_SECRET", "LLM_PROVIDER_ORDER",
  "GEMINI_API_KEY", "GROQ_API_KEY", "OPENROUTER_API_KEY", "LLM_MODEL_AUDIT", "LLM_MODEL_FAST",
  "EMBEDDING_MODEL", "EMBEDDING_DIM", "ID_HASH_PEPPER", "ALIAS_PEPPER", "RATE_LIMIT_PEPPER",
  "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET", "TURNSTILE_SECRET_KEY", "SITE_URLS", "DEMO_PASSWORD",
  "VIDEO_MAX_MB", "VIDEO_MAX_SECONDS", "LLM_ALLOW_SYNTHETIC_DIRECT", "LLM_DAILY_CAP_PER_PROVIDER",
  "GITHUB_REDIRECT_URI", "OAUTH_STATE_PEPPER", "RETENTION_CLEANUP_SECRET", "STUDENT_PORTAL_URL",
  "LLM_MODEL_AUDIT_GEMINI", "LLM_MODEL_AUDIT_GROQ", "LLM_MODEL_AUDIT_OPENROUTER",
  "LLM_MODEL_FAST_GEMINI", "LLM_MODEL_FAST_GROQ", "LLM_MODEL_FAST_OPENROUTER",
];

export function validateEnvTemplate(envText, referencedNames = []) {
  const values = new Map(envText.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*([A-Z][A-Z0-9_]*)\s*=(.*)$/);
    return match ? [[match[1], match[2].trim()]] : [];
  }));
  const keys = new Set(values.keys());
  const missingRequired = requiredEnvKeys.filter((name) => !keys.has(name));
  const missingReferences = [...new Set(referencedNames)].filter((name) => !keys.has(name));
  const unsafeTemplateValues = [...values].filter(([name, value]) =>
    /(?:_KEY|_SECRET|_PEPPER|_PASSWORD)$/.test(name)
    && value !== "" && value !== "placeholder"
    && !(name === "DEMO_PASSWORD" && value === "aptohire-demo-only")
  ).map(([name]) => name);
  const unsafeOperationalDefaults = [];
  if (values.has("APP_ENV") && values.get("APP_ENV") !== "local") unsafeOperationalDefaults.push("APP_ENV");
  if (values.has("AGENT_MODE") && values.get("AGENT_MODE") !== "mock") unsafeOperationalDefaults.push("AGENT_MODE");
  if (values.has("LLM_ALLOW_SYNTHETIC_DIRECT") && values.get("LLM_ALLOW_SYNTHETIC_DIRECT") !== "false") unsafeOperationalDefaults.push("LLM_ALLOW_SYNTHETIC_DIRECT");
  for (const key of ["N8N_ALLOW_SYNTHETIC", "N8N_AUDIT_ENABLED"]) {
    if (values.has(key) && values.get(key) !== "false") unsafeOperationalDefaults.push(key);
  }
  if (values.has("SUPABASE_URL")) {
    try {
      const host = new URL(values.get("SUPABASE_URL")).hostname.toLowerCase();
      if (!new Set(["127.0.0.1", "localhost", "::1", "[::1]"]).has(host)) unsafeOperationalDefaults.push("SUPABASE_URL");
    } catch { unsafeOperationalDefaults.push("SUPABASE_URL"); }
  }
  return { keyCount: keys.size, missingRequired, missingReferences, unsafeTemplateValues, unsafeOperationalDefaults };
}

async function listTs(dir) {
  const found = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...await listTs(fullPath));
    else if (entry.isFile() && entry.name.endsWith(".ts")) found.push(fullPath);
  }
  return found;
}

async function main() {
  const envText = await readFile(templatePath, "utf8");
  const referenced = new Set();
  for (const file of await listTs(functionRoot)) {
    const source = await readFile(file, "utf8");
    for (const match of source.matchAll(/Deno\.env\.get\(\s*["']([A-Z][A-Z0-9_]*)["']\s*\)/g)) referenced.add(match[1]);
  }
  const result = validateEnvTemplate(envText, referenced);
  if (result.missingRequired.length || result.missingReferences.length || result.unsafeTemplateValues.length || result.unsafeOperationalDefaults.length) {
    if (result.missingRequired.length) console.error(`.env.example missing prompt-required keys: ${result.missingRequired.join(", ")}`);
    if (result.missingReferences.length) console.error(`.env.example missing literal Edge Function env references: ${result.missingReferences.join(", ")}`);
    if (result.unsafeTemplateValues.length) console.error(`.env.example contains non-placeholder sensitive values for: ${result.unsafeTemplateValues.join(", ")}`);
    if (result.unsafeOperationalDefaults.length) console.error(`.env.example has unsafe operational defaults for: ${result.unsafeOperationalDefaults.join(", ")}`);
    process.exitCode = 1;
    return;
  }
  console.log(`Environment template check passed: ${result.keyCount} keys; all ${requiredEnvKeys.length} prompt-required and ${referenced.size} literal Edge Function env names are present. Sensitive values are blank/placeholders and operating defaults are local/mock/off; runtime credential validity is not checked.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) await main();
