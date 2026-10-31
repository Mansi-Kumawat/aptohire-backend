export type MatchLevel = "Emerging" | "Competent" | "Proficient" | "Advanced";
export type MatchRequirement = { skill_id: string; weight: number; min_level: MatchLevel };
export type MatchSkillEvidence = { skill_id: string; score: number; level: string; name?: string | null };
export type MatchScoreFloors = Record<MatchLevel, number>;

export type MatchRequirementResult = {
  coverage: number;
  structuredScore: number;
  meetsCoverageFloor: boolean;
  reasons: string[];
  gaps: string[];
};

/** Deterministic weighted threshold coverage and recruiter-readable evidence facts. */
export function scoreMatchRequirements(
  requirements: readonly MatchRequirement[],
  evidence: readonly MatchSkillEvidence[],
  levelFloors: MatchScoreFloors,
  coverageFloor: number,
  skillNames: ReadonlyMap<string, string> = new Map(),
): MatchRequirementResult {
  const totalWeight = requirements.reduce((sum, item) => sum + item.weight, 0);
  const bySkill = new Map<string, MatchSkillEvidence>();
  for (const item of evidence) if (!bySkill.has(item.skill_id)) bySkill.set(item.skill_id, item);
  const weightedCoverage = requirements.reduce((sum, requirement) => {
    const row = bySkill.get(requirement.skill_id);
    const threshold = levelFloors[requirement.min_level];
    const ratio = row && Number.isFinite(threshold) && threshold > 0
      ? Math.min(1, Number(row.score) / threshold)
      : 0;
    return sum + ratio * requirement.weight;
  }, 0);
  const coverage = totalWeight > 0 ? weightedCoverage / totalWeight : 0;
  const byWeight = [...requirements].sort((a, b) => b.weight - a.weight);
  const reasons = byWeight.filter((requirement) => bySkill.has(requirement.skill_id)).slice(0, 3).map((requirement) => {
    const row = bySkill.get(requirement.skill_id)!;
    return `Verified ${row.name || skillNames.get(requirement.skill_id) || "skill"} — ${row.level} (${Number(row.score)})`;
  });
  const gaps = byWeight.filter((requirement) => {
    const row = bySkill.get(requirement.skill_id);
    return !row || Number(row.score) < Number(levelFloors[requirement.min_level]);
  }).slice(0, 3).map((requirement) => {
    const row = bySkill.get(requirement.skill_id);
    return row
      ? `Below requested ${requirement.min_level} in ${row.name || skillNames.get(requirement.skill_id) || "skill"}`
      : `No verified evidence for required skill ${skillNames.get(requirement.skill_id) || "skill"}`;
  });
  return {
    coverage,
    structuredScore: Math.round(coverage * 10000) / 100,
    meetsCoverageFloor: evidence.length > 0 && coverage >= coverageFloor,
    reasons,
    gaps,
  };
}
