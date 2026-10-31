#!/usr/bin/env node
// Generate a review backlog linking source-inventoried RLS policies to pgTAP files
// that mention the protected relation. This is a candidate list, not proof of behavior.
import { readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { splitMarkdownTableRow } from "./markdown-table.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const inventoryPath = path.join(root, "docs/RLS_POLICY_INVENTORY.md");
const testsPath = path.join(root, "supabase/tests");
const outputPath = path.join(root, "docs/RLS_COVERAGE_CANDIDATES.md");
const matrixPath = path.join(root, "docs/RLS_MATRIX.md");
const inventory = await readFile(inventoryPath, "utf8");
const tests = (await readdir(testsPath)).filter((name) => /^\d{4}_.+\.test\.sql$/.test(name)).sort();
const testTexts = await Promise.all(tests.map(async (name) => [name, await readFile(path.join(testsPath, name), "utf8")]));
const rows = [];
for (const line of inventory.split(/\r?\n/)) {
  if (!line.startsWith("| `public.") && !line.startsWith("| `private.") && !line.startsWith("| `storage.")) continue;
  const cells = splitMarkdownTableRow(line).map((cell) => cell.replaceAll("`", ""));
  if (cells.length < 8) continue;
  const [relation, policy, command, roles, using, withCheck, migration] = cells;
  const table = relation.split(".").at(-1);
  const escapedTable = table.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&");
  const relationPattern = new RegExp(`(?:(?:public|private|storage)\\s*\\.\\s*)?${escapedTable}\\b`, "i");
  const nameMentionCells = splitMarkdownTableRow(line);
  const explicitCell = nameMentionCells[7] ?? "";
  const explicitTests = [...explicitCell.matchAll(/`(\d{4}_[^`]+\.test\.sql)`/g)].map((match) => match[1]);
  const candidates = testTexts.filter(([, text]) => relationPattern.test(text)).map(([name]) => name);
  rows.push({ relation, policy, command, roles, using, withCheck, migration, explicitTests, candidates });
}
const covered = rows.filter((row) => row.candidates.length).length;
const explicitCount = rows.filter((row) => row.explicitTests.length).length;
const output = [
  "# RLS behavioral-test candidate map (static; review required)",
  "",
  "> Generated from `RLS_POLICY_INVENTORY.md` and raw pgTAP text matches on relation names. A listed test is only a **candidate**: this scan does not prove it sets the intended JWT/role, asserts both allowed and denied rows, exercises `USING`/`WITH CHECK`, or even reaches the policy. A `none found` result may be a false negative if a test exercises a view or helper instead of the base relation. Do not treat this artifact as authorization verification.",
  "",
  `Policies inventoried: ${rows.length}. Policies explicitly mentioned by test filename/text: ${explicitCount}. Policies with at least one relation-name candidate test: ${covered}. Policies without a candidate match: ${rows.length - covered}.`,
  "",
  "| Relation | Policy | Command | Role target | USING | WITH CHECK | Defined in | Tests mentioning policy name | Candidate pgTAP files (relation text only) |",
  "|---|---|---|---|---|---|---|---|",
  ...rows.map((row) => `| \`${row.relation}\` | \`${row.policy}\` | ${row.command} | ${row.roles} | ${row.using} | ${row.withCheck} | \`${row.migration}\` | ${row.explicitTests.length ? row.explicitTests.map((name) => `\`${name}\``).join(", ") : "none found"} | ${row.candidates.length ? row.candidates.map((name) => `\`${name}\``).join(", ") : "none found"} |`),
  "",
  "## Required human/test follow-up",
  "",
  "For each policy, inspect its candidate test(s) and add/verify explicit positive and negative pgTAP assertions under the correct role and JWT claims. Include table/column grants, policy-specific ownership, expired/revoked/disabled states, and admin AAL1/AAL2 boundaries where relevant. Prefer dedicated policy-named tests or maintain an explicit mapping in `docs/RLS_MATRIX.md`.",
  "",
];
await writeFile(outputPath, output.join("\n"));

const beginMarker = "<!-- BEGIN GENERATED RLS POLICY REGISTER -->";
const endMarker = "<!-- END GENERATED RLS POLICY REGISTER -->";
const register = [
  beginMarker,
  "## Generated policy-by-policy audit register",
  "",
  "> Generated from the source inventory. This enumerates current policy definitions one row each; explicit policy-name test mentions and relation-name candidate matches are both raw text signals, **not evidence of behavioral coverage**. Review each candidate and add positive/negative assertions before marking a policy verified.",
  "",
  `Policies inventoried: ${rows.length}; explicit policy-name test mentions: ${explicitCount}; relation-name candidate matches: ${covered}.`,
  "",
  "| Relation | Policy | Command | Role target | USING | WITH CHECK | Migration | Tests mentioning policy name | Relation-name candidate tests |",
  "|---|---|---|---|---|---|---|---|---|",
  ...rows.map((row) => `| \`${row.relation}\` | \`${row.policy}\` | ${row.command} | ${row.roles} | ${row.using} | ${row.withCheck} | \`${row.migration}\` | ${row.explicitTests.length ? row.explicitTests.map((name) => `\`${name}\``).join(", ") : "none found"} | ${row.candidates.length ? row.candidates.map((name) => `\`${name}\``).join(", ") : "none found"} |`),
  "",
  endMarker,
].join("\n");
let matrix = await readFile(matrixPath, "utf8");
const begin = matrix.indexOf(beginMarker);
const end = matrix.indexOf(endMarker);
if (begin >= 0 && end >= begin) {
  matrix = `${matrix.slice(0, begin)}${register}${matrix.slice(end + endMarker.length)}`;
} else {
  matrix = `${matrix.trimEnd()}\n\n${register}\n`;
}
await writeFile(matrixPath, matrix);
console.log(`Wrote docs/RLS_COVERAGE_CANDIDATES.md and refreshed the RLS_MATRIX policy register (${rows.length} policies; ${explicitCount} exact policy-name mentions; static only).`);
