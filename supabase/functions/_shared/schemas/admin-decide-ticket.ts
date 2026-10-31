import { z } from "npm:zod@3.23.8";

const TicketId = z.string().uuid();
const AdjustedScores = z.array(z.object({ skill_id: z.string().uuid(), score: z.number().min(0).max(100) }).strict()).min(1).max(30)
  .superRefine((scores, context) => {
    const seen = new Set<string>();
    scores.forEach((score, index) => {
      if (seen.has(score.skill_id)) context.addIssue({ code: "custom", path: [index, "skill_id"], message: "Duplicate skill" });
      seen.add(score.skill_id);
    });
  });
const DecideSchema = z.object({
  action: z.literal("decide"), ticket_id: TicketId,
  decision: z.enum(["upheld", "overturned", "adjusted"]),
  assigned_to: z.never().optional(),
  criterion: z.string().trim().min(1).max(100).regex(/^[A-Za-z0-9 _.-]+$/).optional(),
  note: z.string().trim().max(500).optional(),
  adjusted_scores: AdjustedScores.optional(),
}).strict();

export const AdminDecideTicketInputSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("ack"), ticket_id: TicketId }).strict(),
  z.object({ action: z.literal("assign"), ticket_id: TicketId, assigned_to: z.string().uuid() }).strict(),
  DecideSchema,
]).superRefine((input, context) => {
  if (input.action !== "decide") return;
  if (input.decision === "adjusted" && !input.adjusted_scores) context.addIssue({ code: "custom", path: ["adjusted_scores"], message: "Adjusted scores are required" });
  if (input.decision !== "adjusted" && input.adjusted_scores !== undefined) context.addIssue({ code: "custom", path: ["adjusted_scores"], message: "Scores are only accepted for adjusted decisions" });
});
export const AdminDecideTicketOutputSchema = z.object({
  ticket_id: TicketId,
  status: z.enum(["assigned", "closed"]),
  decision: z.enum(["upheld", "overturned", "adjusted"]).optional(),
}).strict();
