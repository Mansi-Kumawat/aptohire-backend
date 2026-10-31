import { z } from "zod";
export const AdminRetryRunInputSchema = z.object({ run_id: z.string().uuid() }).strict();
export const AdminRetryRunOutputSchema = z.object({ run_id: z.string().uuid(), status: z.literal("queued"), mode: z.literal("mock") }).strict();
