import { z } from "zod";
import { AuditOutputSchema } from "../agents/audit-schema.ts";

export const AgentCallbackInputSchema = z.object({
  run_id: z.string().uuid(),
  output: AuditOutputSchema,
  evidence_refs: z.array(z.string().min(1).max(160)).max(500),
}).strict();
export const AgentCallbackOutputSchema = z.object({
  run_id: z.string().uuid(),
  audit_id: z.string().uuid(),
  status: z.literal("completed"),
}).strict();
