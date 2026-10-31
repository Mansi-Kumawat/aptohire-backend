import { chooseTemplate } from "./project-assignment.ts";

function tokens(value: unknown): Set<string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return new Set();
  const brief = value as { title?: unknown; scenario?: unknown; deliverables?: unknown };
  const text = [brief.title, brief.scenario, ...(Array.isArray(brief.deliverables) ? brief.deliverables : [])]
    .filter((part): part is string => typeof part === "string").join(" ").normalize("NFKC").toLowerCase();
  return new Set(text.match(/[\p{L}\p{N}]{3,}/gu) ?? []);
}

export function projectBriefSimilarity(left: unknown, right: unknown): number {
  const a = tokens(left);
  const b = tokens(right);
  if (!a.size || !b.size) return 0;
  let intersection = 0;
  for (const token of a) if (b.has(token)) intersection++;
  return intersection / (a.size + b.size - intersection);
}

/** Chooses by stable seed, then re-rolls away from recent near-duplicate briefs when possible. */
export function chooseDiverseTemplate<T extends { id: string }>(
  candidates: T[],
  recentTemplateIds: Set<string>,
  recentBriefs: unknown[],
  seed: string,
  render: (candidate: T) => unknown,
  maxSimilarity = 0.72, // TODO(decision): validate this similarity cutoff against the curated template set before launch.
): T | null {
  const available = candidates.filter((candidate) => !recentTemplateIds.has(candidate.id));
  if (!available.length) return null;
  const initial = chooseTemplate(available, new Set(), seed);
  if (!initial || !recentBriefs.length) return initial;
  const similarity = (candidate: T) => Math.max(0, ...recentBriefs.map((recent) => projectBriefSimilarity(render(candidate), recent)));
  if (similarity(initial) < maxSimilarity) return initial;
  const diverse = available.filter((candidate) => similarity(candidate) < maxSimilarity);
  const pool = diverse.length ? diverse : available.filter((candidate) => similarity(candidate) === Math.min(...available.map(similarity)));
  return chooseTemplate(pool, new Set(), `${seed}:similarity-reroll`) ?? initial;
}
