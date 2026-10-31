import { assertEquals } from "@std/assert";
import { extractJobSkills } from "./job-description.ts";

Deno.test("JD extraction matches taxonomy entries without substring false positives", () => {
  const result = extractJobSkills("Senior React developer. The role also uses TypeScript and UX testing.", [
    { slug: "react", name: "React" },
    { slug: "typescript", name: "TypeScript" },
    { slug: "testing", name: "Testing" },
    { slug: "go", name: "Go" },
  ]);
  assertEquals(result.title_suggestion, "Senior React developer. The role also uses TypeScript and UX testing.");
  assertEquals(result.skills.map((skill) => skill.skill_slug), ["react", "typescript", "testing"]);
  assertEquals(result.skills.every((skill) => skill.min_level === "Advanced"), true);
  assertEquals(result.skills.every((skill) => skill.weight === 0.333333), true);
});

Deno.test("JD extraction returns empty skills and bounded title for unmatched text", () => {
  const result = extractJobSkills("Position: A very specialized role with no taxonomy match.", []);
  assertEquals(result.title_suggestion, "A very specialized role with no taxonomy match.");
  assertEquals(result.skills, []);
});
