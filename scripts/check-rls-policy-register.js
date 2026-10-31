#!/usr/bin/env node
// Verify that the generated policy register inside RLS_MATRIX.md lists every
// source-inventoried relation/policy pair exactly once. This is documentation
// integrity only; it does not establish behavioral RLS coverage.
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const beginMarker = "<!-- BEGIN GENERATED RLS POLICY REGISTER -->";
const endMarker = "<!-- END GENERATED RLS POLICY REGISTER -->";
const inventory = await readFile(path.join(root, "docs/RLS_POLICY_INVENTORY.md"), "utf8");
const matrix = await readFile(path.join(root, "docs/RLS_MATRIX.md"), "utf8");

function pairsFrom(markdown) {
  return [...markdown.matchAll(/^\| `([^`]+)` \| `([^`]+)` \|/gm)]
    .map((match) => `${match[1]}\u0000${match[2]}`);
}

const start = matrix.indexOf(beginMarker);
const end = matrix.indexOf(endMarker);
if (start < 0 || end <= start || matrix.indexOf(beginMarker, start + beginMarker.length) >= 0 || matrix.indexOf(endMarker, end + endMarker.length) >= 0) {
  console.error("RLS matrix must contain exactly one correctly ordered generated-register marker pair.");
  process.exit(1);
}
const block = matrix.slice(start + beginMarker.length, end);
if (!/raw text signals, \*\*not evidence of behavioral coverage\*\*/i.test(block)) {
  console.error("Generated RLS register must retain its static-only / non-proof warning.");
  process.exit(1);
}
const expected = pairsFrom(inventory);
const actual = pairsFrom(block);
const duplicates = actual.filter((pair, index) => actual.indexOf(pair) !== index);
const missing = expected.filter((pair) => !actual.includes(pair));
const unexpected = actual.filter((pair) => !expected.includes(pair));
if (expected.length === 0 || actual.length !== expected.length || duplicates.length || missing.length || unexpected.length) {
  console.error(`RLS policy register mismatch: inventory=${expected.length}, register=${actual.length}, duplicates=${duplicates.length}, missing=${missing.length}, unexpected=${unexpected.length}.`);
  process.exit(1);
}
console.log(`RLS policy register integrity passed: ${actual.length} unique relation/policy pairs match the static inventory. Behavioral authorization is not verified.`);
