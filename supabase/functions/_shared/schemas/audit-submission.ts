import { z } from "zod";

export const AuditSubmissionInputSchema = z.object({ run_id: z.string().uuid() }).strict();
export const AuditSubmissionOutputSchema = z.object({ run_id: z.string().uuid(), status: z.literal("running") }).strict();
