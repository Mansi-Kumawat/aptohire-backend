export const DEMAND_REASONS = [
  "no_eligible",
  "incomplete_assessments",
  "insufficient_evidence",
  "skills_mismatch",
  "opted_out",
  "not_assessed",
] as const;

export type DemandReason = typeof DEMAND_REASONS[number];
export type DemandCounts = Record<DemandReason, number>;

export function emptyDemandCounts(): DemandCounts {
  return {
    no_eligible: 0,
    incomplete_assessments: 0,
    insufficient_evidence: 0,
    skills_mismatch: 0,
    opted_out: 0,
    not_assessed: 0,
  };
}

export type DemandCandidateState = {
  discoverable: boolean;
  hasCandidateProfile: boolean;
  insufficientEvidence: boolean;
  verifiedSkillCount: number;
  requirementCount: number;
  coverage: number;
  coverageFloor: number;
};

/** Returns one mutually exclusive explanation for a currently affiliated student, or null when matched. */
export function demandReason(state: DemandCandidateState): DemandReason | null {
  if (!state.discoverable) return "opted_out";
  if (!state.hasCandidateProfile) return "no_eligible";
  if (state.insufficientEvidence) return "insufficient_evidence";
  if (state.verifiedSkillCount === 0) return "not_assessed";
  if (state.verifiedSkillCount < state.requirementCount) return "incomplete_assessments";
  if (state.coverage < state.coverageFloor) return "skills_mismatch";
  return null;
}
