import { assertEquals, assertFalse } from "@std/assert";
import { AdminUpdateConfigInputSchema, AdminUpdateConfigOutputSchema } from "./admin-update-config.ts";

Deno.test("admin config schema accepts documented keys and bounded values", () => {
  assertEquals(AdminUpdateConfigInputSchema.safeParse({ key: "AGENT_MODE", value: "mock" }).success, true);
  assertEquals(AdminUpdateConfigInputSchema.safeParse({ key: "BORDERLINE", value: [40, 60] }).success, true);
  assertEquals(AdminUpdateConfigInputSchema.safeParse({ key: "AI_KILL_SWITCH", value: true }).success, true);
  assertEquals(AdminUpdateConfigInputSchema.safeParse({ key: "MATCH_COVERAGE_FLOOR", value: 0.25 }).success, true);
  assertEquals(AdminUpdateConfigInputSchema.safeParse({ key: "MATCH_LEVEL_FLOORS", value: { Emerging: 51, Competent: 51, Proficient: 70, Advanced: 85 } }).success, true);
  assertEquals(AdminUpdateConfigOutputSchema.safeParse({ key: "PASS_MARK", updated_at: "2026-01-01T00:00:00.000Z" }).success, true);
});

Deno.test("admin config schema rejects unsupported keys, invalid bounds, and extra fields", () => {
  assertFalse(AdminUpdateConfigInputSchema.safeParse({ key: "SUPABASE_SERVICE_ROLE_KEY", value: "x" }).success);
  assertFalse(AdminUpdateConfigInputSchema.safeParse({ key: "BORDERLINE", value: [60, 40] }).success);
  assertFalse(AdminUpdateConfigInputSchema.safeParse({ key: "VIDEO_MAX_SECONDS", value: 3601 }).success);
  assertFalse(AdminUpdateConfigInputSchema.safeParse({ key: "PASS_MARK", value: 50, actor_id: "x" }).success);
  assertFalse(AdminUpdateConfigInputSchema.safeParse({ key: "MATCH_COVERAGE_FLOOR", value: 0.8 }).success);
  assertFalse(AdminUpdateConfigInputSchema.safeParse({ key: "MATCH_LEVEL_FLOORS", value: { Emerging: 70, Competent: 60, Proficient: 80, Advanced: 90 } }).success);
});
