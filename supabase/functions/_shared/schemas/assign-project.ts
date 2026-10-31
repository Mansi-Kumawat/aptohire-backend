import { z } from "npm:zod@3.23.8";

export const AssignProjectInputSchema = z.object({
  target: z.union([
    z.object({ skill_slug: z.string().trim().min(1).max(80).regex(/^[a-z0-9-]+$/i) }).strict(),
    z.object({ role_text: z.string().trim().min(2).max(120) }).strict(),
  ]),
  level: z.enum(["Competent", "Proficient", "Advanced"]).optional(),
}).strict();

export const ProjectBriefSchema = z.object({
  title: z.string().trim().min(1).max(120),
  scenario: z.string().trim().min(1).max(700),
  level: z.enum(["Competent", "Proficient", "Advanced"]),
  target_skills: z.array(z.string().min(1).max(80)).max(12),
  deliverables: z.array(z.string().trim().min(1).max(240)).min(1).max(8),
  constraints: z.array(z.string().trim().min(1).max(240)).max(8),
  suggested_stack: z.array(z.string().trim().min(1).max(80)).max(12).optional(),
  estimated_hours: z.number().int().min(1).max(160),
  rubric_preview: z.array(z.object({ criterion: z.string().min(1).max(120), weight: z.number().min(0).max(1) }).strict()).min(1).max(12),
  video_guidance: z.string().trim().min(1).max(700),
  originality_questions: z.array(z.string().trim().min(1).max(300)).min(2).max(3),
}).strict();

export const AssignProjectOutputSchema = z.object({
  assignment_id: z.string().uuid(),
  brief: ProjectBriefSchema,
}).strict();

export type AssignProjectInput = z.infer<typeof AssignProjectInputSchema>;
export type ProjectBrief = z.infer<typeof ProjectBriefSchema>;
