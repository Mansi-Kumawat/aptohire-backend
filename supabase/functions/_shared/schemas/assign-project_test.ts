import { assertEquals } from "jsr:@std/assert@1";
import { AssignProjectInputSchema, AssignProjectOutputSchema, ProjectBriefSchema } from "./assign-project.ts";

Deno.test("assign-project accepts only the two documented target variants", () => {
  assertEquals(AssignProjectInputSchema.safeParse({ target: { skill_slug: "react" } }).success, true);
  assertEquals(AssignProjectInputSchema.safeParse({ target: { role_text: "Frontend developer" }, level: "Proficient" }).success, true);
  assertEquals(AssignProjectInputSchema.safeParse({ target: { skill_slug: "react", role_text: "developer" } }).success, false);
  assertEquals(AssignProjectInputSchema.safeParse({ target: { skill_slug: "../react" } }).success, false);
  assertEquals(AssignProjectInputSchema.safeParse({ target: { skill_slug: "react" }, extra: true }).success, false);
});

Deno.test("project brief bounds reject unsafe or malformed output", () => {
  const valid = {
    title: "Accessible dashboard", scenario: "Build a fictional dashboard.", level: "Competent", target_skills: ["react"],
    deliverables: ["Source", "Tests"], constraints: [], estimated_hours: 8,
    rubric_preview: [{ criterion: "Functionality", weight: 1 }], video_guidance: "Show one workflow and a test.",
    originality_questions: ["What did you build?", "What was difficult?"],
  };
  assertEquals(ProjectBriefSchema.safeParse(valid).success, true);
  assertEquals(ProjectBriefSchema.safeParse({ ...valid, scenario: "x".repeat(701) }).success, false);
  assertEquals(ProjectBriefSchema.safeParse({ ...valid, secret: "not allowed" }).success, false);
  assertEquals(AssignProjectOutputSchema.safeParse({ assignment_id: "not-a-uuid", brief: valid }).success, false);
});
