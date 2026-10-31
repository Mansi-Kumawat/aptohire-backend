export type RegisterOutcome =
  | "verified_roster"
  | "needs_student_id"
  | "verified_student_id"
  | "unverified"
  | "confirm_existing"
  | "roster_no_match";

export function resolveDetectOutcome(verifiedEmail: boolean, approvedDomainMatches: number, rosterMatches: number): RegisterOutcome {
  if (!verifiedEmail || approvedDomainMatches !== 1) return "needs_student_id";
  return rosterMatches === 1 ? "verified_roster" : "roster_no_match";
}

export function resolveStudentIdOutcome(approvedUniversity: boolean, rosterMatch: boolean): RegisterOutcome {
  return approvedUniversity && rosterMatch ? "verified_student_id" : "roster_no_match";
}

export function resolveUnregisteredOutcome(): RegisterOutcome {
  return "unverified";
}

export function resolveExistingAffiliationOutcome(current: RegisterOutcome, hasDifferentCurrentUniversity: boolean): RegisterOutcome {
  return hasDifferentCurrentUniversity && (current === "verified_roster" || current === "verified_student_id")
    ? "confirm_existing"
    : current;
}
