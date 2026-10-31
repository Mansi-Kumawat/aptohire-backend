import { assertEquals } from "@std/assert";
import { scoreMatchRequirements, type MatchRequirement } from "./match-scoring.ts";

const requirements: MatchRequirement[] = [
  { skill_id: "skill-react", weight: 2, min_level: "Proficient" },
  { skill_id: "skill-sql", weight: 1, min_level: "Competent" },
];
const floors = { Emerging: 1, Competent: 55, Proficient: 75, Advanced: 90 };

Deno.test("weighted requirement score caps above-threshold evidence and calculates coverage deterministically", () => {
  const result = scoreMatchRequirements(requirements, [
    { skill_id: "skill-react", score: 90, level: "Advanced", name: "React" },
    { skill_id: "skill-sql", score: 55, level: "Competent", name: "SQL" },
  ], floors, 0.8);
  assertEquals(result.coverage, 1);
  assertEquals(result.structuredScore, 100);
  assertEquals(result.meetsCoverageFloor, true);
  assertEquals(result.reasons, ["Verified React — Advanced (90)", "Verified SQL — Competent (55)"]);
  assertEquals(result.gaps, []);
});

Deno.test("partial and missing evidence yield weighted coverage and catalog-named gaps", () => {
  const result = scoreMatchRequirements(requirements, [
    { skill_id: "skill-react", score: 30, level: "Emerging", name: "React" },
  ], floors, 0.5, new Map([["skill-sql", "SQL"]]));
  assertEquals(Math.round(result.coverage * 10000) / 10000, 0.2667);
  assertEquals(result.meetsCoverageFloor, false);
  assertEquals(result.reasons, ["Verified React — Emerging (30)"]);
  assertEquals(result.gaps, ["Below requested Proficient in React", "No verified evidence for required skill SQL"]);
});

Deno.test("empty evidence never qualifies, and reasons and gaps are bounded to three", () => {
  assertEquals(scoreMatchRequirements(requirements, [], floors, 0).meetsCoverageFloor, false);
  const many = Array.from({ length: 5 }, (_, index): MatchRequirement => ({
    skill_id: `skill-${index}`, weight: 1, min_level: "Competent",
  }));
  const evidence = many.map((item) => ({ skill_id: item.skill_id, score: 60, level: "Competent", name: item.skill_id }));
  const result = scoreMatchRequirements(many, evidence, floors, 0.5);
  assertEquals(result.reasons.length, 3);
  assertEquals(result.gaps.length, 0);
});
