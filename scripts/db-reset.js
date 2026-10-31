#!/usr/bin/env node
// Guard the destructive local Supabase reset and demo seed. Direct CLI use is discouraged;
// the seed SQL also checks APP_ENV in public.app_config when that value is present.
import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export function parseAppEnv(text) {
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^\s*(?:export\s+)?APP_ENV\s*=\s*(.*?)\s*$/);
    if (!match) continue;
    return match[1].replace(/\s+#.*$/, "").trim().replace(/^(["'])(.*)\1$/, "$2").trim();
  }
  return undefined;
}

export function validateResetEnvironment(value) {
  if (value === "production") return { ok: false, reason: "APP_ENV=production; refusing destructive demo reset" };
  if (value !== "local" && value !== "demo") {
    return { ok: false, reason: "APP_ENV must be explicitly set to local or demo before resetting the database" };
  }
  return { ok: true, reason: "" };
}

async function readEnvFile(file) {
  try { return parseAppEnv(await readFile(file, "utf8")); } catch { return undefined; }
}

export function runResetAndAssert(root, runCommand = spawnSync, nodeExecutable = process.execPath) {
  const reset = runCommand("supabase", ["db", "reset"], { cwd: root, stdio: "inherit" });
  if (reset.error) return { code: 1, error: `Could not run Supabase CLI: ${reset.error.message}` };
  if (reset.status !== 0) return { code: reset.status ?? 1 };
  const assertions = runCommand(nodeExecutable, [path.join(root, "scripts", "assert-demo-states.js")], { cwd: root, stdio: "inherit" });
  if (assertions.error) return { code: 1, error: `Could not run demo-state assertions: ${assertions.error.message}` };
  return { code: assertions.status ?? 1 };
}

async function main() {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const value = process.env.APP_ENV ?? await readEnvFile(path.join(root, ".env.local")) ?? await readEnvFile(path.join(root, ".env"));
  const validation = validateResetEnvironment(value);
  if (!validation.ok) {
    console.error(`${validation.reason}. Set APP_ENV=local in .env.local (or explicitly in the environment) for a local-only reset.`);
    process.exitCode = 1;
    return;
  }
  // The local reset is not considered complete until the fictional demo fixtures
  // satisfy the repository's documented state assertions.
  const result = runResetAndAssert(root);
  if (result.error) console.error(result.error);
  process.exitCode = result.code;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) await main();
