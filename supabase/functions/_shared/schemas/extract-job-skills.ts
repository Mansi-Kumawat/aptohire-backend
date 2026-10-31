import { z } from "npm:zod@3.23.8";

export const ExtractJobSkillsInputSchema = z.object({
  description: z.string().trim().min(20).max(8000),
}).strict();

export const ExtractJobSkillsOutputSchema = z.object({
  skills: z.array(z.object({
    skill_slug: z.string().min(1).max(80),
    min_level: z.enum(["Competent", "Proficient", "Advanced"]),
    weight: z.number().positive().max(1),
  }).strict()).max(30),
  title_suggestion: z.string().min(1).max(120).optional(),
}).strict();

export type ExtractedSkill = z.infer<typeof ExtractJobSkillsOutputSchema>["skills"][number];
