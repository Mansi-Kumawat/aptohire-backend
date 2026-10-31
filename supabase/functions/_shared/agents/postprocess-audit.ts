import { AuditOutputSchema, type AuditOutput } from "./audit-schema.ts";

const weights: Record<AuditOutput["criteria"][number]["key"], number> = {
  functionality: 25,
  quality: 20,
  ui_accessibility: 15,
  testing: 10,
  documentation: 10,
  problem_solving: 10,
  communication: 10,
};
const injectionPattern = /ignore (?:all )?(?:previous|prior) instructions|reveal (?:the )?(?:system|hidden) prompt|developer message|disregard (?:your|all) rules/i;

export function detectPromptInjection(text: string): boolean {
  return injectionPattern.test(text);
}

export function scrubExcerpt(text: string): string {
  return text
    .replace(/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/gi, "[redacted private key]")
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted email]")
    .replace(/\b(?:\+?\d[\d ().-]{7,}\d)\b/g, "[redacted phone]")
    .replace(/https?:\/\/\S+/gi, "[redacted URL]")
    .replace(/\b(?:sb_secret_|sk_(?:live|test|proj)[_-]|github_pat_|gh[pousr]_)[A-Za-z0-9_-]{8,}\b/gi, "[redacted secret]")
    .replace(/\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/g, "[redacted secret]")
    .replace(/\bAIza[0-9A-Za-z_-]{30,}\b/g, "[redacted secret]")
    .replace(/\b(?:xox[baprs]-)[A-Za-z0-9-]{10,}\b/gi, "[redacted secret]")
    .replace(/\b(?:authorization\s*:\s*)?bearer\s+[A-Za-z0-9._~+/-]+=*/gi, "[redacted bearer token]")
    .replace(/\b(password|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|secret|token)\s*[:=]\s*[^\s,;]+/gi, "$1=[redacted]")
    .slice(0, 1200);
}

export function postprocessAudit(raw: unknown, allowedEvidenceRefs: ReadonlySet<string>, untrustedContent: string, low: number, high: number): AuditOutput {
  let candidate = raw;
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    const record = raw as Record<string, unknown>;
    if (Array.isArray(record.next_steps)) candidate = { ...record, next_steps: record.next_steps.slice(0, 3) };
  }
  const parsed = AuditOutputSchema.parse(candidate);
  let weighted = 0;
  let weightTotal = 0;
  let evidenceCount = 0;
  const criteria = parsed.criteria.map((criterion) => {
    const weight = weights[criterion.key];
    const evidence = criterion.evidence.filter((item) => allowedEvidenceRefs.has(item.evidence_ref)).map((item) => {
      evidenceCount++;
      return { ...item, ...(item.excerpt ? { excerpt: scrubExcerpt(item.excerpt) } : {}) };
    });
    // An asserted score with no manifest-backed evidence is not a score we should apply.
    const insufficient_evidence = criterion.insufficient_evidence || evidence.length === 0;
    if (!insufficient_evidence) {
      weighted += Math.max(0, Math.min(100, criterion.score)) * weight;
      weightTotal += weight;
    }
    return { ...criterion, insufficient_evidence, score: Math.max(0, Math.min(100, criterion.score)), rationale: scrubExcerpt(criterion.rationale).slice(0, 280), evidence };
  });
  const overall = weightTotal ? Math.round(weighted / weightTotal) : 0;
  const injection = detectPromptInjection(untrustedContent);
  const invalidEvidenceDropped = parsed.criteria.some((criterion) => criterion.evidence.some((item) => !allowedEvidenceRefs.has(item.evidence_ref)));
  const evidenceCoverage = Math.max(0.2, weightTotal / 100);
  const confidence = Math.max(0, Math.min(1, parsed.confidence * evidenceCoverage * (weightTotal ? 1 : 0.4) * (invalidEvidenceDropped ? 0.8 : 1) * (evidenceCount ? 1 : 0.7)));
  return AuditOutputSchema.parse({
    ...parsed,
    overall_score: overall,
    confidence,
    summary: scrubExcerpt(parsed.summary).slice(0, 600),
    criteria,
    transcript: parsed.transcript.map((item) => ({ ...item, text: scrubExcerpt(item.text) })),
    visual_observations: parsed.visual_observations.map((item) => scrubExcerpt(item).slice(0, 500)),
    next_steps: parsed.next_steps.slice(0, 3).map((item) => scrubExcerpt(item).slice(0, 500)), 
    prompt_injection_attempt: parsed.prompt_injection_attempt || injection,
    borderline: overall >= low && overall <= high,
  });
}
