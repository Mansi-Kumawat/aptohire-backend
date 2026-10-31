import { evidenceItemFromRef, type EvidenceItem } from "./evidence-item.ts";
import { isOwnedVideoObjectPath } from "../retention-path.ts";

const MAX_DOCUMENTS = 10;
const MAX_DOCUMENT_BYTES = 100_000;
const MAX_TOTAL_DOCUMENT_BYTES = 250_000;
const MAX_README_BYTES = 100_000;
const MAX_REPO_FILE_BYTES = 40_000;
const MAX_REPO_SOURCE_FILES = 3;
const MAX_INLINE_MEDIA_BYTES = 14_000_000;
const ALLOWED_MEDIA_TYPES = new Set(["video/mp4", "video/webm", "video/quicktime"]);
const MAX_PROMPT_CHARS = 24_000;
const MAX_CITED_LINES = 60;
const MAX_DOCUMENT_EXCERPT_CHARS = 2_000;
const MAX_README_EXCERPT_CHARS = 4_000;
const TEXT_EXTENSIONS = new Set(["md", "txt", "csv", "json", "html", "css", "js", "jsx", "ts", "tsx"]);
const REPO_SOURCE_EXTENSIONS = new Set(["html", "css", "js", "jsx", "mjs", "cjs", "ts", "tsx", "vue", "svelte", "py"]);

export interface AuditEvidenceInput {
  submissionId: string;
  studentId: string;
  title: string;
  description: string | null;
  githubUrl: string | null;
  documentPaths: string[];
  originalityAnswers: unknown;
  claimedSkills: string[];
  videoAvailable?: boolean;
  videoPath?: string | null;
  liveUrlAvailable?: boolean;
  studentName?: string | null;
  studentEmail?: string | null;
  universityNames?: string[];
  sensitiveTerms?: string[];
}
export interface AuditEvidenceBundle {
  submission: {
    title: string;
    description: string;
    skills_claimed: string[];
    ai_use: string;
  };
  repository: {
    languages: string[];
    tests_present: boolean;
    readme_present: boolean;
    tree: string[];
    commit_stats: { count: number; first: string | null; last: string | null; sampled: boolean } | null;
  } | null;
  documents: Array<{ label: string; ref: string; text: string }>;
  evidence: EvidenceItem[];
  untrusted_content: string;
  limitations: string[];
  media: Array<{ ref: string; mimeType: string; bytes: Uint8Array }>;
}
export interface BundleDependencies {
  fetcher?: typeof fetch;
  downloadDocument: (path: string) => Promise<Uint8Array | null>;
  downloadVideo?: (path: string) => Promise<{ bytes: Uint8Array; mimeType: string; durationSeconds?: number } | null>;
  maxVideoDurationSeconds?: number;
  timeLimitMs?: number;
}

function stripUrlAndContact(text: string): string {
  return text
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted email]")
    .replace(/\b(?:\+?\d[\d ().-]{7,}\d)\b/g, "[redacted phone]")
    .replace(/https?:\/\/[^\s<>"']+/gi, "[redacted URL]")
    .replace(/@[\p{L}\p{N}_.-]{2,}/gu, "[redacted handle]")
    .replace(/\b(?:sb_secret|sk_live|sk_test|gh[pousr]_[A-Za-z0-9_]{20,})\b/gi, "[redacted secret]")
    .replace(/\b(password|api[_ -]?key|access[_ -]?token|token)\s*[:=]\s*[^\s,;]+/gi, "$1=[redacted]");
}

export function redactStudentIdentity(text: string, names: string[] = []): string {
  const output = stripUrlAndContact(text);
  const sensitiveTokens = new Set<string>();
  for (const name of names) {
    const clean = name.trim().normalize("NFKC");
    if (clean.length < 3) continue;
    // For email identifiers, redact the local-part identity but never treat generic
    // domain tokens such as "test" or "gmail" as personal names in repository paths.
    const identityText = clean.includes("@") ? clean.split("@", 1)[0] : clean;
    for (const token of identityText.split(/[^\p{L}\p{M}\p{N}]+/u)) {
      if (token.length >= 3) sensitiveTokens.add(token.normalize("NFKC").toLowerCase());
    }
  }
  return output.replace(/[\p{L}\p{M}\p{N}]+/gu, (token) =>
    sensitiveTokens.has(token.normalize("NFKC").toLowerCase()) ? "[redacted identity]" : token
  ).slice(0, MAX_PROMPT_CHARS);
}

function repositoryPathContainsDirectIdentifier(path: string, names: string[]): boolean {
  return /\[redacted (?:identity|email|phone|secret)\]/.test(redactStudentIdentity(path, names));
}

function githubRepository(urlText: string | null): { owner: string; repo: string } | null {
  if (!urlText) return null;
  try {
    const url = new URL(urlText);
    if (url.protocol !== "https:" || !["github.com", "www.github.com"].includes(url.hostname.toLowerCase()) ||
      url.port || url.username || url.password || url.search || url.hash) return null;
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts.length !== 2 || !/^[A-Za-z0-9_.-]{1,39}$/.test(parts[0]) || !/^[A-Za-z0-9_.-]{1,100}$/.test(parts[1])) return null;
    return { owner: parts[0], repo: parts[1].replace(/\.git$/i, "") };
  } catch {
    return null;
  }
}

