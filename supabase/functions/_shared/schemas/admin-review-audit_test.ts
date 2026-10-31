import { assertEquals, assertFalse } from "jsr:@std/assert@1";
import { AdminReviewAuditInputSchema, AdminReviewAuditOutputSchema } from "./admin-review-audit.ts";

const auditId = "ae000000-0000-4000-8000-000000000001";
const skillId = "ae000000-0000-4000-8000-000000000002";
Deno.test("admin audit review schema accepts confirm and bounded adjustments", () => {
  assertEquals(AdminReviewAuditInputSchema.safeParse({ audit_id: auditId, decision: "confirm", note: "Reviewed against the evidence." }).success, true);
  assertEquals(AdminReviewAuditInputSchema.safeParse({ audit_id: auditId, decision: "adjust", adjusted_scores: [{ skill_id: skillId, score: 72 }], note: "Adjusted for the demonstrated tests." }).success, true);
  assertEquals(AdminReviewAuditOutputSchema.safeParse({ audit_id: auditId, review_status: "complete", reviewed_score: 72 }).success, true);
});
Deno.test("admin audit review schema rejects malformed or identity-bearing input/output", () => {
  assertFalse(AdminReviewAuditInputSchema.safeParse({ audit_id: auditId, decision: "confirm", note: "" }).success);
  assertFalse(AdminReviewAuditInputSchema.safeParse({ audit_id: auditId, decision: "adjust", adjusted_scores: [{ skill_id: skillId, score: 101 }], note: "review" }).success);
  assertFalse(AdminReviewAuditInputSchema.safeParse({ audit_id: auditId, decision: "adjust", adjusted_scores: [{ skill_id: skillId, score: 70 }, { skill_id: skillId, score: 80 }], note: "review" }).success);
  assertFalse(AdminReviewAuditOutputSchema.safeParse({ audit_id: auditId, review_status: "complete", reviewed_score: 72, student_id: skillId }).success);
});
