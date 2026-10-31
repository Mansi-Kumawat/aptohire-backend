import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const migrationsDir = path.join(root, "supabase/migrations");
const files = (await readdir(migrationsDir)).filter((name) => name.endsWith(".sql")).sort();
const startPattern = /create\s+(?:or\s+replace\s+)?function\s+([a-z_][a-z0-9_.]*)\s*\(/gi;
const bodyPattern = /\bas\s+\$([a-z_][a-z0-9_]*)?\$/i;
const violations = [];
const checked = new Set();
const securityDefinerSignatures = new Set();
const migrationSources = [];

function argumentCount(source, openIndex) {
  let depth = 0;
  let singleQuoted = false;
  let doubleQuoted = false;
  let commas = 0;
  let hasContent = false;
  for (let i = openIndex; i < source.length; i++) {
    const char = source[i];
    const next = source[i + 1];
    if (singleQuoted) {
      hasContent = true;
      if (char === "'" && next === "'") { i++; continue; }
      if (char === "'") singleQuoted = false;
      continue;
    }
    if (doubleQuoted) {
      hasContent = true;
      if (char === '"' && next === '"') { i++; continue; }
      if (char === '"') doubleQuoted = false;
      continue;
    }
    if (char === "'") { singleQuoted = true; hasContent = true; continue; }
    if (char === '"') { doubleQuoted = true; hasContent = true; continue; }
    if (char === "(") { depth++; if (depth > 1) hasContent = true; continue; }
    if (char === ")") {
      depth--;
      if (depth === 0) return hasContent ? commas + 1 : 0;
      continue;
    }
    if (depth === 1) {
      if (char === ",") commas++;
      else if (!/\s/.test(char)) hasContent = true;
    }
  }
  return null;
}

for (const file of files) {
  const sql = await readFile(path.join(migrationsDir, file), "utf8");
  migrationSources.push(sql);
  const starts = [...sql.matchAll(startPattern)];
  for (let i = 0; i < starts.length; i++) {
    const start = starts[i].index ?? 0;
    const endOfStatement = starts[i + 1]?.index ?? sql.length;
    const section = sql.slice(start, endOfStatement);
    const body = bodyPattern.exec(section);
    if (!body) continue;
    const header = section.slice(0, body.index + body[0].length);
    if (!/\bsecurity\s+definer\b/i.test(header)) continue;
    const name = starts[i][1].toLowerCase();
    const openIndex = start + starts[i][0].lastIndexOf("(");
    const arity = argumentCount(sql, openIndex);
    const signature = `${name}/${arity}`;
    const label = `${file}: ${name}`;
    checked.add(label);
    if (arity === null) violations.push(`${label} has an unreadable argument list`);
    else securityDefinerSignatures.add(signature);
    if (!/\bset\s+search_path\s*=\s*(?:''|""|'\s*'|"\s*")/i.test(header)) {
      violations.push(`${label} is SECURITY DEFINER without an explicitly empty search_path`);
    }
  }
}

const revokedRolesBySignature = new Map();
const allSql = migrationSources.join("\n");
for (const match of allSql.matchAll(/revoke\s+all\s+on\s+function\s+([\s\S]*?)\s+from\s+([^;]*);/gi)) {
  const functionList = match[1];
  const roles = match[2].toLowerCase();
  const functionPattern = /\b(public|private)\.([a-z_][a-z0-9_]*)\s*\(/gi;
  for (const fn of functionList.matchAll(functionPattern)) {
    const openIndex = fn.index + fn[0].lastIndexOf("(");
    const arity = argumentCount(functionList, openIndex);
    if (arity === null) continue;
    const signature = `${fn[1].toLowerCase()}.${fn[2].toLowerCase()}/${arity}`;
    const revokedRoles = revokedRolesBySignature.get(signature) ?? new Set();
    for (const role of roles.matchAll(/\b(public|anon|authenticated|service_role)\b/g)) revokedRoles.add(role[1]);
    revokedRolesBySignature.set(signature, revokedRoles);
  }
}
for (const signature of securityDefinerSignatures) {
  const roles = revokedRolesBySignature.get(signature);
  if (!roles) violations.push(`${signature} has no matching-arity source-visible REVOKE ALL ON FUNCTION statement`);
  else if (!roles.has("public")) violations.push(`${signature} does not explicitly revoke inherited PUBLIC execution`);
}
if (violations.length) {
  console.error("SECURITY DEFINER search_path/execute ACL violations found:");
  for (const violation of [...new Set(violations)]) console.error(`- ${violation}`);
  process.exitCode = 1;
} else {
  console.log(`Static SECURITY DEFINER check passed: ${checked.size} declarations across ${securityDefinerSignatures.size} distinct name/arity signatures have an empty search_path and a matching-arity REVOKE ALL naming PUBLIC.`);
}
