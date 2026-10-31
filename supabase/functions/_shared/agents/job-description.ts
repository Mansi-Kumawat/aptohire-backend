import { ExtractJobSkillsOutputSchema, type ExtractedSkill } from "../schemas/extract-job-skills.ts";

export interface SkillTaxon { slug: string; name: string }

function escapeRegExp(value: string): string {
  const special = new Set([".", "*", "+", "?", "^", "$", "{", "}", "(", ")", "|", "[", "]", "\\"]);
  return [...value].map((character) => special.has(character) ? `\\${character}` : character).join("");
}

function matchesSkill(description: string, skill: SkillTaxon): boolean {
  const variants = new Set([skill.name, skill.slug, skill.slug.replaceAll("-", " ")]);
  return [...variants].some((variant) => {
    const normalized = variant.trim().toLocaleLowerCase().replace(/\s+/g, " ");
    if (normalized.length < 2) return false;
    const escaped = escapeRegExp(normalized).replace(/\s+/g, "\\s+");
    return new RegExp(`(?:^|[^a-z0-9])${escaped}(?:$|[^a-z0-9])`, "i").test(description);
  });
}

function inferLevel(description: string): "Competent" | "Proficient" | "Advanced" {
  const text = description.toLocaleLowerCase();
  if (/\b(principal|staff|lead|senior|architect|expert)\b/.test(text)) return "Advanced";
  if (/\b(mid[- ]level|intermediate|3\+ years|4\+ years|5\+ years)\b/.test(text)) return "Proficient";
  return "Competent";
}

function suggestTitle(description: string): string | undefined {
  const first = description.split(/\r?\n/).map((line) => line.trim()).find(Boolean);
  if (!first) return undefined;
  const cleaned = first.replace(/^(job title|position|role)\s*:\s*/i, "").trim().slice(0, 120);
  return cleaned || undefined;
}

/** Deterministic local fallback; job text is treated as data and never interpreted as instructions. */
export function extractJobSkills(description: string, catalog: SkillTaxon[]) {
  const level = inferLevel(description);
  const unique = new Map<string, SkillTaxon>();
  for (const skill of catalog) if (matchesSkill(description, skill)) unique.set(skill.slug, skill);
  const matched = [...unique.values()].slice(0, 30);
  const weight = matched.length ? Number((1 / matched.length).toFixed(6)) : 0;
  const skills: ExtractedSkill[] = matched.map((skill) => ({ skill_slug: skill.slug, min_level: level, weight }));
  const title = suggestTitle(description);
  return ExtractJobSkillsOutputSchema.parse({ skills, ...(title ? { title_suggestion: title } : {}) });
}
