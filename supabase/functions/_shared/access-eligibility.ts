export type CurrentMatchEligibility = {
  jobOpen: boolean;
  studentHasLogin: boolean;
  studentDiscoverable: boolean;
  candidateProjectionDiscoverable: boolean;
  shareableVerifiedSkillCount: number | null;
};

/** A recruiter may request consent only from a currently visible, scored candidate on an open job. */
export function isCurrentMatchRequestable(state: CurrentMatchEligibility): boolean {
  return state.jobOpen && state.studentHasLogin && state.studentDiscoverable &&
    state.candidateProjectionDiscoverable && state.shareableVerifiedSkillCount !== null &&
    state.shareableVerifiedSkillCount > 0;
}
