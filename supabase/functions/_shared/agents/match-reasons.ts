import { z } from "zod";

export const MatchReasonOutputSchema = z.object({
  reasons: z.array(z.object({
    alias: z.string().trim().min(1).max(80),
    reason: z.string().trim().min(1).max(180),
  }).strict()).max(20),
}).strict();

export type MatchReasonCandidate = { alias: string; facts: readonly string[] };

const safeGrammar = new Set([
  "a", "an", "and", "at", "based", "candidate", "covers", "evidence", "for", "has", "in", "match", "matches",
  "meets", "on", "relevant", "score", "scores", "shows", "skill", "skills", "strong", "the", "verified", "with",
]);
const sensitiveOrUntrustedPattern = /(?:https?:\/\/|www\.|[\w.+-]+@[\w.-]+\.[a-z]{2,}|(?:\+?\d[\d\s().-]{7,}\d)|@[a-z0-9_]{2,})/i;

function wordTokens(value: string): string[] {
  return value.normalize("NFKC").toLowerCase().match(/[a-z0-9]+/g) ?? [];
}

/** Accept only aliases in the request and generated prose whose content tokens are grounded in facts. */
export function constrainMatchReasonOutput(
  value: unknown,
  candidates: readonly MatchReasonCandidate[],
): Map<string, string> {
  const parsed = MatchReasonOutputSchema.safeParse(value);
  if (!parsed.success) return new Map();
  const byAlias = new Map(candidates.map((candidate) => [candidate.alias, candidate]));
  const accepted = new Map<string, string>();
  for (const item of parsed.data.reasons) {
    const candidate = byAlias.get(item.alias);
    if (!candidate || accepted.has(item.alias) || sensitiveOrUntrustedPattern.test(item.reason)) continue;
    const allowed = new Set([...safeGrammar, ...candidate.facts.flatMap(wordTokens), ...wordTokens(candidate.alias)]);
    const tokens = wordTokens(item.reason);
    if (!tokens.length || tokens.some((token) => !allowed.has(token))) continue;
    accepted.set(item.alias, item.reason);
  }
  return accepted;
}

export function appendConstrainedMatchReasons<T extends { alias: string; reasons: string[] }>(
  matches: T[],
  accepted: ReadonlyMap<string, string>,
): void {
  for (const match of matches) {
    const reason = accepted.get(match.alias);
    if (reason && !match.reasons.includes(reason)) match.reasons = [...match.reasons.slice(0, 2), reason];
  }
}

export function matchReasonPromptInput(candidates: readonly MatchReasonCandidate[]): string {
  return JSON.stringify(candidates.map(({ alias, facts }) => ({ alias, facts: [...facts].slice(0, 3) })));
}
