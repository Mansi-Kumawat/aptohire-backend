import { assertEquals } from "jsr:@std/assert@1";
import { AdminViewStudentInputSchema, AdminViewStudentOutputSchema } from "./admin-view-student.ts";
Deno.test("admin view student request is strict", () => {
  const id = "00000000-0000-4000-8000-000000000001";
  assertEquals(AdminViewStudentInputSchema.safeParse({ student_id: id }).success, true);
  assertEquals(AdminViewStudentInputSchema.safeParse({ student_id: id, email: "spoof" }).success, false);
});
Deno.test("admin view student output excludes raw storage/token fields", () => {
  const output = { student: { id: "00000000-0000-4000-8000-000000000001", full_name: "Synthetic Student", primary_email: null, headline: null, bio: null, location: null, credential_id: null }, affiliations: [], skill_scores: [], submissions: [] };
  assertEquals(AdminViewStudentOutputSchema.safeParse(output).success, true);
  assertEquals(AdminViewStudentOutputSchema.safeParse({ ...output, video_path: "private/path" }).success, false);
});
