import { assertEquals } from "@std/assert";
import { ConfirmAffiliationInputSchema, ConfirmAffiliationOutputSchema } from "./confirm-affiliation.ts";

Deno.test("confirm-affiliation accepts proposals and new unverified affiliations", () => {
  assertEquals(ConfirmAffiliationInputSchema.safeParse({
    kind: "proposal", proposal_id: "00000000-0000-4000-8000-000000000001",
  }).success, true);
  assertEquals(ConfirmAffiliationInputSchema.safeParse({
    kind: "new", new: { university_name_text: "Fictional Institute", program_level: "ug", year: 2 },
  }).success, true);
});

Deno.test("confirm-affiliation requires a university and restricts student-ID checks", () => {
  assertEquals(ConfirmAffiliationInputSchema.safeParse({
    kind: "new", new: { program_level: "ug" },
  }).success, false);
  assertEquals(ConfirmAffiliationInputSchema.safeParse({
    kind: "new", new: { university_name_text: "Fictional Institute", student_id_number: "X-1", program_level: "ug" },
  }).success, false);
  assertEquals(ConfirmAffiliationInputSchema.safeParse({
    kind: "new", new: { university_id: "00000000-0000-4000-8000-000000000002", student_id_number: "X-1", program_level: "ug", year: 0 },
  }).success, false);
  assertEquals(ConfirmAffiliationInputSchema.safeParse({
    kind: "new", new: { university_id: "00000000-0000-4000-8000-000000000002", student_id_number: "- -", program_level: "ug" },
  }).success, false);
});

Deno.test("confirm-affiliation response has only the specified affiliation fields", () => {
  const result = { affiliation: {
    id: "00000000-0000-4000-8000-000000000003",
    university_id: "00000000-0000-4000-8000-000000000002",
    university_name_text: null,
    verification: "student_id",
    program_level: "ug",
    year: 2,
    status: "enrolled",
    is_current: true,
  } };
  assertEquals(ConfirmAffiliationOutputSchema.safeParse(result).success, true);
  assertEquals(ConfirmAffiliationOutputSchema.safeParse({ affiliation: { ...result.affiliation, email: "private@example.test" } }).success, false);
});
