import { z } from "npm:zod@3.23.8";

export const AuditSubmissionInputSchema = z.object({ run_id: z.string().uuid() }).strict();
export const AuditSubmissionOutputSchema = z.object({ run_id: z.string().uuid(), status: z.literal("running") }).strict();
