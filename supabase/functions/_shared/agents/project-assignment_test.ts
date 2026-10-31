import { assertEquals, assertNotEquals } from "@std/assert";
import { buildTemplateBrief, chooseTemplate, nextProjectLevel } from "./project-assignment.ts";

Deno.test("next level advances from baseline and caps at Advanced", () => {
  assertEquals(nextProjectLevel(null), "Competent");
  assertEquals(nextProjectLevel("Emerging"), "Competent");
  assertEquals(nextProjectLevel("Competent"), "Proficient");
  assertEquals(nextProjectLevel("Proficient"), "Advanced");
  assertEquals(nextProjectLevel("Advanced"), "Advanced");
});

Deno.test("template choice is deterministic and excludes recent templates", () => {
  const templates = [{ id: "one" }, { id: "two" }, { id: "three" }];
  const recent = new Set(["one", "two"]);
  assertEquals(chooseTemplate(templates, recent, "fixed-seed")?.id, "three");
  assertEquals(chooseTemplate(templates, new Set(templates.map((row) => row.id)), "fixed-seed"), null);
  assertEquals(chooseTemplate(templates, new Set(), "fixed-seed")?.id, chooseTemplate(templates, new Set(), "fixed-seed")?.id);
});

Deno.test("template content becomes a strict, schema-checked student brief", () => {
  const brief = buildTemplateBrief({
    id: "template-id", skill_id: "skill-id", level: "Competent", title: "Accessible dashboard",
    brief: { objective: "Build a dashboard for a fictional library.", deliverables: ["Source", "Tests"] },
  }, ["react"], "Competent");
  assertEquals(brief.scenario, "Build a dashboard for a fictional library.");
  assertEquals(brief.deliverables, ["Source", "Tests"]);
  assertEquals(brief.target_skills, ["react"]);
  assertEquals(brief.originality_questions.length, 3);
  assertNotEquals(brief.title, "");
});
