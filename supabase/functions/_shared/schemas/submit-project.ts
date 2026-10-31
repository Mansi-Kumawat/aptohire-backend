import { z } from "npm:zod@3.23.8";

export const SubmitProjectInputSchema = z.object({
  submission_id: z.string().uuid(),
  confirm: z.literal(true),
}).strict();

export const SubmitProjectOutputSchema = z.object({
  run_id: z.string().uuid(),
  status: z.literal("queued"),
  mode: z.enum(["mock", "direct", "n8n"]),
}).strict();

export type SubmitProjectInput = z.infer<typeof SubmitProjectInputSchema>;
export type SubmitProjectOutput = z.infer<typeof SubmitProjectOutputSchema>;
