import { assertEquals } from "@std/assert";
import { AdminRetryRunInputSchema, AdminRetryRunOutputSchema } from "./admin-retry-run.ts";

Deno.test("admin retry accepts only a failed run identifier", () => {
  assertEquals(AdminRetryRunInputSchema.safeParse({ run_id: "00000000-0000-4000-8000-000000000001" }).success, true);
  assertEquals(AdminRetryRunInputSchema.safeParse({ run_id: "bad" }).success, false);
  assertEquals(AdminRetryRunInputSchema.safeParse({ run_id: "00000000-0000-4000-8000-000000000001", user_id: "spoofed" }).success, false);
});
Deno.test("admin retry response never claims a non-mock mode", () => {
  const run_id = "00000000-0000-4000-8000-000000000001";
  assertEquals(AdminRetryRunOutputSchema.safeParse({ run_id, status: "queued", mode: "mock" }).success, true);
  assertEquals(AdminRetryRunOutputSchema.safeParse({ run_id, status: "queued", mode: "direct" }).success, false);
});
