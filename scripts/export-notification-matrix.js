#!/usr/bin/env node
// Static notification-kind-to-source/test candidate map; textual matches do not prove delivery.
import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { mergeNotificationMatrix } from "./notification-matrix-output.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const promptPath = path.join(root, "docs/prompts/00-aptohire-backend-prompt.md");
const outputPath = path.join(root, "docs/NOTIFICATION_MATRIX.md");

async function filesUnder(dir, predicate) {
  const files = [];
  async function walk(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) await walk(fullPath);
      else if (entry.isFile() && predicate(entry.name)) files.push(fullPath);
    }
  }
  await walk(dir);
  return files;
}
function markdownPath(file) { return `\`${path.relative(root, file).replaceAll(path.sep, "/")}\``; }

let existingMatrix = "";
try {
  existingMatrix = await readFile(outputPath, "utf8");
} catch { /* first generation has no curated tail */ }

const prompt = await readFile(promptPath, "utf8");
const section = prompt.split("### Notification kinds", 2)[1]?.split("### Extra seed requirements", 1)[0];
if (!section) throw new Error("Could not locate authoritative notification-kind list in prompt section 15A");
const kinds = [...new Set([...section.matchAll(/`([a-z][a-z_]+)`/g)].map((match) => match[1]))];
const sourceFiles = [
  // The notification CHECK-constraint migration enumerates allowed literals, not producers.
  ...await filesUnder(path.join(root, "supabase/migrations"), (name) => name.endsWith(".sql") && name !== "0025_notification_kinds.sql"),
  ...await filesUnder(path.join(root, "supabase/functions"), (name) => name.endsWith(".ts") && !name.endsWith("_test.ts")),
];
const testFiles = [
  ...await filesUnder(path.join(root, "supabase/tests"), (name) => name.endsWith(".test.sql")),
  ...await filesUnder(path.join(root, "supabase/functions"), (name) => name.endsWith("_test.ts")),
];
const sourceText = await Promise.all(sourceFiles.map(async (file) => [file, await readFile(file, "utf8")]));
const testText = await Promise.all(testFiles.map(async (file) => [file, await readFile(file, "utf8")]));
const rows = kinds.map((kind) => {
  const producers = sourceText.filter(([, text]) =>
    text.includes(`'${kind}'`) || text.includes(`"${kind}"`)
    || (kind === "new_match" && text.includes("buildNewMatchNotifications"))
  ).map(([file]) => file);
  const tests = testText.filter(([, text]) => text.includes(kind)).map(([file]) => file);
  return { kind, producers, tests };
});
const withProducer = rows.filter((row) => row.producers.length).length;
const withTestCandidate = rows.filter((row) => row.tests.length).length;
const lines = [
  "# Notification-kind source/test candidate matrix (static; review required)",
  "",
  "> Expected kinds are parsed from the authoritative prompt §15A. Producer and test columns use raw source-text matching; these matches do **not** prove that a code path reaches the producer, that the payload is correct, or that a test asserts delivery/identity minimization. Runtime DB tests and code review remain required.",
  "",
  `Prompt kinds: ${rows.length}; kinds with a producer-source text match: ${withProducer}; kinds with a test-file text match: ${withTestCandidate}.`,
  "",
  "| Kind | Producer-source files (text match) | Candidate test files (text match) |",
  "|---|---|---|",
  ...rows.map((row) => `| \`${row.kind}\` | ${row.producers.length ? row.producers.map(markdownPath).join(", ") : "none found"} | ${row.tests.length ? row.tests.map(markdownPath).join(", ") : "none found"} |`),
  "",
  "## Manual review required",
  "",
  "For each kind, verify the producer is invoked under the expected lifecycle transition, payload fields are allowlisted, organization-bound notifications contain no student identity, and tests assert both recipient delivery and prohibited fields. `none found` is a source-text gap signal, not proof a producer/test does not exist.",
  "",
];
await writeFile(outputPath, mergeNotificationMatrix(lines.join("\n"), existingMatrix));
console.log(`Wrote docs/NOTIFICATION_MATRIX.md (${rows.length} prompt kinds; ${withProducer} producer-source matches; ${withTestCandidate} test-file matches; static only).`);
