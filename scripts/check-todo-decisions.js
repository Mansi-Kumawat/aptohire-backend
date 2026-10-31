import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const inventoryPath = path.join(root, "docs/TODO_DECISIONS.md");
const inventory = await readFile(inventoryPath, "utf8");
const candidates = [
  path.join(root, "supabase/functions"),
  path.join(root, "supabase/migrations"),
  path.join(root, "supabase/seed.sql"),
  path.join(root, "docs/CONTRACT.md"),
  path.join(root, "docs/prompts/00-aptohire-backend-prompt.md"),
];
const files = [];
async function collect(candidate) {
  try {
    const info = await stat(candidate);
    if (info.isDirectory()) {
      for (const entry of await readdir(candidate)) await collect(path.join(candidate, entry));
    } else if (/\.(?:ts|sql|md)$/.test(candidate)) files.push(candidate);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
}
for (const candidate of candidates) await collect(candidate);
const sourceFiles = [];
for (const file of files) {
  const source = await readFile(file, "utf8");
  if (!source.includes("TODO(decision)")) continue;
  const relative = path.relative(root, file).split(path.sep).join("/");
  if (relative === "docs/TODO_DECISIONS.md") continue;
  sourceFiles.push(relative);
}
const missing = [...new Set(sourceFiles)].filter((file) => !inventory.includes(file));
if (missing.length) {
  console.error("TODO(decision) source files missing from docs/TODO_DECISIONS.md:");
  for (const file of missing) console.error(`- ${file}`);
  process.exitCode = 1;
} else {
  console.log(`TODO(decision) inventory check passed: ${new Set(sourceFiles).size} source files are represented in docs/TODO_DECISIONS.md.`);
}
