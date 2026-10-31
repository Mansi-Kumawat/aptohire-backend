import { assertEquals, assertFalse } from "jsr:@std/assert@1";
import { AdminApproveOrgInputSchema, AdminApproveOrgOutputSchema, AdminSetSubscriptionInputSchema, AdminSetSubscriptionOutputSchema } from "./admin-approve-org.ts";

const organizationId = "ab000000-0000-4000-8000-000000000001";
Deno.test("organization admin actions use strict bounded contracts", () => {
  assertEquals(AdminApproveOrgInputSchema.safeParse({ organization_id: organizationId, decision: "approve" }).success, true);
  assertEquals(AdminApproveOrgInputSchema.safeParse({ organization_id: organizationId, decision: "reject", note: "Please correct the website details." }).success, true);
  assertEquals(AdminApproveOrgOutputSchema.safeParse({ organization_id: organizationId, status: "approved" }).success, true);
  assertEquals(AdminSetSubscriptionInputSchema.safeParse({ organization_id: organizationId, status: "inactive" }).success, true);
  assertEquals(AdminSetSubscriptionOutputSchema.safeParse({ organization_id: organizationId, subscription_status: "active" }).success, true);
});
Deno.test("organization admin action contracts reject invalid values and extra fields", () => {
  assertFalse(AdminApproveOrgInputSchema.safeParse({ organization_id: organizationId, decision: "pending" }).success);
  assertFalse(AdminApproveOrgInputSchema.safeParse({ organization_id: organizationId, decision: "reject", note: "x".repeat(501) }).success);
  assertFalse(AdminSetSubscriptionInputSchema.safeParse({ organization_id: organizationId, status: "trial" }).success);
  assertFalse(AdminApproveOrgInputSchema.safeParse({ organization_id: organizationId, decision: "approve", actor_id: organizationId }).success);
});
