import { z } from "zod";
import { ScopeSchema } from "./common.ts";

export const RespondAccessInputSchema = z.object({
  request_id: z.string().uuid(),
  decision: z.enum(["accept", "decline"]),
  granted_scope: z.array(ScopeSchema).min(1).max(4).optional(),
  duration_days: z.union([z.literal(7), z.literal(30), z.literal(90)]).optional(),
}).strict().superRefine((value, ctx) => {
  if (value.decision === "accept" && !value.granted_scope?.length) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["granted_scope"], message: "Accepting requires at least one granted scope" });
  }
  if (value.granted_scope && new Set(value.granted_scope).size !== value.granted_scope.length) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["granted_scope"], message: "Granted scopes must be unique" });
  }
  if (value.decision === "decline" && (value.granted_scope !== undefined || value.duration_days !== undefined)) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["decision"], message: "Declining cannot include grant fields" });
  }
});

export const RespondAccessOutputSchema = z.discriminatedUnion("status", [
  z.object({ status: z.literal("accepted"), expires_at: z.string().datetime() }).strict(),
  z.object({ status: z.literal("declined") }).strict(),
]);
