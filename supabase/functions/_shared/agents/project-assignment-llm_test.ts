import { assertEquals } from "jsr:@std/assert@1";
import type { ProjectBrief } from "../schemas/assign-project.ts";
import { personalizeTemplateBrief } from "./project-assignment-llm.ts";

Deno.test("direct assignment can change wording only and scrubs contact details", async () => {
  const names = ["LLM_PROVIDER_ORDER", "GEMINI_API_KEY", "LLM_MODEL_FAST"];
  const saved = new Map(names.map((name) => [name, Deno.env.get(name)]));
  try {
    Deno.env.set("LLM_PROVIDER_ORDER", "gemini");
    Deno.env.set("GEMINI_API_KEY", "synthetic-key");
    Deno.env.set("LLM_MODEL_FAST", "synthetic-model");
    const brief: ProjectBrief = {
      title: "Build a data dashboard",
      scenario: "Create a fictional community dashboard.",
      level: "Competent",
      target_skills: ["typescript"],
      deliverables: ["Source code", "Tests"],
      constraints: ["No paid service"],
      suggested_stack: ["TypeScript", "React"],
      estimated_hours: 8,
      rubric_preview: [{ criterion: "Functionality", weight: 1 }],
      video_guidance: "Show the dashboard.",
      originality_questions: ["What did you build?", "What was difficult?"],
    };
    const result = await personalizeTemplateBrief(brief, "typescript", () => Promise.resolve(new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        title: "Build a clear dashboard",
        scenario: "Create an accessible dashboard. Contact owner@example.test for help.",
        video_guidance: "Demonstrate the filters.",
        originality_questions: ["Which chart did you design?", "What would you test next?"],
      }) }] } }],
    }), { status: 200 })));
    assertEquals(result.brief.level, brief.level);
    assertEquals(result.brief.target_skills, brief.target_skills);
    assertEquals(result.brief.deliverables, brief.deliverables);
    assertEquals(result.brief.constraints, brief.constraints);
    assertEquals(result.brief.suggested_stack, brief.suggested_stack);
    assertEquals(result.brief.estimated_hours, brief.estimated_hours);
    assertEquals(result.brief.rubric_preview, brief.rubric_preview);
    assertEquals(result.brief.scenario.includes("owner@example.test"), false);
    assertEquals(result.provider, "gemini");
  } finally {
    for (const [name, value] of saved) value === undefined ? Deno.env.delete(name) : Deno.env.set(name, value);
  }
});
