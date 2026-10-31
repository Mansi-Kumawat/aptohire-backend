import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { findSecretLabels, scanWorkspace } from "./secret-scan.js";

test("secret scanner recognizes configured LLM token families without leaking values", () => {
  const cases = [
    ["Google API key", "AIza" + "A".repeat(35)],
    ["OpenAI API key", "sk-proj-" + "B".repeat(30)],
    ["Anthropic API key", "sk-ant-api03-" + "C".repeat(30)],
    ["Groq API key", "gsk_" + "D".repeat(30)],
    ["OpenRouter API key", "sk-or-v1-" + "e".repeat(64)],
    ["Hugging Face token", "hf_" + "F".repeat(35)],
  ];
  for (const [expected, token] of cases) {
    const labels = findSecretLabels(`candidate=${token}`);
    assert.deepEqual(labels, [expected]);
    assert.equal(labels.join(" ").includes(token), false);
  }
});

test("secret scanner retains coverage for repository, cloud, and payment credentials", () => {
  const cases = [
    ["private key block", "-----BEGIN RSA " + "PRIVATE KEY-----"],
    ["Supabase secret key", "sb_secret_" + "A".repeat(24)],
    ["AWS access key", "AKIA" + "B".repeat(16)],
    ["GitHub token", "ghp_" + "C".repeat(30)],
    ["Stripe secret key", "sk_live_" + "D".repeat(24)],
  ];
  for (const [expected, token] of cases) assert.deepEqual(findSecretLabels(token), [expected]);
});

test("secret scanner ignores only Supabase CLI runtime secrets under supabase/.temp", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "aptohire-secret-scan-"));
  const runtimeDir = path.join(root, "supabase", ".temp", "start-secrets");
  const otherTempDir = path.join(root, "other", ".temp");
  const syntheticSecret = "sb_secret_" + "X".repeat(24);
  try {
    await mkdir(runtimeDir, { recursive: true });
    await mkdir(otherTempDir, { recursive: true });
    await writeFile(path.join(runtimeDir, "docker.env"), `SUPABASE_SECRET=${syntheticSecret}\n`);
    assert.deepEqual(await scanWorkspace(root), []);

    await writeFile(path.join(otherTempDir, "config.env"), `VALUE=${syntheticSecret}\n`);
    const findings = await scanWorkspace(root);
    assert.equal(findings.length, 1);
    assert.match(findings[0], /^other\/\.temp\/config\.env:1: possible Supabase secret key \(value redacted\)$/);
    assert.equal(findings[0].includes(syntheticSecret), false);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("secret scanner ignores placeholders and ordinary model/config strings", () => {
  for (const value of ["placeholder", "", "gemini-2.5-flash", "sk-ant-api03-short", "https://example.test"]) {
    assert.deepEqual(findSecretLabels(value), []);
  }
});