async function limitedJson(response: Response, maxBytes: number): Promise<unknown | null> {
  const declared = Number(response.headers.get("content-length") ?? "0");
  if (!response.ok || declared > maxBytes) {
    try { await response.body?.cancel(); } catch { /* best-effort close of rejected response */ }
    return null;
  }
  const reader = response.body?.getReader();
  if (!reader) return null;
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  try { return JSON.parse(new TextDecoder().decode(bytes)); } catch { return null; }
}

function linesExcerpt(
  text: string,
  label: string,
  kind: "repo" | "doc",
  evidence: EvidenceItem[],
  maxChars = MAX_DOCUMENT_EXCERPT_CHARS,
): { ref: string; text: string } | null {
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  const excerptLines: string[] = [];
  let chars = 0;
  for (const line of lines.slice(0, MAX_CITED_LINES)) {
    if (chars >= maxChars) break;
    const remaining = maxChars - chars;
    const excerpt = line.length + 1 > remaining ? line.slice(0, remaining) : line;
    excerptLines.push(excerpt);
    chars += excerpt.length + 1;
    if (excerpt.length < line.length) break;
  }
  if (!excerptLines.some((line) => line.trim())) return null;
  const ref = `${kind}:${label}#L1-L${excerptLines.length}`;
  const item = evidenceItemFromRef(ref);
  if (!item) return null;
  evidence.push(item);
  return { ref, text: excerptLines.join("\n") };
}

const GITHUB_HEADERS = {
  accept: "application/vnd.github+json",
  "x-github-api-version": "2022-11-28",
  "user-agent": "AptoHire-Audit/1.0",
};

async function githubJson(
  fetcher: typeof fetch,
  url: string,
  timeoutMs: number,
  maxBytes: number,
): Promise<{ response: Response; json: unknown | null }> {
  const response = await fetcher(url, {
    headers: GITHUB_HEADERS,
    redirect: "error",
    signal: AbortSignal.timeout(timeoutMs),
  });
  return { response, json: await limitedJson(response, maxBytes) };
}

function safeRepoPath(path: string): boolean {
  return path.length > 0 && path.length <= 160 && /^[A-Za-z0-9._/-]+$/.test(path) &&
    !path.startsWith("/") && !path.includes("\\") &&
    !path.split("/").some((part) => !part || part === "." || part === "..") &&
    !/(^|\/)(node_modules|vendor|dist|build|coverage|\.git)(\/|$)/i.test(path) &&
    !/(^|\/)(\.env|.*secret.*|.*credential.*|.*private[-_]?key.*)(\/|$)/i.test(path);
}

function repoSourcePaths(paths: string[], namesToRedact: string[] = []): string[] {
  const eligible = paths.filter((path) => {
    if (!safeRepoPath(path) || repositoryPathContainsDirectIdentifier(path, namesToRedact)) return false;
    const filename = path.split("/").at(-1) ?? "";
    const extension = filename.split(".").at(-1)?.toLowerCase() ?? "";
    return REPO_SOURCE_EXTENSIONS.has(extension) || ["package.json", "tsconfig.json", "vite.config.js", "vite.config.ts"].includes(filename);
  });
  const tests = eligible.filter((path) => /(^|\/)(test|tests|spec|specs)(\/|\.|$)/i.test(path) || /\.(test|spec)\.[cm]?[jt]sx?$/i.test(path));
  const sources = eligible.filter((path) => !tests.includes(path) && REPO_SOURCE_EXTENSIONS.has(path.split(".").at(-1)?.toLowerCase() ?? ""));
  const configs = eligible.filter((path) => ["package.json", "tsconfig.json", "vite.config.js", "vite.config.ts"].includes(path.split("/").at(-1) ?? ""));
  return [...new Set([sources[0], tests[0], configs[0], sources[1], tests[1]].filter((path): path is string => Boolean(path)))].slice(0, MAX_REPO_SOURCE_FILES);
}

