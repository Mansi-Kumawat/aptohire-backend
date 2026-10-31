const root = new URL("../", import.meta.url);
const migrationsDir = new URL("supabase/migrations/", root);
const functionsDir = new URL("supabase/functions/", root);
const docsDir = new URL("docs/", root);
const outDir = new URL("contract-dist/", root);
const schemaOutDir = new URL("contract-dist/schemas/", root);

await Deno.mkdir(schemaOutDir, { recursive: true });
const migrationFiles: string[] = [];
for await (const entry of Deno.readDir(migrationsDir)) if (entry.isFile && entry.name.endsWith(".sql")) migrationFiles.push(entry.name);
migrationFiles.sort();

const objects = new Map<string, Set<string>>();
const storageBuckets = new Set<string>();
const realtimeTables = new Set<string>();
const policyInventory: string[] = [];
const grantInventory: string[] = [];
const migrationInventory: Array<{ name: string; objectNames: Set<string> }> = [];
for (const file of migrationFiles) {
  const sql = await Deno.readTextFile(new URL(file, migrationsDir));
  const declaredHere = new Set<string>();
  const patterns: Array<[string, RegExp]> = [
    ["table", /create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public|private)\.([a-z_][a-z0-9_]*)/gi],
    ["view", /create\s+(?:or\s+replace\s+)?view\s+(?:public|private)\.([a-z_][a-z0-9_]*)/gi],
    ["function", /create\s+(?:or\s+replace\s+)?function\s+(?:public|private)\.([a-z_][a-z0-9_]*)/gi],
  ];
  for (const [kind, expression] of patterns) {
    for (const match of sql.matchAll(expression)) {
      const set = objects.get(match[1]) ?? new Set<string>();
      set.add(kind);
      objects.set(match[1], set);
      declaredHere.add(match[1]);
    }
  }
  for (const match of sql.matchAll(/create\s+policy\s+([a-z_][a-z0-9_]*)\s+on\s+((?:public|private|storage)\.[a-z_][a-z0-9_]*)[\s\S]*?;/gi)) {
    policyInventory.push("- `" + match[2] + "` · `" + match[1] + "` — " + match[0].replace(/\s+/g, " ").trim());
  }
  for (const match of sql.matchAll(/\b(?:grant|revoke)\b[^;]*?\bon\s+(?:(?:table|function)\s+)?(?:public|private|storage)\.[a-z_][a-z0-9_]*(?:\([^;]*?\))?[^;]*;/gi)) {
    grantInventory.push("- " + match[0].replace(/\s+/g, " ").trim());
  }
  migrationInventory.push({ name: file, objectNames: declaredHere });

  for (const match of sql.matchAll(/(?:values|,\s*)\s*\(\s*'([a-z0-9_-]+)'\s*,/gi)) {
    const start = match.index ?? 0;
    if (/storage\.buckets/i.test(sql.slice(Math.max(0, start - 500), start))) storageBuckets.add(match[1]);
  }
  for (const match of sql.matchAll(/alter\s+publication\s+supabase_realtime\s+add\s+table\s+public\.([a-z_][a-z0-9_]*)/gi)) realtimeTables.add(match[1]);
}

