import { z } from "npm:zod@3.23.8";
import { ScopeSchema } from "./common.ts";

export const RequestAccessInputSchema = z.object({
  match_result_id: z.string().uuid(),
  message: z.string().trim().max(500).optional(),
  requested_scope: z.array(ScopeSchema).min(1).max(4).refine((scopes) => new Set(scopes).size === scopes.length, "Scopes must be unique"),
  duration_days: z.union([z.literal(7), z.literal(30), z.literal(90)]),
}).strict();
export const RequestAccessOutputSchema = z.object({ request_id: z.string().uuid() }).strict();
