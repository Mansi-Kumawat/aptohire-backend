import { z } from "npm:zod@3.23.8";

export const MatchJobInputSchema = z.object({ job_id: z.string().uuid() }).strict();
export const MatchJobOutputSchema = z.object({ status: z.enum(["ready", "running"]), candidate_count: z.number().int().nonnegative() }).strict();

export const RequiredJobSkillSchema = z.object({
  skill_id: z.string().uuid(),
  weight: z.number().min(0.01).max(100),
  min_level: z.enum(["Emerging", "Competent", "Proficient", "Advanced"]),
}).strict();
export const RequiredJobSkillsSchema = z.array(RequiredJobSkillSchema).min(1).max(30).superRefine((skills, context) => {
  const seen = new Set<string>();
  skills.forEach((skill, index) => {
    if (seen.has(skill.skill_id)) context.addIssue({ code: "custom", path: [index, "skill_id"], message: "Duplicate required skill" });
    seen.add(skill.skill_id);
  });
});
