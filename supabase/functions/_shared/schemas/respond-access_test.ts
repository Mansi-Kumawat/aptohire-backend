import { assertEquals } from "@std/assert";
import { RespondAccessInputSchema, RespondAccessOutputSchema } from "./respond-access.ts";

Deno.test("respond-access accepts subset grants and declines without grant details", () => {
  const request = "00000000-0000-4000-8000-000000000001";
  assertEquals(RespondAccessInputSchema.safeParse({ request_id: request, decision: "accept", granted_scope: ["profile"], duration_days: 7 }).success, true);
  assertEquals(RespondAccessInputSchema.safeParse({ request_id: request, decision: "decline" }).success, true);
  assertEquals(RespondAccessOutputSchema.safeParse({ status: "accepted", expires_at: "2026-11-01T00:00:00.000Z" }).success, true);
  assertEquals(RespondAccessOutputSchema.safeParse({ status: "declined" }).success, true);
});

Deno.test("respond-access rejects empty, duplicate, malformed, and decline grant fields", () => {
  const request_id = "00000000-0000-4000-8000-000000000001";
  assertEquals(RespondAccessInputSchema.safeParse({ request_id, decision: "accept" }).success, false);
  assertEquals(RespondAccessInputSchema.safeParse({ request_id, decision: "accept", granted_scope: [] }).success, false);
  assertEquals(RespondAccessInputSchema.safeParse({ request_id, decision: "accept", granted_scope: ["profile", "profile"] }).success, false);
  assertEquals(RespondAccessInputSchema.safeParse({ request_id, decision: "decline", duration_days: 30 }).success, false);
  assertEquals(RespondAccessInputSchema.safeParse({ request_id, decision: "accept", granted_scope: ["identity"] }).success, false);
});