function githubFileText(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const record = value as { content?: unknown; encoding?: unknown; size?: unknown; type?: unknown };
  if (record.type !== "file" || record.encoding !== "base64" || typeof record.content !== "string" ||
    (typeof record.size === "number" && record.size > MAX_REPO_FILE_BYTES)) return null;
  const compact = record.content.replace(/\s/g, "");
  if (compact.length > MAX_REPO_FILE_BYTES * 2) return null;
  try { return new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(atob(compact), (char) => char.charCodeAt(0))); }
  catch { return null; }
}

function commitDate(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function commitTimestamp(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const commit = (value as { commit?: unknown }).commit;
  if (!commit || typeof commit !== "object") return null;
  const details = commit as { author?: { date?: unknown } | null; committer?: { date?: unknown } | null };
  return commitDate(details.committer?.date) ?? commitDate(details.author?.date);
}

function safeDocumentPath(path: string, studentId: string, submissionId: string): boolean {
  return path.length <= 300 && path.startsWith(`${studentId}/${submissionId}/`) &&
    !path.includes("\\") && !path.split("/").some((part) => !part || part === "." || part === "..") &&
    /^[A-Za-z0-9._/-]+$/.test(path);
}

function decodeUtf8(bytes: Uint8Array): string | null {
  try { return new TextDecoder("utf-8", { fatal: true }).decode(bytes); } catch { return null; }
}

export async function buildAuditEvidenceBundle(input: AuditEvidenceInput, dependencies: BundleDependencies): Promise<AuditEvidenceBundle> {
  if (!input.submissionId || !input.studentId || input.documentPaths.length > MAX_DOCUMENTS) throw new Error("INVALID_EVIDENCE_INPUT");
  const names = [input.studentName ?? "", input.studentEmail ?? "", ...(input.universityNames ?? []), ...(input.sensitiveTerms ?? [])];
  const evidence: EvidenceItem[] = [];
  const media: AuditEvidenceBundle["media"] = [];
  const documents: AuditEvidenceBundle["documents"] = [];
  const limitations: string[] = [];
  const fetcher = dependencies.fetcher ?? fetch;
  const timeoutMs = Math.max(500, Math.min(10_000, dependencies.timeLimitMs ?? 4_000));
  const deadline = Date.now() + timeoutMs;
  const boundedFetcher: typeof fetch = (input, init) => {
    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) return Promise.reject(new Error("EVIDENCE_FETCH_DEADLINE_EXCEEDED"));
    return fetcher(input, { ...init, signal: AbortSignal.timeout(remainingMs) });
  };
  const namesToRedact = names.filter(Boolean);
  const title = redactStudentIdentity(input.title, namesToRedact).slice(0, 500);
  const description = redactStudentIdentity(input.description ?? "", namesToRedact).slice(0, 4_000);
  const aiUse = redactStudentIdentity(JSON.stringify(input.originalityAnswers ?? {}), namesToRedact).slice(0, 4_000);

  let repository: AuditEvidenceBundle["repository"] = null;
  const repo = githubRepository(input.githubUrl);
  if (input.githubUrl && !repo) limitations.push("The GitHub URL was not a public repository URL accepted for metadata lookup.");
  if (repo) {
    try {
      const base = `https://api.github.com/repos/${encodeURIComponent(repo.owner)}/${encodeURIComponent(repo.repo)}`;
      const metadataResult = await githubJson(boundedFetcher, base, timeoutMs, 64_000);
      const metadata = metadataResult.json as Record<string, unknown> | null;
      if (!metadata || metadata.private === true || metadata.archived === true || typeof metadata.default_branch !== "string") {
        limitations.push("Public repository metadata was unavailable; repository claims were not inferred.");
      } else {
        const [languagesResult, treeResult] = await Promise.all([
          githubJson(boundedFetcher, `${base}/languages`, timeoutMs, 32_000),
          githubJson(boundedFetcher, `${base}/git/trees/${encodeURIComponent(metadata.default_branch)}?recursive=1`, timeoutMs, 1_000_000),
        ]);
        const languages = languagesResult.json;
        const langNames = languages && typeof languages === "object" && !Array.isArray(languages)
          ? Object.keys(languages as Record<string, unknown>).filter((name) => /^[A-Za-z0-9+#.-]{1,40}$/.test(name)).slice(0, 20)
          : [];
        const treeJson = treeResult.json as { tree?: Array<{ path?: unknown; type?: unknown }>; truncated?: unknown } | null;
        const paths = (treeJson?.tree ?? []).flatMap((item) =>
          typeof item.path === "string" && item.type === "blob" && safeRepoPath(item.path) ? [item.path] : []
        ).slice(0, 5_000);
        const testsPresent = paths.some((path) => /(^|\/)(test|tests|spec|specs)(\/|\.|$)/i.test(path) || /\.(test|spec)\.[cm]?[jt]sx?$/i.test(path));
        const tree = paths.filter((path) => !repositoryPathContainsDirectIdentifier(path, [...namesToRedact, repo.owner]))
          .slice(0, 24).map((path) => path.slice(0, 120));
        repository = { languages: langNames, tests_present: testsPresent, readme_present: false, tree, commit_stats: null };

        const readmeResult = await githubJson(boundedFetcher, `${base}/readme`, timeoutMs, MAX_README_BYTES);
        const readmeText = githubFileText(readmeResult.json);
        if (readmeText !== null) {
          const excerpt = linesExcerpt(redactStudentIdentity(readmeText, [...namesToRedact, repo.owner]), "README.md", "repo", evidence, MAX_README_EXCERPT_CHARS);
          if (excerpt) {
            repository.readme_present = true;
            documents.push({ label: "Public repository README", ref: excerpt.ref, text: excerpt.text });
          }
        }

        const chosenPaths = repoSourcePaths(paths, [...namesToRedact, repo.owner]);
        let sourceIndex = 0;
        for (const path of chosenPaths) {
          const encodedPath = path.split("/").map(encodeURIComponent).join("/");
          const fileResult = await githubJson(
            boundedFetcher,
            `${base}/contents/${encodedPath}?ref=${encodeURIComponent(metadata.default_branch)}`,
            timeoutMs,
            MAX_REPO_FILE_BYTES,
          );
          const sourceText = githubFileText(fileResult.json);
          if (sourceText === null) {
            limitations.push("One or more repository source files were unavailable or not safe UTF-8 text.");
            continue;
          }
          sourceIndex++;
          const excerpt = linesExcerpt(
            redactStudentIdentity(sourceText, [...namesToRedact, repo.owner]),
            path,
            "repo",
            evidence,
            MAX_DOCUMENT_EXCERPT_CHARS,
          );
          if (excerpt) documents.push({ label: `Public repository file ${sourceIndex}`, ref: excerpt.ref, text: excerpt.text });
        }
        if (treeJson?.truncated === true) limitations.push("The public repository tree was truncated by GitHub; only a bounded subset was considered.");

        const commitsResult = await githubJson(boundedFetcher, `${base}/commits?per_page=1`, timeoutMs, 64_000);
        const recentCommits = Array.isArray(commitsResult.json) ? commitsResult.json : [];
        if (recentCommits.length) {
          const latest = commitTimestamp(recentCommits[0]);
          const link = commitsResult.response.headers.get("link") ?? "";
          const lastPageText = /<[^>]+[?&]page=(\d+)[^>]*>\s*;\s*rel="last"/i.exec(link)?.[1];
          const lastPage = lastPageText ? Number(lastPageText) : 1;
          const pageCount = Number.isSafeInteger(lastPage) && lastPage >= 1 && lastPage <= 100_000 ? lastPage : 1;
          let first = latest;
          if (pageCount > 1) {
            const oldestResult = await githubJson(boundedFetcher, `${base}/commits?per_page=1&page=${pageCount}`, timeoutMs, 64_000);
            const oldestCommits = Array.isArray(oldestResult.json) ? oldestResult.json : [];
            if (oldestCommits.length) first = commitTimestamp(oldestCommits[0]);
          }
          repository.commit_stats = { count: pageCount, first, last: latest, sampled: !lastPageText };
        }
      }
    } catch {
      limitations.push("Public repository evidence could not be fetched within the bounded request window.");
    }
  }

  let totalDocumentBytes = 0;
  for (const [index, path] of input.documentPaths.entries()) {
    if (!safeDocumentPath(path, input.studentId, input.submissionId)) {
      throw new Error("DOCUMENT_PATH_NOT_OWNED");
    }
    const filename = path.split("/").at(-1) ?? "";
    const extension = filename.split(".").at(-1)?.toLowerCase() ?? "";
    if (!TEXT_EXTENSIONS.has(extension)) {
      limitations.push(`Document ${index + 1} was omitted because its format is not supported for text extraction.`);
      continue;
    }
    try {
      const bytes = await dependencies.downloadDocument(path);
      if (!bytes || bytes.byteLength > MAX_DOCUMENT_BYTES || totalDocumentBytes + bytes.byteLength > MAX_TOTAL_DOCUMENT_BYTES) {
        limitations.push(`Document ${index + 1} was omitted because it was unavailable or exceeded the text extraction limit.`);
        continue;
      }
      totalDocumentBytes += bytes.byteLength;
      const decoded = decodeUtf8(bytes);
      if (decoded === null) {
        limitations.push(`Document ${index + 1} was omitted because it was not valid UTF-8 text.`);
        continue;
      }
      const refLabel = `document-${index + 1}.${extension}`;
      const excerpt = linesExcerpt(redactStudentIdentity(decoded, namesToRedact), refLabel, "doc", evidence);
      if (excerpt) documents.push({ label: `Submission document ${index + 1}`, ref: excerpt.ref, text: excerpt.text });
    } catch {
      limitations.push(`Document ${index + 1} could not be read safely.`);
    }
  }

  if (input.videoPath) {
    if (!isOwnedVideoObjectPath(input.videoPath, input.studentId, input.submissionId)) {
      throw new Error("VIDEO_PATH_NOT_OWNED");
    }
    if (dependencies.downloadVideo) {
      try {
        const source = await dependencies.downloadVideo(input.videoPath);
        const duration = source?.durationSeconds;
        const durationInvalid = dependencies.maxVideoDurationSeconds !== undefined &&
          (typeof duration !== "number" || !Number.isFinite(duration) || duration <= 0 || duration > dependencies.maxVideoDurationSeconds);
        if (!source || source.bytes.byteLength === 0 || source.bytes.byteLength > MAX_INLINE_MEDIA_BYTES || !ALLOWED_MEDIA_TYPES.has(source.mimeType.toLowerCase()) || durationInvalid) {
          limitations.push("The submitted media was omitted because its size, duration, storage object, or media type was not within the safe analysis limits.");
        } else {
          const ref = "video:0";
          const item = evidenceItemFromRef(ref);
          if (item) {
            evidence.push(item);
            media.push({ ref, mimeType: source.mimeType.toLowerCase(), bytes: source.bytes });
          }
        }
      } catch {
        limitations.push("The submitted media could not be read from its owner-scoped storage path.");
      }
    } else {
      limitations.push("The submitted media was not analyzed because no bounded storage reader was configured.");
    }
  }
  if (input.videoAvailable && !input.videoPath) {
    limitations.push("A remote video URL was not fetched; only owner-scoped Supabase Storage media is eligible for analysis.");
  }
  if (input.liveUrlAvailable) {
    limitations.push("The live site was not fetched or analyzed by this evidence collector.");
  }
  const evidenceRefs = new Set(evidence.map((item) => item.ref));
  const safeDocuments = documents.filter((item) => evidenceRefs.has(item.ref));
  const escapeContent = (value: string) => value.replaceAll("<", "&lt;").replaceAll(">", "&gt;");
  const skills = input.claimedSkills.slice(0, 30).map((skill) => redactStudentIdentity(skill, namesToRedact).slice(0, 80));
  const contentBlocks = [
    `<student_content title>\n${escapeContent(title)}\n</student_content>`,
    `<student_content description>\n${escapeContent(description)}\n</student_content>`,
    `<student_content originality_answers>\n${escapeContent(aiUse)}\n</student_content>`,
    `<student_content claimed_skills>\n${escapeContent(JSON.stringify(skills))}\n</student_content>`,
  ];
  const includedDocuments: typeof safeDocuments = [];
  for (const item of safeDocuments) {
    const block = `<student_content evidence_ref=${item.ref}>\n${escapeContent(item.text)}\n</student_content>`;
    const candidate = [...contentBlocks, ...includedDocuments.map((doc) => `<student_content evidence_ref=${doc.ref}>\n${escapeContent(doc.text)}\n</student_content>`), block].join("\n\n");
    if (candidate.length > MAX_PROMPT_CHARS) {
      limitations.push("Some readable excerpts were omitted to keep the audit prompt within its size limit.");
      continue;
    }
    includedDocuments.push(item);
  }
  const includedRefs = new Set([...includedDocuments.map((item) => item.ref), ...media.map((item) => item.ref)]);
  const includedEvidence = evidence.filter((item) => includedRefs.has(item.ref));
  const untrustedContent = [...contentBlocks, ...includedDocuments.map((item) => `<student_content evidence_ref=${item.ref}>\n${escapeContent(item.text)}\n</student_content>`)].join("\n\n");
  return {
    submission: { title, description, skills_claimed: skills, ai_use: aiUse },
    repository,
    documents: includedDocuments,
    evidence: includedEvidence,
    untrusted_content: untrustedContent,
    limitations: [...new Set(limitations)].slice(0, 12),
    media,
  };
}
