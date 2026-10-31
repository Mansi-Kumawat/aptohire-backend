import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ignoredDirs = new Set([".git", "node_modules", "dist", "build", "coverage", ".next", ".venv"]);
const skippedFiles = new Set(["secret-scan.js"]);
export const secretPatterns = [
  ["private key block", /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],
  ["Supabase secret key", /sb_secret_[A-Za-z0-9_-]{20,}/],
  ["AWS access key", /\bAKIA[0-9A-Z]{16}\b/],
  ["GitHub token", /\bgh[pousr]_[A-Za-z0-9]{30,}\b/],
  ["Google API key", /\bAIza[0-9A-Za-z_-]{35}\b/],
  ["Anthropic API key", /\bsk-ant-api\d{2}-[A-Za-z0-9_-]{24,}\b/],
  ["Groq API key", /\bgsk_[A-Za-z0-9]{24,}\b/],
  ["OpenRouter API key", /\bsk-or-v1-[A-Fa-f0-9]{64}\b/],
  ["OpenAI API key", /\bsk-(?!(?:ant-api\d{2}|or-v1)-)(?:proj-)?[A-Za-z0-9_-]{24,}\b/],
  ["Hugging Face token", /\bhf_[A-Za-z0-9]{30,}\b/],
  ["Stripe secret key", /\bsk_(?:live|test)_[A-Za-z0-9]{20,}\b/],
];

export function findSecretLabels(line) {
  return secretPatterns.flatMap(([label, regex]) => regex.test(line) ? [label] : []);
}

export async function scanWorkspace(workspaceRoot = root) {
  const findings = [];
  async function walk(dir) {
    for (const entry of await readdir(dir, { withFileTypes: true })) {
      if (entry.isDirectory() && ignoredDirs.has(entry.name)) continue;
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }
      if (!entry.isFile() || skippedFiles.has(entry.name) || entry.name === ".gitignore") continue;
      if (entry.name === ".env.example") continue;
      let content;
      try { content = await readFile(fullPath, "utf8"); } catch { continue; }
      const lines = content.split(/\r?\n/);
      for (let i = 0; i < lines.length; i++) {
        for (const label of findSecretLabels(lines[i])) {
          findings.push(`${path.relative(workspaceRoot, fullPath)}:${i + 1}: possible ${label} (value redacted)`);
        }
      }
    }
  }
  await walk(workspaceRoot);
  return findings;
}

async function main() {
  const findings = await scanWorkspace();
  if (findings.length) {
    console.error("Potential secrets detected; values are intentionally not displayed:");
    for (const finding of findings) console.error(`- ${finding}`);
    process.exitCode = 1;
  } else {
    console.log("Secret scan passed: no recognized secret patterns found.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) await main();
