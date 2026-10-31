#!/usr/bin/env node
// Static guard for the frozen API contract: public SQL views must name columns
// explicitly. This is not a PostgreSQL parser; CI's local migration run is the
// authoritative syntax/runtime check.
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const migrationsDir = path.join(root, "supabase/migrations");

function maskCommentsAndStrings(sql) {
  const chars = [...sql];
  let i = 0;
  while (i < chars.length) {
    if (chars[i] === "-" && chars[i + 1] === "-") {
      while (i < chars.length && chars[i] !== "\n") chars[i++] = " ";
      continue;
    }
    if (chars[i] === "/" && chars[i + 1] === "*") {
      chars[i++] = " "; chars[i++] = " ";
      let depth = 1;
      while (i < chars.length && depth) {
        if (chars[i] === "/" && chars[i + 1] === "*") { chars[i++] = " "; chars[i++] = " "; depth++; }
        else if (chars[i] === "*" && chars[i + 1] === "/") { chars[i++] = " "; chars[i++] = " "; depth--; }
        else if (chars[i] !== "\n") chars[i++] = " ";
        else i++;
      }
      continue;
    }
    if (chars[i] === "$") {
      const delimiter = sql.slice(i).match(/^\$(?:[a-z_][a-z_0-9]*)?\$/i)?.[0];
      if (delimiter) {
        const close = sql.indexOf(delimiter, i + delimiter.length);
        const stop = close < 0 ? chars.length : close + delimiter.length;
        while (i < stop) {
          if (chars[i] !== "\n") chars[i] = " ";
          i++;
        }
        continue;
      }
    }
    if (chars[i] === "'") {
      chars[i++] = " ";
      while (i < chars.length) {
        if (chars[i] === "'" && chars[i + 1] === "'") { chars[i++] = " "; chars[i++] = " "; }
        else if (chars[i] === "'") { chars[i++] = " "; break; }
        else if (chars[i] !== "\n") chars[i++] = " ";
        else i++;
      }
      continue;
    }
    i++;
  }
  return chars.join("");
}

const files = (await readdir(migrationsDir)).filter((name) => /^\d{4}_.*\.sql$/.test(name)).sort();
const violations = [];
let viewCount = 0;
for (const file of files) {
  const source = await readFile(path.join(migrationsDir, file), "utf8");
  const masked = maskCommentsAndStrings(source);
  const viewPattern = /\bcreate\s+(?:or\s+replace\s+)?view\b([\s\S]*?)\bas\b([\s\S]*?);/gi;
  for (const match of masked.matchAll(viewPattern)) {
    viewCount++;
    const definition = match[0];
    const sqlIdentifier = String.raw`(?:"(?:[^"]|"")*"|[a-z_][\w$]*)`;
    const selectStarPattern = new RegExp(String.raw`\bselect\s+(?:(?:all|distinct(?:\s+on\s*\([^)]*\))?)\s+)?(?:${sqlIdentifier}(?:\s*\.\s*${sqlIdentifier})*\s*\.\s*)?\*`, "i");
    const selectStar = selectStarPattern.exec(match[2]);
    if (!selectStar) continue;
    const prefix = masked.slice(0, match.index);
    const line = prefix.split("\n").length;
    const viewName = match[1].trim().replace(/\s+with\s*\([\s\S]*$/i, "").trim();
    violations.push(`${file}:${line}: view ${viewName} uses SELECT *`);
    void definition;
  }
}
if (violations.length) {
  console.error(`Found SELECT * in ${violations.length} SQL view definition(s):\n${violations.join("\n")}`);
  process.exit(1);
}
console.log(`View column-list check passed: scanned ${viewCount} SQL view definitions across ${files.length} migrations; no SELECT * found. Static source check only.`);
