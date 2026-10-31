import { assertEquals } from "@std/assert";
import { RequestAccessInputSchema, RequestAccessOutputSchema } from "./request-access.ts";

Deno.test("request-access accepts allowed scopes/durations and rejects unknown fields", () => {
  const request = { match_result_id: "00000000-0000-4000-8000-000000000001", requested_scope: ["profile", "scorecard"], duration_days: 30 };
  assertEquals(RequestAccessInputSchema.safeParse(request).success, true);
  assertEquals(RequestAccessInputSchema.safeParse({ ...request, duration_days: 14 }).success, false);
  assertEquals(RequestAccessInputSchema.safeParse({ ...request, requested_scope: ["profile", "profile"] }).success, false);
  assertEquals(RequestAccessInputSchema.safeParse({ ...request, student_id: "00000000-0000-4000-8000-000000000002" }).success, false);
  assertEquals(RequestAccessOutputSchema.safeParse({ request_id: request.match_result_id }).success, true);
});
