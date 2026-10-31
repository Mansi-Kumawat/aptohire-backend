import { AuditOutputSchema, type AuditOutput } from "./audit-schema.ts";

export interface MockAuditInput {
  submission_id: string;
  title: string;
  bundle_refs: string[];
  prompt_version: string;
  untrusted_content: string;
}

const keys: AuditOutput["criteria"][number]["key"][] = ["functionality", "quality", "ui_accessibility", "testing", "documentation", "problem_solving", "communication"];
function stableSeed(value: string): number {
  let hash = 2166136261;
  for (const char of value) hash = Math.imul(hash ^ char.charCodeAt(0), 16777619) >>> 0;
  return hash >>> 0;
}

export async function mockAudit(input: MockAuditInput): Promise<AuditOutput> {
  if (input.title.includes("[fail]")) throw new Error("MOCK_RUN_FAILED");
  if (input.title.includes("[slow]")) await new Promise((resolve) => setTimeout(resolve, 40_000));
  const seed = stableSeed(input.submission_id);
  await new Promise((resolve) => setTimeout(resolve, 1_000 + (seed % 2_001)));
  const availableEvidence = input.bundle_refs.filter((ref) => /^[a-z0-9:_./-]{1,160}$/i.test(ref));
  const criteria = keys.map((key, index) => ({
    key,
    score: 42 + ((seed >>> (index % 24)) + index * 7) % 45,
    confidence: availableEvidence.length ? 0.72 : 0.42,
    rationale: availableEvidence.length
      ? `Synthetic mock observation for ${key.replaceAll("_", " ")}; independently verify the cited evidence.`
      : `No reviewable evidence was bundled for ${key.replaceAll("_", " ")}; this criterion is insufficient and must not be treated as a low score.`,
    insufficient_evidence: availableEvidence.length === 0,
    evidence: availableEvidence.length ? [{ evidence_ref: availableEvidence[index % availableEvidence.length], excerpt: `Evidence locator ${availableEvidence[index % availableEvidence.length]}` }] : [],
  }));
  const raw = {
    rubric_version: "web-frontend@1",
    prompt_version: input.prompt_version,
    overall_score: 50,
    confidence: availableEvidence.length ? 0.72 : 0.4,
    summary: "Deterministic synthetic mock audit. This is not an evaluation of real work.",
    criteria,
    transcript: [],
    visual_observations: [],
    next_steps: availableEvidence.length
      ? ["Independently review the supplied evidence", "Confirm accessibility behavior", "Add or run focused tests"]
      : ["Attach a reviewable evidence bundle", "Keep this audit pending human review", "Do not infer a score from missing evidence"],
    prompt_injection_attempt: /ignore (?:all )?(?:previous|prior) instructions|reveal (?:the )?(?:system|hidden) prompt/i.test(input.untrusted_content),
  };
  return AuditOutputSchema.parse(raw);
}
