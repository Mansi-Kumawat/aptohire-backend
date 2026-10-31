import { CredentialResponseSchema } from "./schemas/common.ts";
import { publicCredentialDisplayName, isPublicCredentialSkillEligible } from "./credential.ts";

type PublicSkillRow = {
  name?: string | null;
  score: number;
  level: string;
  verified: boolean;
  share_ok: boolean;
  pending_review: boolean;
  updated_at: string | null;
};
type PublicAffiliation = { label: string; verification: "roster" | "student_id" | "unverified" };

function isoDay(value: string | null | undefined): string | undefined {
  if (!value) return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) throw new Error("invalid credential date");
  return date.toISOString().slice(0, 10);
}
function requiredIsoDay(value: string): string {
  const day = isoDay(value);
  if (!day) throw new Error("credential date missing");
  return day;
}

/** Build the anonymous response from an explicit allowlist of visibility fields and data. */
export function buildPublicCredentialResponse(input: {
  credentialId: string;
  fullName: string;
  createdAt: string;
  updatedAt: string;
  sharedFields: string[];
  skills: PublicSkillRow[];
  affiliation?: PublicAffiliation;
}) {
  const allowed = new Set(["name", "university", "skills", "levels", "scores"]);
  const shared = [...new Set(input.sharedFields.filter((field) => allowed.has(field)))];
  const eligible = input.skills.filter(isPublicCredentialSkillEligible);
  const dates = eligible.map((row) => row.updated_at).filter((value): value is string => Boolean(value)).sort();
  const name = shared.includes("name") ? publicCredentialDisplayName(input.fullName) : undefined;
  const affiliation = shared.includes("university") ? input.affiliation : undefined;
  const skills = shared.includes("skills") ? eligible.map((row) => ({
    name: row.name ?? "",
    level: shared.includes("levels") ? row.level : "Verified",
    verified: true,
    ...(shared.includes("scores") ? { score: Number(row.score) } : {}),
    ...(isoDay(row.updated_at) ? { verified_on: isoDay(row.updated_at) } : {}),
  })).filter((row) => row.name) : [];

  return CredentialResponseSchema.parse({ credential: {
    credential_id: input.credentialId,
    issued_at: requiredIsoDay(dates[0] ?? input.createdAt),
    last_updated: requiredIsoDay(dates.at(-1) ?? input.updatedAt),
    ...(name ? { display_name: name } : {}),
    ...(affiliation ? { affiliation } : {}),
    skills,
    shared_fields: shared,
  } });
}
