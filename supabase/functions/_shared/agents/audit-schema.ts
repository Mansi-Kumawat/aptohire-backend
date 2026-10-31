import { z } from "npm:zod@3.23.8";

export const CriterionSchema = z.object({
  key: z.enum(["functionality", "quality", "ui_accessibility", "testing", "documentation", "problem_solving", "communication"]),
  score: z.number().min(0).max(100),
  confidence: z.number().min(0).max(1),
  rationale: z.string().max(1000),
  insufficient_evidence: z.boolean().default(false),
  evidence: z.array(z.object({ evidence_ref: z.string().min(1).max(160), excerpt: z.string().max(1200).optional() }).strict()).max(8),
}).strict();

export const AuditOutputSchema = z.object({
  rubric_version: z.literal("web-frontend@1"),
  prompt_version: z.string().min(1).max(80),
  overall_score: z.number().min(0).max(100),
  confidence: z.number().min(0).max(1),
  summary: z.string().max(1200),
  criteria: z.array(CriterionSchema).length(7).superRefine((criteria, context) => {
    const seen = new Set<string>();
    criteria.forEach((criterion, index) => {
      if (seen.has(criterion.key)) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          message: `Duplicate rubric criterion: ${criterion.key}`,
          path: [index, "key"],
        });
      }
      seen.add(criterion.key);
    });
  }),
  transcript: z.array(z.object({ start_seconds: z.number().min(0), text: z.string().max(1200) }).strict()).max(200),
  visual_observations: z.array(z.string().max(500)).max(30),
  next_steps: z.array(z.string().max(500)).max(3),
  prompt_injection_attempt: z.boolean().default(false),
  borderline: z.boolean().optional(),
}).strict();

export type AuditOutput = z.infer<typeof AuditOutputSchema>;