const frozenSource = await Deno.readTextFile(new URL("FROZEN-CONTRACTS.md", docsDir));
const functionNames: string[] = [];
for await (const entry of Deno.readDir(functionsDir)) if (entry.isDirectory && !entry.name.startsWith("_")) functionNames.push(entry.name);
functionNames.sort();
const functionContracts: Array<{ name: string; portal: string; method: string; auth: string; roles: string; aal2: string; frozen: string; input: string; output: string; rateBuckets: string; errors: string }> = [];
function methodFor(name: string): string {
  if (name === "public-verify") return "GET";
  if (name === "profile-sync") return "GET/POST";
  return "POST";
}
function authFor(name: string, detected: string): string {
  if (name === "public-verify" || name === "submit-application") return "none";
  if (name === "audit-submission") return "service-role bearer";
  if (name === "agent-callback") return "timestamped HMAC";
  if (name === "retention-cleanup") return "dedicated secret header";
  if (name === "profile-sync") return "JWT POST; one-use signed-state GET callback";
  return detected;
}
function portalFor(name: string): string {
  if (name.startsWith("admin-")) return "admin console";
  if (["public-verify", "submit-application"].includes(name)) return "root site";
  if (["roster-import"].includes(name)) return "university portal";
  if (["request-access", "reveal-student", "match-job", "extract-job-skills"].includes(name)) return "organization portal";
  if (["audit-submission", "agent-callback", "retention-cleanup"].includes(name)) return "internal worker";
  if (name === "complete-signup") return "shared signup (student/university/organization)";
  return "student portal";
}
for (const name of functionNames) {
  let source = "";
  try { source = await Deno.readTextFile(new URL(`${name}/index.ts`, functionsDir)); } catch { /* inventory keeps folders even without an entrypoint */ }
  const config = source.match(/withHandler\s*\(\s*\{([\s\S]*?)\}\s*,/);
  const block = config?.[1] ?? "";
  const read = (expression: RegExp, fallback: string) => block.match(expression)?.[1]?.trim() ?? fallback;
  functionContracts.push({
    name,
    portal: portalFor(name),
    method: methodFor(name),
    auth: authFor(name, read(/\bauth\s*:\s*["']([^"']+)["']/, "manual/unknown")),
    roles: read(/\broles\s*:\s*(\[[^\]]*\])/, "not declared in withHandler"),
    aal2: /\baal2\s*:\s*true/.test(block) ? "required" : "not declared",
    frozen: frozenSource.includes("`" + name + "`") ? "frozen-contract mention" : "not marked frozen",
    input: read(/\binput\s*:\s*([A-Za-z_$][\w$]*)/, "manual/unknown"),
    output: read(/\boutput\s*:\s*([A-Za-z_$][\w$]*)/, "manual/unknown"),
    rateBuckets: [...new Set([...source.matchAll(/p_bucket\s*:\s*["']([^"']+)["']/g)].map((match) => match[1]))].join(", ") || "not statically found",
    errors: [...new Set([...source.matchAll(/new\s+HttpError\(\s*["']([A-Z_]+)["']/g)].map((match) => match[1]))].sort().join(", ") || "not statically found",
  });
}

const schemaFiles: string[] = [];
const sourceSchemas = new URL("supabase/functions/_shared/schemas/", root);
for await (const entry of Deno.readDir(sourceSchemas)) {
  if (!entry.isFile || !entry.name.endsWith(".ts") || entry.name.endsWith("_test.ts")) continue;
  await Deno.copyFile(new URL(entry.name, sourceSchemas), new URL(entry.name, schemaOutDir));
  schemaFiles.push(entry.name);
}
const agentSchemaDir = new URL("supabase/functions/_shared/agents/", root);
const agentSchemaOut = new URL("contract-dist/agents/", root);
await Deno.mkdir(agentSchemaOut, { recursive: true });
for (const name of ["audit-schema.ts", "project-assignment.ts", "job-description.ts"]) {
  // Preserve relative imports used by the shared schema files (for example ../agents/audit-schema.ts).
  await Deno.copyFile(new URL(name, agentSchemaDir), new URL(name, agentSchemaOut));
  schemaFiles.push("../agents/" + name);
}
schemaFiles.sort();

const inventory = [
  "# Generated backend inventory (static source scan)", "",
  `Generated ${new Date().toISOString()} from migration files and function folders.`, "",
  "> Static source inventory only: it does not prove SQL or Edge Functions execute. When the local stack is running, this exporter also captures the database's schema-only dump and generated TypeScript types.", "",
  "## Migrations", "", ...migrationInventory.map(({ name, objectNames }) => "- `" + name + "`" + (objectNames.size ? ": " + [...objectNames].sort().map((n) => "`" + n + "`").join(", ") : "")), "",
  "## SQL objects declared by migrations", "", ...[...objects.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([name, kinds]) => "- `" + name + "` — " + [...kinds].sort().join(", ")), "",
  "## Policies declared by migrations", "", ...[...new Set(policyInventory)].sort(), "",
  "## Grants and revokes declared by migrations", "", ...[...new Set(grantInventory)].sort(), "",
  "## Storage buckets declared", "", ...[...storageBuckets].sort().map((name) => "- `" + name + "`"), "",
  "## Realtime tables declared", "", ...[...realtimeTables].sort().map((name) => "- `" + name + "`"), "",
  "## Edge Function folders", "", ...functionNames.map((name) => "- `" + name + "`"), "",
  "## Parsed handler contract metadata (source scan; portal mapping inferred from function names; verify against prompts/runtime)", "",
  "| Function | Portal* | Method* | Auth | Roles | AAL2 | Frozen* | Input schema | Output schema | Rate buckets* | Error codes* |", "|---|---|---|---|---|---|---|---|---|---|---|",
  ...functionContracts.map((item) => `| \`${item.name}\` | ${item.portal} | ${item.method} | ${item.auth} | ${item.roles} | ${item.aal2} | ${item.frozen} | ${item.input} | ${item.output} | ${item.rateBuckets} | ${item.errors} |`), "", "*Portal/method/frozen marker/rate bucket/error lists are static source heuristics, not full contract validation.", "",
  "## Zod / agent schema sources copied to this package", "", ...schemaFiles.map((name) => "- `" + (name.startsWith("../agents/") ? "agents/" + name.slice("../agents/".length) : "schemas/" + name) + "`"), "",
];
await Deno.writeTextFile(new URL("INVENTORY.md", outDir), inventory.join("\n"));

const contractSource = await Deno.readTextFile(new URL("CONTRACT.md", docsDir));
await Deno.writeTextFile(new URL("FROZEN-CONTRACTS.md", outDir), frozenSource);
await Deno.writeTextFile(new URL("CONTRACT.md", outDir), `${contractSource.trim()}\n\n---\n\n## Generated inventory\n\nSee [INVENTORY.md](./INVENTORY.md) for migrations, SQL objects, policies, grants, buckets, Realtime tables, Edge Function folders, and schema sources. The implementation and verification status in the source contract remains authoritative.\n`);

try {
  const result = await new Deno.Command("supabase", { args: ["db", "dump", "--local", "--schema", "public,private,storage"], stdout: "piped", stderr: "piped" }).output();
  if (result.success) await Deno.writeTextFile(new URL("database-schema.sql", outDir), new TextDecoder().decode(result.stdout));
  else console.warn("Local schema dump did not succeed; start Supabase and rerun `npm run contract:export`.");
} catch {
  console.warn("Supabase CLI/local database is unavailable; database-schema.sql was not generated.");
}
try {
  const result = await new Deno.Command("supabase", { args: ["gen", "types", "typescript", "--local"], stdout: "piped", stderr: "piped" }).output();
  if (result.success) await Deno.writeTextFile(new URL("database.types.ts", outDir), new TextDecoder().decode(result.stdout));
  else console.warn("Local Supabase type generation did not succeed; run `npm run types` after `supabase start`.");
} catch {
  console.warn("Supabase CLI is unavailable; database.types.ts was not generated. Run `npm run types` after `supabase start`.");
}
console.log(`Wrote contract-dist/CONTRACT.md, FROZEN-CONTRACTS.md, INVENTORY.md, and best-effort database schema/types; inventoried ${objects.size} SQL object names and ${functionNames.length} function folders.`);
