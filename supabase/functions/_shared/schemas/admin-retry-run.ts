import { z } from "npm:zod@3.23.8";
export const AdminRetryRunInputSchema = z.object({ run_id: z.string().uuid() }).strict();
export const AdminRetryRunOutputSchema = z.object({ run_id: z.string().uuid(), status: z.literal("queued"), mode: z.literal("mock") }).strict();
