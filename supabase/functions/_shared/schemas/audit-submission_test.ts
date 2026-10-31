import { assertEquals } from "@std/assert";
import { AuditSubmissionInputSchema, AuditSubmissionOutputSchema } from "./audit-submission.ts";

Deno.test("internal audit submission request is strict and requires a UUID", () => {
  assertEquals(AuditSubmissionInputSchema.safeParse({ run_id: "00000000-0000-4000-8000-000000000001" }).success, true);
  assertEquals(AuditSubmissionInputSchema.safeParse({ run_id: "bad" }).success, false);
  assertEquals(AuditSubmissionInputSchema.safeParse({ run_id: "00000000-0000-4000-8000-000000000001", submission_id: "spoofed" }).success, false);
  assertEquals(AuditSubmissionOutputSchema.safeParse({ run_id: "00000000-0000-4000-8000-000000000001", status: "running" }).success, true);
});
