import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const migrationsDir = path.join(root, "supabase", "migrations");
const outputPath = path.join(root, "docs", "RLS_POLICY_INVENTORY.md");

function migrationOrder(name) {
  const n = Number(name.match(/^(\d+)_/)?.[1] ?? Number.MAX_SAFE_INTEGER);
  return Number.isFinite(n) ? n : Number.MAX_SAFE_INTEGER;
}
function cleanIdentifier(value) {
  return value.replaceAll('"', "").trim();
}
function compact(value) {
  return value.replace(/\s+/g, " ").trim();
}
function markdown(value) {
  return value.replaceAll("|", "\\|").replaceAll("`", "\\`");
}
function extractParenthesizedClause(text, keyword) {
  const match = new RegExp(`\\b${keyword}\\s*\\(`, "i").exec(text);
  if (!match) return "—";
  const open = text.indexOf("(", match.index);
  let depth = 0;
  let singleQuoted = false;
  let doubleQuoted = false;
  for (let i = open; i < text.length; i++) {
    const char = text[i];
    const next = text[i + 1];
    if (singleQuoted) {
      if (char === "'" && next === "'") { i++; continue; }
      if (char === "'") singleQuoted = false;
      continue;
    }
    if (doubleQuoted) {
      if (char === '"' && next === '"') { i++; continue; }
      if (char === '"') doubleQuoted = false;
      continue;
    }
    if (char === "'") { singleQuoted = true; continue; }
    if (char === '"') { doubleQuoted = true; continue; }
    if (char === "(") depth++;
    if (char === ")" && --depth === 0) return text.slice(open, i + 1);
  }
  return text.slice(open);
}

const files = fs.readdirSync(migrationsDir)
  .filter((name) => /^\d+_.*\.sql$/.test(name))
  .sort((a, b) => migrationOrder(a) - migrationOrder(b));
const testsDir = path.join(root, "supabase", "tests");
const testSources = fs.readdirSync(testsDir)
  .filter((name) => /^\d+_.*\.test\.sql$/.test(name))
  .sort()
  .map((name) => [name, fs.readFileSync(path.join(testsDir, name), "utf8")]);
const policies = new Map();
const rlsTables = new Map();
const issues = [];

