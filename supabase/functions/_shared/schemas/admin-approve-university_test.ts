import { assertEquals, assertFalse } from "jsr:@std/assert@1";
import { AdminApproveUniversityInputSchema, AdminApproveUniversityOutputSchema } from "./admin-approve-university.ts";

const universityId = "ab000000-0000-4000-8000-000000000001";
Deno.test("university approval contract accepts bounded decisions and count-only output", () => {
  assertEquals(AdminApproveUniversityInputSchema.safeParse({ university_id: universityId, decision: "approve" }).success, true);
  assertEquals(AdminApproveUniversityInputSchema.safeParse({ university_id: universityId, decision: "reject", note: "Please verify the domain." }).success, true);
  assertEquals(AdminApproveUniversityOutputSchema.safeParse({ university_id: universityId, status: "approved", matched_existing: 2, proposals_created: 1 }).success, true);
});
Deno.test("university approval contract rejects invalid decisions, oversized notes, and identities", () => {
  assertFalse(AdminApproveUniversityInputSchema.safeParse({ university_id: universityId, decision: "pending" }).success);
  assertFalse(AdminApproveUniversityInputSchema.safeParse({ university_id: universityId, decision: "reject", note: "x".repeat(501) }).success);
  assertFalse(AdminApproveUniversityOutputSchema.safeParse({ university_id: universityId, status: "approved", matched_existing: 0, proposals_created: 0, student_ids: [universityId] }).success);
});
