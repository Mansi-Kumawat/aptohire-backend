export type ProgramLevel = "ug" | "pg";
export type UniversityLifeStatus = "incoming" | "enrolled" | "dropout" | "alumni";

/** Convert historical university labels into the frozen two-value program-level vocabulary. */
export function normalizeProgramLevel(value: unknown): ProgramLevel | null {
  if (typeof value !== "string") return null;
  const normalized = value.normalize("NFKC").trim().toLowerCase().replace(/[._'’\s-]+/g, "");
  if (["ug", "undergraduate", "undergrad", "bachelor", "bachelors", "bsc", "btech"].includes(normalized)) return "ug";
  if (["pg", "postgraduate", "graduate", "master", "masters", "msc", "mtech", "phd", "doctorate"].includes(normalized)) return "pg";
  return null;
}

export function normalizeLifeStatus(value: unknown): UniversityLifeStatus | null {
  if (value === "student") return "enrolled";
  return value === "incoming" || value === "enrolled" || value === "dropout" || value === "alumni" ? value : null;
}
