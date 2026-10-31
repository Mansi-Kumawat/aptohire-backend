import { z } from "npm:zod@3.23.8";

export const AdminApproveUniversityInputSchema = z.object({
  university_id: z.string().uuid(),
  decision: z.enum(["approve", "reject"]),
  note: z.string().trim().max(500).optional(),
}).strict();
export const AdminApproveUniversityOutputSchema = z.object({
  university_id: z.string().uuid(),
  status: z.enum(["approved", "rejected"]),
  matched_existing: z.number().int().nonnegative(),
  proposals_created: z.number().int().nonnegative(),
}).strict();
