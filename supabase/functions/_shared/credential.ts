export type CredentialSkillEligibility = {
  verified: boolean;
  share_ok: boolean;
  pending_review: boolean;
};

/** Public credential endpoints never expose skills pending a human review. */
export function isPublicCredentialSkillEligible(skill: CredentialSkillEligibility): boolean {
  return skill.verified === true && skill.share_ok === true && skill.pending_review === false;
}

/** Reduce a shared name to a first name plus last-name initial; handle one-word names safely. */
export function publicCredentialDisplayName(fullName: string): string | undefined {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return undefined;
  return parts.length === 1 ? parts[0] : `${parts[0]} ${parts.at(-1)![0]}.`;
}
