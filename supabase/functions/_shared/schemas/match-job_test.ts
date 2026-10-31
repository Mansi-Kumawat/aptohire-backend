import { assertEquals, assertFalse } from "@std/assert";
import { MatchJobInputSchema, MatchJobOutputSchema, RequiredJobSkillsSchema } from "./match-job.ts";

Deno.test("match-job input and output are strict and bounded", () => {
  assertEquals(MatchJobInputSchema.safeParse({ job_id: "8a7db498-3b8c-4e77-97d7-89f4c5afef69" }).success, true);
  assertFalse(MatchJobInputSchema.safeParse({ job_id: "not-a-uuid", org_id: "x" }).success);
  assertEquals(MatchJobOutputSchema.safeParse({ status: "ready", candidate_count: 0 }).success, true);
  assertEquals(MatchJobOutputSchema.safeParse({ status: "running", candidate_count: 3 }).success, true);
  assertFalse(MatchJobOutputSchema.safeParse({ status: "ready", candidate_count: -1 }).success);
  assertFalse(MatchJobOutputSchema.safeParse({ status: "ready", candidate_count: 1, student_id: "private" }).success);
});

Deno.test("required skill contract rejects duplicates, extra fields, and invalid weights", () => {
  const skill = { skill_id: "8a7db498-3b8c-4e77-97d7-89f4c5afef69", weight: 2, min_level: "Proficient" };
  assertEquals(RequiredJobSkillsSchema.safeParse([skill]).success, true);
  assertFalse(RequiredJobSkillsSchema.safeParse([skill, skill]).success);
  assertFalse(RequiredJobSkillsSchema.safeParse([{ ...skill, weight: 0 }]).success);
  assertFalse(RequiredJobSkillsSchema.safeParse([{ ...skill, student_name: "private" }]).success);
});
