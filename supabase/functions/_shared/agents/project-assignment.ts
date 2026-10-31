import { ProjectBriefSchema, type ProjectBrief } from "../schemas/assign-project.ts";

export interface AssignmentTemplate {
  id: string;
  skill_id: string | null;
  level: string;
  title: string;
  brief: unknown;
}

const LEVELS = ["Emerging", "Competent", "Proficient", "Advanced"] as const;

export function nextProjectLevel(currentLevel: string | null | undefined): "Competent" | "Proficient" | "Advanced" {
  const normalized = currentLevel && LEVELS.includes(currentLevel as typeof LEVELS[number]) ? currentLevel : "Emerging";
  const index = LEVELS.indexOf(normalized as typeof LEVELS[number]);
  return LEVELS[Math.min(index + 1, LEVELS.length - 1)] as "Competent" | "Proficient" | "Advanced";
}

export function chooseTemplate<T extends { id: string }>(templates: T[], recentTemplateIds: Set<string>, seed: string): T | null {
  const available = templates.filter((template) => !recentTemplateIds.has(template.id));
  if (!available.length) return null;
  let hash = 2166136261;
  for (const char of seed) hash = Math.imul(hash ^ char.charCodeAt(0), 16777619) >>> 0;
  return available[hash % available.length];
}

function objectValue(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function stringList(value: unknown, max: number, itemLength: number): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string").map((item) => item.trim().slice(0, itemLength)).filter(Boolean).slice(0, max);
}

/** Deterministic, schema-checked fallback. Template content is data, not executable instructions. */
export function buildTemplateBrief(template: AssignmentTemplate, targetSkills: string[], level: "Competent" | "Proficient" | "Advanced"): ProjectBrief {
  const source = objectValue(template.brief);
  const sourceTitle = typeof source.title === "string" ? source.title.trim() : template.title.trim();
  const title = sourceTitle || "Practical skill project";
  const sourceScenario = typeof source.scenario === "string" ? source.scenario : typeof source.objective === "string" ? source.objective : "";
  const scenario = sourceScenario.trim() || `Build a practical ${targetSkills[0] ?? "role-focused"} project for a fictional community service. Demonstrate the requested target with clear, testable behavior.`;
  const deliverables = stringList(source.deliverables, 8, 240);
  const constraints = stringList(source.constraints, 8, 240);
  const suggestedStack = stringList(source.suggested_stack, 12, 80);
  const rubricValue = Array.isArray(source.rubric_preview) ? source.rubric_preview : [
    { criterion: "Functionality", weight: 0.35 },
    { criterion: "Quality and accessibility", weight: 0.25 },
    { criterion: "Testing and evidence", weight: 0.25 },
    { criterion: "Documentation and reflection", weight: 0.15 },
  ];
  const rawRubric = rubricValue.filter((item): item is { criterion: string; weight: number } => {
    const row = objectValue(item);
    return typeof row.criterion === "string" && typeof row.weight === "number";
  }).map((row) => ({ criterion: row.criterion.trim().slice(0, 120), weight: Math.max(0, row.weight) })).slice(0, 12);
  const rubricTotal = rawRubric.reduce((sum, row) => sum + row.weight, 0);
  const rubric = rawRubric.length && rubricTotal > 0
    ? rawRubric.map((row) => ({ ...row, weight: row.weight / rubricTotal }))
    : [];
  const questions = stringList(source.originality_questions, 3, 300);
  return ProjectBriefSchema.parse({
    title: title.slice(0, 120),
    scenario: scenario.slice(0, 700),
    level,
    target_skills: targetSkills,
    deliverables: deliverables.length ? deliverables : ["Working source code", "A short test suite", "A README explaining key decisions"],
    constraints,
    ...(suggestedStack.length ? { suggested_stack: suggestedStack } : {}),
    estimated_hours: typeof source.estimated_hours === "number" ? Math.max(1, Math.min(160, Math.round(source.estimated_hours))) : 8,
    rubric_preview: rubric.length ? rubric : [{ criterion: "Functionality", weight: 1 }],
    video_guidance: (typeof source.video_guidance === "string" && source.video_guidance.trim() ? source.video_guidance.trim() : "In a short demo, show the project working, explain one important design choice, and walk through one test.").slice(0, 700),
    originality_questions: questions.length >= 2 ? questions : [
      "Which part did you design or implement yourself, and why?",
      "What was one difficult bug or trade-off, and how did you resolve it?",
      "If you had another day, what would you improve first?",
    ],
  });
}
