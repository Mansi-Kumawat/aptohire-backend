import { assertEquals, assertNotEquals } from "@std/assert";
import { chooseDiverseTemplate, projectBriefSimilarity } from "./project-similarity.ts";

const recentBrief = {
  title: "Build a React dashboard",
  scenario: "Create a dashboard for a fictional community library with searchable book lists.",
  deliverables: ["React source code", "Tests"],
};

Deno.test("brief similarity is bounded and recognizes overlapping wording", () => {
  assertEquals(projectBriefSimilarity(recentBrief, recentBrief), 1);
  assertEquals(projectBriefSimilarity(recentBrief, { title: "Build a React dashboard", scenario: "Create a dashboard for a fictional community library with searchable book lists.", deliverables: ["React source code", "Tests"] }), 1);
  assertEquals(projectBriefSimilarity(recentBrief, { title: "Analyze crop yields", scenario: "Compare rainfall and harvest data for a fictional farm.", deliverables: ["Python notebook"] }) < 0.2, true);
  assertEquals(projectBriefSimilarity({}, recentBrief), 0);
});

Deno.test("template selection re-rolls away from similar recent briefs deterministically", () => {
  const candidates = [
    { id: "near-1", brief: { title: "Build a React dashboard", scenario: "Create a dashboard for a fictional community library with searchable book lists.", deliverables: ["React source code", "Tests"] } },
    { id: "near-2", brief: { title: "Build another React dashboard", scenario: "Create a dashboard for a fictional community library with searchable book lists and charts.", deliverables: ["React source code", "Tests"] } },
    { id: "different", brief: { title: "Analyze crop yields", scenario: "Compare rainfall and harvest data for a fictional farm.", deliverables: ["Python notebook"] } },
  ];
  const render = (candidate: typeof candidates[number]) => candidate.brief;
  const initial = candidates.find((candidate) => candidate.id === "near-1")!;
  let seed = "";
  for (let i = 0; i < 10_000; i++) {
    const current = `reroll-${i}`;
    if (chooseDiverseTemplate(candidates, new Set(), [], current, render)?.id === initial.id) { seed = current; break; }
  }
  assertNotEquals(seed, "");
  const selected = chooseDiverseTemplate(candidates, new Set(), [recentBrief], seed, render);
  assertEquals(selected?.id, "different");
  assertEquals(chooseDiverseTemplate(candidates, new Set(), [recentBrief], seed, render)?.id, selected?.id);
});

Deno.test("diverse template selection still respects recent-template exclusion", () => {
  const candidates = [{ id: "recent", brief: recentBrief }, { id: "different", brief: { title: "Analyze crop yields", scenario: "Compare rainfall data.", deliverables: ["Notebook"] } }];
  const result = chooseDiverseTemplate(candidates, new Set(["recent"]), [recentBrief], "fixed", (candidate) => candidate.brief);
  assertEquals(result?.id, "different");
  assertEquals(chooseDiverseTemplate(candidates, new Set(["recent", "different"]), [recentBrief], "fixed", (candidate) => candidate.brief), null);
});
