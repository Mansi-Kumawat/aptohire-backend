import { assertEquals } from "@std/assert";
import { RosterImportInputSchema, RosterImportOutputSchema, CsvRosterRowSchema } from "./roster-import.ts";
import { isDuplicateRosterIdentity, isSafeRosterCsvPath, rosterStorageObjectSize } from "../roster-utils.ts";

Deno.test("roster-import accepts inline rows and dry-run CSV paths", () => {
  assertEquals(RosterImportInputSchema.safeParse({
    university_id: "00000000-0000-4000-8000-000000000001",
    source: { rows: [{ full_name: "Fictional Student", email: "learner@example.test", program_level: "ug", status: "enrolled", year: 2 }] },
  }).success, true);
  assertEquals(RosterImportInputSchema.safeParse({
    university_id: "00000000-0000-4000-8000-000000000001",
    source: { csv_path: "00000000-0000-4000-8000-000000000001/roster.csv" },
    dry_run: true,
  }).success, true);
});

Deno.test("roster-import rejects unsafe paths, unknown fields, and oversized batches", () => {
  const base = { university_id: "00000000-0000-4000-8000-000000000001" };
  assertEquals(RosterImportInputSchema.safeParse({ ...base, source: { csv_path: "../roster.csv" } }).success, false);
  assertEquals(RosterImportInputSchema.safeParse({ ...base, source: { rows: [] } }).success, false);
  assertEquals(RosterImportInputSchema.safeParse({ ...base, source: { rows: [{ full_name: "Fictional", program_level: "ug", status: "enrolled" }] }, mapping: { full_name: "Student" } }).success, false);
  assertEquals(RosterImportInputSchema.safeParse({ ...base, source: { rows: Array.from({ length: 501 }, () => ({})) } }).success, false);
  assertEquals(CsvRosterRowSchema.safeParse({ full_name: "Fictional", student_id_number: "S-001", email: "", program_level: "ug", status: "incoming" }).success, true);
  assertEquals(CsvRosterRowSchema.safeParse({ full_name: "Fictional", student_id_number: "", email: "", program_level: "pg", status: "alumni", year: "" }).success, true);
  assertEquals(CsvRosterRowSchema.parse({ full_name: "Fictional", program_level: "ug", status: "incoming", year: "2" }).year, 2);
  assertEquals(CsvRosterRowSchema.safeParse({ full_name: "Fictional", program_level: "ug", status: "incoming", year: "11" }).success, false);
});

Deno.test("roster-import output keeps match fields counts-only", () => {
  const result = {
    total: 1, valid: 1, invalid: [], duplicates: 0, created: 1, updated: 0,
    matched_existing: 0, proposals_created: 0,
  };
  assertEquals(RosterImportOutputSchema.safeParse(result).success, true);
  assertEquals(RosterImportOutputSchema.safeParse({ ...result, matched_existing: [{ id: "student" }] }).success, false);
});


Deno.test("roster import enforces frozen lifecycle and program-level values", () => {
  const base = { full_name: "Fictional Learner", program_level: "ug", status: "enrolled" };
  assertEquals(CsvRosterRowSchema.safeParse(base).success, true);
  assertEquals(CsvRosterRowSchema.safeParse({ ...base, program_level: "Bachelors" }).success, false);
  assertEquals(CsvRosterRowSchema.safeParse({ ...base, status: "student" }).success, false);
  assertEquals(CsvRosterRowSchema.safeParse({ full_name: "Fictional Learner", program_level: "ug" }).success, false);
});

Deno.test("roster storage paths are confined and canonical under the university folder", () => {
  const universityId = "00000000-0000-4000-8000-000000000001";
  assertEquals(isSafeRosterCsvPath(`${universityId}/roster.csv`, universityId), true);
  assertEquals(isSafeRosterCsvPath(`${universityId}/2026/roster-01.csv`, universityId), true);
  assertEquals(isSafeRosterCsvPath(`${universityId}/../other/roster.csv`, universityId), false);
  assertEquals(isSafeRosterCsvPath(`${universityId}//roster.csv`, universityId), false);
  assertEquals(isSafeRosterCsvPath(`${universityId}\\roster.csv`, universityId), false);
  assertEquals(isSafeRosterCsvPath(`${universityId}/roster${String.fromCharCode(0)}.csv`, universityId), false);
  assertEquals(isSafeRosterCsvPath("00000000-0000-4000-8000-000000000002/roster.csv", universityId), false);
});

Deno.test("roster duplicate detection checks both normalized email and ID hash", () => {
  const seen = new Set<string>();
  assertEquals(isDuplicateRosterIdentity(seen, " Learner@Example.test ", "hash-a"), false);
  assertEquals(isDuplicateRosterIdentity(seen, "learner@example.test", "hash-b"), true);
  assertEquals(isDuplicateRosterIdentity(seen, "other@example.test", "hash-a"), true);
  assertEquals(isDuplicateRosterIdentity(seen, "fresh@example.test", "hash-c"), false);
});

Deno.test("roster import reads safe storage metadata sizes before downloading", () => {
  assertEquals(rosterStorageObjectSize({ size: 1024 }), 1024);
  assertEquals(rosterStorageObjectSize({ size: "2048" }), 2048);
  assertEquals(rosterStorageObjectSize({ size: -1 }), undefined);
  assertEquals(rosterStorageObjectSize({ size: "not-a-size" }), undefined);
  assertEquals(rosterStorageObjectSize(null), undefined);
});
