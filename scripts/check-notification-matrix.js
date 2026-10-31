#!/usr/bin/env node
// Check the generated notification matrix is complete against the prompt and source files.
// Candidate matches remain static text only and never imply runtime coverage.
import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const prompt = await readFile(path.join(root, "docs/prompts/00-aptohire-backend-prompt.md"), "utf8");
const matrix = await readFile(path.join(root, "docs/NOTIFICATION_MATRIX.md"), "utf8");
const section = prompt.split("### Notification kinds", 2)[1]?.split("### Extra seed requirements", 1)[0];
if (!section) throw new Error("Prompt §15A notification-kind section is missing");
const expected = [...new Set([...section.matchAll(/`([a-z][a-z_]+)`/g)].map((match) => match[1]))];
if (!/matches do \*\*not\*\* prove that a code path reaches the producer/i.test(matrix)) {
  console.error("Notification matrix must retain its static-candidate limitation notice.");
  process.exit(1);
}
const generatedSection = matrix.split("## Manual review required", 1)[0];
const rows = [...generatedSection.matchAll(/^\| `([a-z][a-z_]+)` \| (.*?) \| (.*?) \|$/gm)];
const actual = rows.map((row) => row[1]);
const duplicates = actual.filter((kind, index) => actual.indexOf(kind) !== index);
const missing = expected.filter((kind) => !actual.includes(kind));
const unexpected = actual.filter((kind) => !expected.includes(kind));
if (duplicates.length || missing.length || unexpected.length || actual.length !== expected.length) {
  console.error(`Notification matrix mismatch: expected=${expected.length}, actual=${actual.length}, duplicates=${duplicates.length}, missing=${missing.length}, unexpected=${unexpected.length}.`);
  process.exit(1);
}
for (const row of rows) {
  const producerCell = row[2];
  const testCell = row[3];
  if (producerCell === "none found" || testCell === "none found") {
    console.error(`Notification kind ${row[1]} lacks a source or test text candidate.`);
    process.exit(1);
  }
  for (const relative of [producerCell, testCell].flatMap((cell) => [...cell.matchAll(/`([^`]+)`/g)].map((match) => match[1]))) {
    try { await access(path.join(root, relative)); }
    catch { console.error(`Notification matrix references a missing file for ${row[1]}: ${relative}`); process.exit(1); }
  }
}
console.log(`Notification matrix integrity passed: ${actual.length} prompt kinds each have source/test text candidates and existing file references. Runtime delivery is not verified.`);
