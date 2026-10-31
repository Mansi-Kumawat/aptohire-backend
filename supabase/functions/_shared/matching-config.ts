const LEVELS = ["Emerging", "Competent", "Proficient", "Advanced"] as const;
export type MatchLevel = typeof LEVELS[number];
export type MatchingThresholds = { coverageFloor: number; levelFloors: Record<MatchLevel, number> };

export function parseMatchingThresholds(coverageValue: unknown, levelValue: unknown): MatchingThresholds | null {
  if (typeof coverageValue !== "number" || !Number.isFinite(coverageValue) ||
    coverageValue < 0.05 || coverageValue > 0.75 || Number(coverageValue.toFixed(2)) !== coverageValue ||
    !levelValue || typeof levelValue !== "object" || Array.isArray(levelValue)) return null;

  const candidate = levelValue as Record<string, unknown>;
  if (Object.keys(candidate).length !== LEVELS.length || !LEVELS.every((level) => {
    const floor = candidate[level];
    return typeof floor === "number" && Number.isInteger(floor) && floor >= 1 && floor <= 100;
  })) return null;

  const levelFloors = candidate as Record<MatchLevel, number>;
  if (levelFloors.Emerging > levelFloors.Competent || levelFloors.Competent > levelFloors.Proficient ||
    levelFloors.Proficient > levelFloors.Advanced) return null;
  return { coverageFloor: coverageValue, levelFloors };
}
