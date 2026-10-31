import { z } from "npm:zod@3.23.8";

export const AdminApproveOrgInputSchema = z.object({
  organization_id: z.string().uuid(),
  decision: z.enum(["approve", "reject"]),
  note: z.string().trim().max(500).optional(),
}).strict();
export const AdminApproveOrgOutputSchema = z.object({
  organization_id: z.string().uuid(),
  status: z.enum(["approved", "rejected"]),
}).strict();

export const AdminSetSubscriptionInputSchema = z.object({
  organization_id: z.string().uuid(),
  status: z.enum(["active", "inactive"]),
}).strict();
export const AdminSetSubscriptionOutputSchema = z.object({
  organization_id: z.string().uuid(),
  subscription_status: z.enum(["active", "inactive"]),
}).strict();
