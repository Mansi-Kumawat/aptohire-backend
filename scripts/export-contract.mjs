#!/usr/bin/env node
// Static contract package exporter. A live Supabase schema dump/types are best-effort extras.
import { cp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const docs = path.join(root, "docs");
const migrationsDir = path.join(root, "supabase/migrations");
const functionsDir = path.join(root, "supabase/functions");
const out = path.join(root, "contract-dist");
const schemasOut = path.join(out, "schemas");
const agentsOut = path.join(out, "agents");
// Rebuild the generated package from scratch so removed schemas cannot linger as stale contracts.
await rm(out, { recursive: true, force: true });
await mkdir(schemasOut, { recursive: true });
await mkdir(agentsOut, { recursive: true });

const migrationFiles = (await readdir(migrationsDir)).filter((name) => name.endsWith(".sql")).sort();
const objects = new Map();
const policies = [];
const grants = [];
const buckets = new Set();
const realtime = new Set();
const migrationInventory = [];
for (const file of migrationFiles) {
  const sql = await readFile(path.join(migrationsDir, file), "utf8");
  const declared = new Set();
  for (const [kind, re] of [
    ["table", /create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public|private)\.([a-z_][a-z0-9_]*)/gi],
    ["view", /create\s+(?:or\s+replace\s+)?view\s+(?:public|private)\.([a-z_][a-z0-9_]*)/gi],
    ["function", /create\s+(?:or\s+replace\s+)?function\s+(?:public|private)\.([a-z_][a-z0-9_]*)/gi],
  ]) {
    for (const match of sql.matchAll(re)) {
      const set = objects.get(match[1]) ?? new Set(); set.add(kind); objects.set(match[1], set); declared.add(match[1]);
    }
  }
  for (const match of sql.matchAll(/create\s+policy\s+([a-z_][a-z0-9_]*)\s+on\s+((?:public|private|storage)\.[a-z_][a-z0-9_]*)[\s\S]*?;/gi))
    policies.push(`- \`${match[2]}\` · \`${match[1]}\` — ${match[0].replace(/\s+/g, " ").trim()}`);
  for (const match of sql.matchAll(/\b(?:grant|revoke)\b[^;]*?\bon\s+(?:(?:table|function)\s+)?(?:public|private|storage)\.[a-z_][a-z0-9_]*(?:\([^;]*?\))?[^;]*;/gi))
    grants.push(`- ${match[0].replace(/\s+/g, " ").trim()}`);
  for (const match of sql.matchAll(/(?:values|,\s*)\s*\(\s*'([a-z0-9_-]+)'\s*,/gi)) {
    if (/storage\.buckets/i.test(sql.slice(Math.max(0, match.index - 500), match.index))) buckets.add(match[1]);
  }
  for (const match of sql.matchAll(/alter\s+publication\s+supabase_realtime\s+add\s+table\s+public\.([a-z_][a-z0-9_]*)/gi)) realtime.add(match[1]);
  migrationInventory.push({ file, declared });
}

const frozen = await readFile(path.join(docs, "FROZEN-CONTRACTS.md"), "utf8");
const functionNames = (await readdir(functionsDir, { withFileTypes: true })).filter((entry) => entry.isDirectory() && !entry.name.startsWith("_")).map((entry) => entry.name).sort();
function portalFor(name) {
  if (name.startsWith("admin-")) return "admin console";
  if (["public-verify", "submit-application"].includes(name)) return "root site";
  if (name === "roster-import") return "university portal";
  if (["request-access", "reveal-student", "match-job", "extract-job-skills"].includes(name)) return "organization portal";
  if (["audit-submission", "agent-callback", "retention-cleanup"].includes(name)) return "internal worker";
  if (name === "complete-signup") return "shared signup";
  return "student portal";
}
function methodFor(name) { return name === "public-verify" ? "GET" : name === "profile-sync" ? "GET/POST" : "POST"; }
function authFor(name, detected) {
  if (["public-verify", "submit-application"].includes(name)) return "none";
  if (name === "audit-submission") return "service-role bearer";
  if (name === "agent-callback") return "timestamped HMAC";
  if (name === "retention-cleanup") return "dedicated secret header";
  if (name === "profile-sync") return "JWT POST; one-use signed-state GET callback";
  return detected;
}
const contracts = [];
for (const name of functionNames) {
  let source = "";
  try { source = await readFile(path.join(functionsDir, name, "index.ts"), "utf8"); } catch { /* retain folder in static inventory */ }
  const block = source.match(/withHandler\s*\(\s*\{([\s\S]*?)\}\s*,/)?.[1] ?? "";
  const read = (regex, fallback) => block.match(regex)?.[1]?.trim() ?? fallback;
  contracts.push({
    name, portal: portalFor(name), method: methodFor(name),
    auth: authFor(name, read(/\bauth\s*:\s*["']([^"']+)["']/, "manual/unknown")),
    roles: read(/\broles\s*:\s*(\[[^\]]*\])/, "not declared in withHandler"),
    aal2: /\baal2\s*:\s*true/.test(block) ? "required" : "not declared",
    frozen: frozen.includes(`\`${name}\``) ? "frozen-contract mention" : "not marked frozen",
    input: read(/\binput\s*:\s*([A-Za-z_$][\w$]*)/, "manual/unknown"),
    output: read(/\boutput\s*:\s*([A-Za-z_$][\w$]*)/, "manual/unknown"),
    rates: [...new Set([...source.matchAll(/p_bucket\s*:\s*["']([^"']+)["']/g)].map((m) => m[1]))].join(", ") || "not statically found",
    errors: [...new Set([...source.matchAll(/new\s+HttpError\(\s*["']([A-Z_]+)["']/g)].map((m) => m[1]))].sort().join(", ") || "not statically found",
  });
}

const schemaSource = path.join(functionsDir, "_shared/schemas");
const schemaFiles = [];
for (const name of (await readdir(schemaSource)).filter((n) => n.endsWith(".ts") && !n.endsWith("_test.ts")).sort()) {
  await cp(path.join(schemaSource, name), path.join(schemasOut, name)); schemaFiles.push(`schemas/${name}`);
}
const agentSource = path.join(functionsDir, "_shared/agents");
for (const name of ["audit-schema.ts", "project-assignment.ts", "job-description.ts"]) {
  await cp(path.join(agentSource, name), path.join(agentsOut, name)); schemaFiles.push(`agents/${name}`);
}

const inventory = [
  "# Generated backend inventory (static source scan)", "", `Generated ${new Date().toISOString()} from migration files and function folders.`, "",
  "> Static source inventory only: it does not prove SQL or Edge Functions execute. A live local schema dump and generated TypeScript types are included only when the Supabase CLI and local stack are available.", "",
  "## Migrations", "", ...migrationInventory.map(({ file, declared }) => `- \`${file}\`${declared.size ? `: ${[...declared].sort().map((x) => `\`${x}\``).join(", ")}` : ""}`), "",
  "## SQL objects declared by migrations", "", ...[...objects].sort(([a], [b]) => a.localeCompare(b)).map(([name, kinds]) => `- \`${name}\` — ${[...kinds].sort().join(", ")}`), "",
  "## Policies declared by migrations", "", ...[...new Set(policies)].sort(), "",
  "## Grants and revokes declared by migrations", "", ...[...new Set(grants)].sort(), "",
  "## Storage buckets declared", "", ...[...buckets].sort().map((name) => `- \`${name}\``), "",
  "## Realtime tables declared", "", ...[...realtime].sort().map((name) => `- \`${name}\``), "",
  "## Edge Function folders", "", ...functionNames.map((name) => `- \`${name}\``), "",
  "## Parsed handler contract metadata (source scan; portal mapping inferred; verify against prompts/runtime)", "",
  "| Function | Portal* | Method* | Auth | Roles | AAL2 | Frozen* | Input schema | Output schema | Rate buckets* | Error codes* |", "|---|---|---|---|---|---|---|---|---|---|---|",
  ...contracts.map((x) => `| \`${x.name}\` | ${x.portal} | ${x.method} | ${x.auth} | ${x.roles} | ${x.aal2} | ${x.frozen} | ${x.input} | ${x.output} | ${x.rates} | ${x.errors} |`), "",
  "*Portal/method/frozen marker/rate bucket/error lists are static source heuristics, not full contract validation.", "",
  "## Zod / agent schema sources copied to this package", "", ...schemaFiles.map((x) => `- \`${x}\``), "",
];
await writeFile(path.join(out, "INVENTORY.md"), inventory.join("\n"));
const contract = await readFile(path.join(docs, "CONTRACT.md"), "utf8");
await writeFile(path.join(out, "FROZEN-CONTRACTS.md"), frozen);
await writeFile(path.join(out, "CONTRACT.md"), `${contract.trim()}\n\n---\n\n## Generated inventory\n\nSee [INVENTORY.md](./INVENTORY.md) for migrations, SQL objects, policies, grants, buckets, Realtime tables, Edge Function folders, and schema sources. The implementation and verification status in the source contract remains authoritative.\n`);

const schemaDump = spawnSync("supabase", ["db", "dump", "--local", "--schema", "public,private,storage"], { cwd: root, encoding: "utf8" });
if (schemaDump.status === 0) await writeFile(path.join(out, "database-schema.sql"), schemaDump.stdout);
else console.warn("Supabase CLI/local database unavailable; static contract inventory was exported without database-schema.sql.");
const types = spawnSync("supabase", ["gen", "types", "typescript", "--local"], { cwd: root, encoding: "utf8" });
if (types.status === 0) await writeFile(path.join(out, "database.types.ts"), types.stdout);
else console.warn("Supabase CLI/local database unavailable; database.types.ts was not generated.");
console.log(`Wrote contract-dist/CONTRACT.md, FROZEN-CONTRACTS.md, INVENTORY.md, and ${schemaFiles.length} schema sources; inventoried ${objects.size} SQL object names and ${functionNames.length} function folders.`);
