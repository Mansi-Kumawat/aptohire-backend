import { assertEquals } from "jsr:@std/assert@1";
import {
  resolveDetectOutcome,
  resolveExistingAffiliationOutcome,
  resolveStudentIdOutcome,
  resolveUnregisteredOutcome,
} from "./register-outcome.ts";

Deno.test("student registration maps the six frozen outcomes without leaking roster-match distinctions", () => {
  assertEquals(resolveDetectOutcome(false, 0, 0), "needs_student_id");
  assertEquals(resolveDetectOutcome(true, 1, 1), "verified_roster");
  assertEquals(resolveDetectOutcome(true, 1, 0), "roster_no_match");
  assertEquals(resolveDetectOutcome(true, 1, 2), "roster_no_match");
  assertEquals(resolveStudentIdOutcome(true, true), "verified_student_id");
  assertEquals(resolveStudentIdOutcome(true, false), "roster_no_match");
  assertEquals(resolveStudentIdOutcome(false, false), "roster_no_match");
  assertEquals(resolveUnregisteredOutcome(), "unverified");
  assertEquals(resolveExistingAffiliationOutcome("verified_student_id", true), "confirm_existing");
  assertEquals(resolveExistingAffiliationOutcome("roster_no_match", true), "roster_no_match");
});

Deno.test("ambiguous email-domain ownership never verifies a roster automatically", () => {
  assertEquals(resolveDetectOutcome(true, 0, 1), "needs_student_id");
  assertEquals(resolveDetectOutcome(true, 2, 1), "needs_student_id");
});
