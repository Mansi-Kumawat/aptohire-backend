import { z } from "npm:zod@3.23.8";

const NoteSchema = z.string().trim().min(1).max(500);
const AdjustedScoresSchema = z.array(z.object({ skill_id: z.string().uuid(), score: z.number().min(0).max(100) }).strict())
  .min(1).max(30).superRefine((items, context) => {
    const seen = new Set<string>();
    items.forEach((item, index) => {
      if (seen.has(item.skill_id)) context.addIssue({ code: "custom", path: [index, "skill_id"], message: "Duplicate skill" });
      seen.add(item.skill_id);
    });
  });

export const AdminReviewAuditInputSchema = z.discriminatedUnion("decision", [
  z.object({ audit_id: z.string().uuid(), decision: z.literal("confirm"), note: NoteSchema }).strict(),
  z.object({ audit_id: z.string().uuid(), decision: z.literal("adjust"), adjusted_scores: AdjustedScoresSchema, note: NoteSchema }).strict(),
]);
export const AdminReviewAuditOutputSchema = z.object({
  audit_id: z.string().uuid(),
  review_status: z.literal("complete"),
  reviewed_score: z.number().min(0).max(100),
}).strict();
