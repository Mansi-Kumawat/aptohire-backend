import { assertEquals } from "jsr:@std/assert@1";
import { SubmitProjectInputSchema, SubmitProjectOutputSchema } from "./submit-project.ts";

Deno.test("submit-project accepts only confirmed submissions", () => {
  assertEquals(SubmitProjectInputSchema.safeParse({ submission_id: "af400000-0000-4000-8000-000000000001", confirm: true }).success, true);
  assertEquals(SubmitProjectInputSchema.safeParse({ submission_id: "af400000-0000-4000-8000-000000000001", confirm: false }).success, false);
  assertEquals(SubmitProjectInputSchema.safeParse({ submission_id: "af400000-0000-4000-8000-000000000001", confirm: true, user_id: "af400000-0000-4000-8000-000000000002" }).success, false);
});

Deno.test("submit-project response is frozen and status validated", () => {
  assertEquals(SubmitProjectOutputSchema.safeParse({ run_id: "af400000-0000-4000-8000-000000000001", status: "queued", mode: "mock" }).success, true);
  assertEquals(SubmitProjectOutputSchema.safeParse({ run_id: "af400000-0000-4000-8000-000000000001", status: "queued", mode: "direct" }).success, true);
  assertEquals(SubmitProjectOutputSchema.safeParse({ run_id: "af400000-0000-4000-8000-000000000001", status: "running", mode: "mock" }).success, false);
  assertEquals(SubmitProjectOutputSchema.safeParse({ run_id: "af400000-0000-4000-8000-000000000001", status: "queued", mode: "mock", internal: true }).success, false);
});