for (const file of files) {
  const sql = fs.readFileSync(path.join(migrationsDir, file), "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .replace(/^\s*--.*$/gm, " ");
  for (const statement of sql.split(";")) {
    const create = statement.match(/\bcreate\s+policy\s+(?:if\s+not\s+exists\s+)?(?:"([^"]+)"|([\w-]+))\s+on\s+(?:only\s+)?((?:"?[\w]+"?\.)?"?[\w]+"?)([\s\S]*)/i);
    if (create) {
      const name = create[1] ?? create[2];
      const relation = cleanIdentifier(create[3]);
      const tail = compact(create[4]);
      const command = tail.match(/\bfor\s+(select|insert|update|delete|all)\b/i)?.[1]?.toUpperCase() ?? "UNSPECIFIED";
      const rolesText = tail.match(/\bto\s+([\s\S]*?)(?=\s+using\s*\(|\s+with\s+check\s*\(|\s+as\s+|$)/i)?.[1] ?? "PUBLIC (implicit)";
      const usingText = extractParenthesizedClause(tail, "using");
      const checkText = extractParenthesizedClause(tail, "with\\s+check");
      const key = `${relation}.${name}`;
      if (policies.has(key)) issues.push(`Policy replaced without a visible DROP POLICY: ${key} (${file})`);
      const testMentions = testSources.filter(([, source]) => source.includes(name)).map(([test]) => test);
      policies.set(key, { name, relation, command, roles: compact(rolesText), using: compact(usingText), check: compact(checkText), migration: file, testMentions });
      continue;
    }
    const drop = statement.match(/\bdrop\s+policy\s+(?:if\s+exists\s+)?(?:"([^"]+)"|([\w-]+))\s+on\s+(?:only\s+)?((?:"?[\w]+"?\.)?"?[\w]+"?)/i);
    if (drop) {
      const name = drop[1] ?? drop[2];
      const relation = cleanIdentifier(drop[3]);
      policies.delete(`${relation}.${name}`);
      continue;
    }
    const enable = statement.match(/\balter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?((?:"?[\w]+"?\.)?"?[\w]+"?)\s+enable\s+row\s+level\s+security\b/i);
    if (enable) rlsTables.set(cleanIdentifier(enable[1]), { migration: file, method: "explicit DDL" });
  }
  const dynamicEnable = /foreach\s+(\w+)\s+in\s+array\s+array\[([\s\S]*?)\]\s+loop\s+execute\s+format\(\s*'alter\s+table\s+([\w.]+)\.%i\s+enable\s+row\s+level\s+security'\s*,\s*\1\s*\)/gi;
  for (const match of sql.matchAll(dynamicEnable)) {
    const [, variable, names, schema] = match;
    for (const table of names.matchAll(/'([\w]+)'/g)) {
      const relation = `${schema}.${table[1]}`;
      if (!rlsTables.has(relation)) rlsTables.set(relation, { migration: file, method: `static DO-list (${variable})` });
    }
  }
}

const rows = [...policies.values()].sort((a, b) => a.relation.localeCompare(b.relation) || a.name.localeCompare(b.name));
const rlsRows = [...rlsTables].sort(([a], [b]) => a.localeCompare(b));
const policyRelationsWithoutRls = [...new Set(rows.map((row) => row.relation))]
  .filter((relation) => relation !== "storage.objects" && !rlsTables.has(relation)).sort();
const body = [
  "# Static RLS policy inventory",
  "",
  "> Generated by `npm run rls:inventory` from numbered SQL migrations. This is a source-text inventory, **not** proof that policies execute correctly and **not** the required one-to-one RLS matrix. It does not map or validate pgTAP behavior. Dynamic SQL, procedural DDL, policies changed by conditional logic, and PostgreSQL parser semantics may not be represented exactly. Review this output against the live local schema and add explicit per-policy positive and negative pgTAP tests before treating authorization as verified.",
  "",
  `Migrations scanned: ${files.length}. Active policy definitions by source-order replay: ${rows.length}. ` +
    `RLS-enable relations found: ${rlsRows.length} (explicit DDL plus extracted static DO-lists). ` +
    `Policy relations without source-visible enablement (excluding Supabase-managed storage.objects): ${policyRelationsWithoutRls.length}. ` +
    `Replacements detected without a visible drop: ${issues.length}.`,
  "",
  "## Policies",
  "",
  "| Relation | Policy | Command | To | USING (source) | WITH CHECK (source) | Last definition | Test files mentioning policy name (text scan) |",
  "|---|---|---|---|---|---|---|---|",
  ...rows.map((row) => `| \`${markdown(row.relation)}\` | \`${markdown(row.name)}\` | ${row.command} | ${markdown(row.roles)} | \`${markdown(row.using)}\` | \`${markdown(row.check)}\` | \`${row.migration}\` | ${row.testMentions.length ? row.testMentions.map((test) => `\`${test}\``).join(", ") : "none found"} |`),
  "",
  "## RLS enablement found in migration source",
  "",
  "| Relation | Detection | Migration |",
  "|---|---|---|",
  ...rlsRows.map(([relation, detail]) => `| \`${markdown(relation)}\` | ${markdown(detail.method)} | \`${detail.migration}\` |`),
  "",
  "## Policy relations without source-visible RLS enablement",
  "",
  ...(policyRelationsWithoutRls.length
    ? policyRelationsWithoutRls.map((relation) => `- Review: \`${markdown(relation)}\` has policies but no enablement statement was detected by this static scan.`)
    : ["- None found outside the Supabase-managed `storage.objects` platform relation; verify against the local schema nonetheless."]),
  "",
  "## Inventory limitations",
  "",
  "- A `test files mentioning policy name` hit is a raw text match only; it is not proof that the test asserts the policy or covers both permitted and denied rows. A test may exercise a policy without naming it.",
  "- Supabase-managed `storage.objects` is intentionally absent from this migration-source enablement list; its RLS state comes from the Supabase storage schema and must be verified in the local database.",
  "- This exporter does not resolve role inheritance, grants, view security mode, function execution rights, policy combination semantics, or table ownership/bypass behavior.",
  "- `USING` and `WITH CHECK` are preserved as SQL source snippets for human review; the extracted fragments can include surrounding formatting and are not parsed ASTs.",
  "- The separate `docs/RLS_MATRIX.md` remains the authoritative human-maintained matrix and must still match each policy to an explicit pgTAP test.",
  ...(issues.length ? ["", "## Review warnings", "", ...issues.map((issue) => `- ${issue}`)] : []),
  "",
].join("\n");

fs.writeFileSync(outputPath, body);
console.log(`Wrote ${path.relative(root, outputPath)} (${rows.length} policies; ${rlsRows.length} RLS-enable relations found; static only).`);
