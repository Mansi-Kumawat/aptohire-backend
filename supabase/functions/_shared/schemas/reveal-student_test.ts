import { assertEquals } from "jsr:@std/assert@1";
import { RevealStudentInputSchema, RevealStudentOutputSchema } from "./reveal-student.ts";

Deno.test("reveal-student contract rejects unknown identity fields", () => {
  const id = "00000000-0000-4000-8000-000000000001";
  assertEquals(RevealStudentInputSchema.safeParse({ request_id: id }).success, true);
  assertEquals(RevealStudentInputSchema.safeParse({ request_id: id, student_id: id }).success, false);
  const base = { request_id: id, granted_scope: ["profile"], expires_at: "2027-01-01T00:00:00.000Z", profile: { full_name: "Aarav A." } };
  assertEquals(RevealStudentOutputSchema.safeParse(base).success, true);
  assertEquals(RevealStudentOutputSchema.safeParse({ ...base, student_id: id }).success, false);
});

Deno.test("reveal-student output validates signed project links", () => {
  const id = "00000000-0000-4000-8000-000000000001";
  const data = { request_id: id, granted_scope: ["projects"], expires_at: "2027-01-01T00:00:00.000Z", projects: [{ id, title: "Demo", skills: ["React"], live_url: "https://demo.example.test/", github_url: "https://github.com/example/demo", files: [{ name: "report.pdf", url: "https://signed.example.test/file?token=x" }], video_url: "https://signed.example.test/video?token=x" }] };
  assertEquals(RevealStudentOutputSchema.safeParse(data).success, true);
  assertEquals(RevealStudentOutputSchema.safeParse({ ...data, projects: [{ id, title: "Demo", skills: [], video_url: "not-a-url" }] }).success, false);
});
