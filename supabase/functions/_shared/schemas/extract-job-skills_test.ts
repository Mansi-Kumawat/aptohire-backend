import { assertEquals } from "@std/assert";
import { ExtractJobSkillsInputSchema, ExtractJobSkillsOutputSchema } from "./extract-job-skills.ts";

Deno.test("extract-job-skills validates bounded strict request shape", () => {
  assertEquals(ExtractJobSkillsInputSchema.safeParse({ description: "Frontend developer with React and TypeScript." }).success, true);
  assertEquals(ExtractJobSkillsInputSchema.safeParse({ description: "short" }).success, false);
  assertEquals(ExtractJobSkillsInputSchema.safeParse({ description: "A sufficiently long job description for testing.", extra: true }).success, false);
});

Deno.test("extract-job-skills validates taxonomy output and rejects extra fields", () => {
  const valid = { skills: [{ skill_slug: "react", min_level: "Competent", weight: 1 }], title_suggestion: "Frontend developer" };
  assertEquals(ExtractJobSkillsOutputSchema.safeParse(valid).success, true);
  assertEquals(ExtractJobSkillsOutputSchema.safeParse({ skills: [{ ...valid.skills[0], min_level: "expert" }] }).success, false);
  assertEquals(ExtractJobSkillsOutputSchema.safeParse({ ...valid, hidden: "not allowed" }).success, false);
});
