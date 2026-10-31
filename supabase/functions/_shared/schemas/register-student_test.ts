import { assertEquals } from "jsr:@std/assert@1";
import { RegisterStudentInputSchema, RegisterStudentOutputSchema } from "./register-student.ts";

Deno.test("register-student validates each choice variant strictly", () => {
  const common = { full_name: "Demo Student", program_level: "ug", year: 2 };
  assertEquals(RegisterStudentInputSchema.safeParse({ ...common, choice: { kind: "detect" } }).success, true);
  assertEquals(RegisterStudentInputSchema.safeParse({ ...common, choice: { kind: "student_id", university_id: "00000000-0000-4000-8000-000000000001", student_id_number: "B-1042" } }).success, true);
  assertEquals(RegisterStudentInputSchema.safeParse({ ...common, choice: { kind: "student_id", university_id: "00000000-0000-4000-8000-000000000001", student_id_number: "- -" } }).success, false);
  assertEquals(RegisterStudentInputSchema.safeParse({ ...common, choice: { kind: "unregistered", university_name: "Demo Institute" } }).success, true);
  assertEquals(RegisterStudentInputSchema.safeParse({ ...common, choice: { kind: "unregistered", university_name: "Demo Institute", extra: true } }).success, false);
});

Deno.test("register-student output schema accepts all six documented outcomes", () => {
  const id = "00000000-0000-4000-8000-000000000001";
  const affiliation = { university_id: id, label: "Demo Institute", verification: "roster" as const };
  const cases = [
    { student_id: id, outcome: "verified_roster", affiliation, matched_existing_person: true },
    { student_id: id, outcome: "needs_student_id", matched_existing_person: false },
    { student_id: id, outcome: "verified_student_id", affiliation: { ...affiliation, verification: "student_id" as const }, matched_existing_person: false },
    { student_id: id, outcome: "unverified", affiliation: { label: "Demo Institute", verification: "unverified" as const }, matched_existing_person: false },
    { student_id: id, outcome: "confirm_existing", affiliation, matched_existing_person: true },
    { student_id: id, outcome: "roster_no_match", matched_existing_person: false },
  ];
  for (const value of cases) assertEquals(RegisterStudentOutputSchema.safeParse(value).success, true, value.outcome);
});

Deno.test("register-student output schema rejects unknown outcomes and malformed identity", () => {
  const valid = { student_id: "00000000-0000-4000-8000-000000000001", outcome: "unverified", affiliation: { label: "Demo Institute", verification: "unverified" }, matched_existing_person: false };
  assertEquals(RegisterStudentOutputSchema.safeParse({ ...valid, outcome: "matched" }).success, false);
  assertEquals(RegisterStudentOutputSchema.safeParse({ ...valid, student_id: "not-a-uuid" }).success, false);
  assertEquals(RegisterStudentOutputSchema.safeParse({ ...valid, extra: "unexpected" }).success, false);
  assertEquals(RegisterStudentOutputSchema.safeParse({ ...valid, student_id_number: "FICTIONAL-1042" }).success, false);
});
