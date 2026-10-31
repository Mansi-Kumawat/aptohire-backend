import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const testsDir = path.join(root, "supabase/tests");
const migrationsDir = path.join(root, "supabase/migrations");
const files = (await readdir(testsDir)).filter((name) => name.endsWith(".test.sql")).sort();
const migrations = (await readdir(migrationsDir)).filter((name) => name.endsWith(".sql")).sort();
const assertionNames = [
  "has_function", "hasnt_function", "ok", "is", "isnt", "like", "unlike", "matches", "doesnt_match",
  "throws_ok", "throws_like", "throws_matching", "lives_ok", "cmp_ok", "pass", "fail", "results_eq",
  "set_eq", "bag_eq", "row_eq", "is_empty", "isnt_empty", "columns_are", "has_table", "has_view",
  "has_column", "hasnt_column", "has_type", "has_enum", "has_schema", "has_trigger", "has_index",
  "has_pk", "has_fk", "hasnt_pk", "hasnt_fk", "has_role", "hasnt_role",
];
const assertionPattern = new RegExp(`^\\s*select\\s+(?:${assertionNames.join("|")})\\s*\\(`, "gim");
const failures = [];
const numbers = [];
const migrationNumbers = [];
for (const file of migrations) {
  const prefix = /^(\d{4})_.*\.sql$/.exec(file);
  if (!prefix) {
    failures.push(`${file}: migration filename must start with a four-digit sequence`);
    continue;
  }
  migrationNumbers.push(Number(prefix[1]));
}

for (const file of files) {
  const prefix = /^(\d{4})_/.exec(file);
  if (!prefix) {
    failures.push(`${file}: test filename must start with a four-digit sequence`);
    continue;
  }
  numbers.push(Number(prefix[1]));
  const source = await readFile(path.join(testsDir, file), "utf8");
  // Remove comments before counting so examples and commented-out assertions are ignored.
  const sql = source.replace(/--[^\n]*/g, "").replace(/\/\*[\s\S]*?\*\//g, "");
  if (!/^\s*begin\s*;/i.test(sql)) failures.push(`${file}: pgTAP test must start a transaction`);
  const finishes = [...sql.matchAll(/\bselect\s+\*\s+from\s+finish\s*\(\s*\)\s*;/gi)];
  if (finishes.length !== 1) failures.push(`${file}: expected exactly one select * from finish()`);
  const rollbacks = [...sql.matchAll(/^\s*rollback\s*;/gim)];
  if (rollbacks.length !== 1) failures.push(`${file}: expected exactly one rollback`);
  const plans = [...sql.matchAll(/\bselect\s+plan\s*\(\s*(\d+)\s*\)/gi)];
  if (plans.length !== 1) {
    failures.push(`${file}: expected exactly one TAP plan, found ${plans.length}`);
    continue;
  }
  assertionPattern.lastIndex = 0;
  const actual = [...sql.matchAll(assertionPattern)].length;
  const expected = Number(plans[0][1]);
  if (actual !== expected) failures.push(`${file}: TAP plan is ${expected}, counted ${actual} assertion calls`);
}

migrationNumbers.sort((a, b) => a - b);
for (let i = 0; i < migrationNumbers.length; i++) {
  if (migrationNumbers[i] !== i) {
    failures.push(`migration numbering is not contiguous at ${String(i).padStart(4, "0")}`);
    break;
  }
}
numbers.sort((a, b) => a - b);
for (let i = 0; i < numbers.length; i++) {
  if (numbers[i] !== i + 1) {
    failures.push(`pgTAP test numbering is not contiguous at ${String(i + 1).padStart(4, "0")}`);
    break;
  }
}

if (failures.length) {
  console.error("pgTAP static plan check failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log(`Static migration/TAP check passed: ${migrations.length} contiguous migrations and ${files.length} contiguous pgTAP files have plans matching recognized assertion calls.`);
}
