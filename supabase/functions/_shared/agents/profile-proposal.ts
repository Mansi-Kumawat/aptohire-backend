import type { ProfileProposal } from "../schemas/profile-sync.ts";
import { normalizedGitHubRepositoryUrl } from "../github-profile.ts";

type GitHubUser = { name?: string | null; bio?: string | null; html_url?: string; login?: string };
type GitHubRepo = { name?: string; description?: string | null; html_url?: string; language?: string | null; fork?: boolean; archived?: boolean };

/** Redact direct contact/link data before any profile content is proposed or sent to an agent. */
export function cleanProfileText(value: unknown, max = 500): string {
  if (typeof value !== "string") return "";
  // deno-lint-ignore no-control-regex -- strip control characters from untrusted profile exports
  const scrubbed = value.normalize("NFKC").replace(/<[^>]*>/g, " ").replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[redacted email]")
    .replace(/(?:\+?\d[\d\s().-]{7,}\d)/g, "[redacted phone]")
    .replace(/https?:\/\/\S+/gi, "[redacted URL]");
  return redactProfileSecrets(scrubbed).replace(/\s+/g, " ").trim().slice(0, max);
}

function cleanProfileExportText(value: unknown, max = 20_000): string {
  if (typeof value !== "string") return "";
  // Keep line boundaries for the deterministic field parser, but discard other controls.
  // deno-lint-ignore no-control-regex -- newlines are intentionally preserved; other controls are removed
  const scrubbed = value.normalize("NFKC").replace(/<[^>]*>/g, " ").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, " ")
    .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[redacted email]")
    .replace(/(?:\+?\d[\d\s().-]{7,}\d)/g, "[redacted phone]")
    .replace(/https?:\/\/\S+/gi, "[redacted URL]");
  return redactProfileSecrets(scrubbed).split(/\r?\n/).map((line) => line.replace(/[\t ]+/g, " ").trim()).filter(Boolean).join("\n").slice(0, max);
}

function redactProfileSecrets(value: string): string {
  return value
    .replace(/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/gi, "[redacted private key]")
    .replace(/\b(?:sb_secret_|sk_(?:live|test|proj)[_-]|github_pat_|gh[pousr]_)[A-Za-z0-9_-]{8,}\b/gi, "[redacted secret]")
    .replace(/\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/g, "[redacted secret]")
    .replace(/\bAIza[0-9A-Za-z_-]{30,}\b/g, "[redacted secret]")
    .replace(/\b(?:xox[baprs]-)[A-Za-z0-9-]{10,}\b/gi, "[redacted secret]")
    .replace(/\b(?:authorization\s*:\s*)?bearer\s+[A-Za-z0-9._~+/-]+=*/gi, "[redacted bearer token]")
    .replace(/\b(password|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|secret|token)\s*[:=]\s*[^\s,;]+/gi, "$1=[redacted]");
}

function textValue(value: string, max = 500): string {
  return cleanProfileText(value, max);
}

export function githubProposal(user: GitHubUser, repos: GitHubRepo[]): ProfileProposal {
  const changes: ProfileProposal["changes"] = [];
  const bio = textValue(user.bio ?? "", 280);
  if (bio) changes.push({ field: "headline", action: "update", value: bio, evidence: "GitHub public profile bio" });
  const languages = [...new Set(repos.map((repo) => textValue(repo.language ?? "", 60)).filter(Boolean))].slice(0, 12);
  if (languages.length) changes.push({ field: "skills_interest", action: "add", value: languages, evidence: "Languages listed in public repositories; not verified skills" });
  for (const repo of repos.filter((r) => !r.fork && !r.archived && normalizedGitHubRepositoryUrl(r.html_url) !== null).slice(0, 10)) {
    const repoUrl = normalizedGitHubRepositoryUrl(repo.html_url);
    const title = textValue(repo.name ?? "", 120);
    if (!repoUrl || !title) continue;
    const value = { title, description: textValue(repo.description ?? "", 400), url: repoUrl };
    changes.push({ field: "project_candidate", action: "add", value, evidence: "Public GitHub repository metadata; human review required" });
  }
  if (user.login) changes.push({ field: "links", action: "add", value: [{ label: "GitHub", url: `https://github.com/${encodeURIComponent(user.login)}` }], evidence: "Authenticated GitHub profile" });
  return { source: "github", changes: changes.slice(0, 30) };
}

export function linkedinProposal(text: string): ProfileProposal {
  const safe = cleanProfileExportText(text, 20_000);
  const lines = safe.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const changes: ProfileProposal["changes"] = [];
  const labels: Array<[RegExp, ProfileProposal["changes"][number]["field"]]> = [
    [/^(headline|professional headline)\s*[:,]\s*/i, "headline"],
    [/^(skills|top skills)\s*[:,]\s*/i, "skills_interest"],
    [/^(experience|positions)\s*[:,]?\s*/i, "experience"],
    [/^(education)\s*[:,]?\s*/i, "education"],
  ];
  for (const [pattern, field] of labels) {
    const line = lines.find((item) => pattern.test(item));
    if (!line) continue;
    const value = line.replace(pattern, "").slice(0, 1000).trim();
    if (!value) continue;
    changes.push({ field, action: "update", value, evidence: "User-provided LinkedIn export; review before applying" });
  }
  if (!changes.length && safe) changes.push({ field: "experience", action: "add", value: safe.slice(0, 1000), evidence: "User-provided LinkedIn export; review before applying" });
  return { source: "linkedin_export", changes };
}
