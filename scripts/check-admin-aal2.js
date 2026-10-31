#!/usr/bin/env node
// Static guard: every admin-* Edge Function must use the shared JWT admin + AAL2 gate.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export function adminHandlerViolations(name, source) {
  const match = source.match(/withHandler\s*\(\s*\{([\s\S]*?)\}\s*,/);
  if (!match) return [`${name}: no statically recognizable withHandler config`];
  const config = match[1];
  const errors = [];
  if (!/\bauth\s*:\s*["']jwt["']/.test(config)) errors.push(`${name}: auth must be jwt`);
  if (!/\broles\s*:\s*\[[^\]]*["']admin["'][^\]]*\]/.test(config)) errors.push(`${name}: roles must include admin`);
  if (!/\baal2\s*:\s*true\b/.test(config)) errors.push(`${name}: aal2: true is required`);
  return errors;
}

export async function scanAdminFunctions(root) {
  const functionsDir = path.join(root, "supabase/functions");
  const folders = (await readdir(functionsDir, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory() && entry.name.startsWith("admin-"))
    .map((entry) => entry.name).sort();
  const violations = [];
  for (const name of folders) {
    const file = path.join(functionsDir, name, "index.ts");
    let source;
    try { source = await readFile(file, "utf8"); } catch { violations.push(`${name}: missing index.ts`); continue; }
    violations.push(...adminHandlerViolations(name, source));
  }
  return { folders, violations };
}

async function main() {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const { folders, violations } = await scanAdminFunctions(root);
  if (violations.length) {
    console.error(`Admin AAL2 static check failed:\n- ${violations.join("\n- ")}`);
    process.exitCode = 1;
    return;
  }
  console.log(`Admin AAL2 static check passed: ${folders.length} admin-* functions declare JWT auth, admin role, and aal2: true.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) await main();
