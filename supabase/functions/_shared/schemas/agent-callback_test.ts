import { assertEquals } from "@std/assert";
import { AgentCallbackOutputSchema } from "./agent-callback.ts";

Deno.test("agent callback output is strict and reports completed run identifiers", () => {
  const valid = { run_id: "00000000-0000-4000-8000-000000000001", audit_id: "00000000-0000-4000-8000-000000000002", status: "completed" };
  assertEquals(AgentCallbackOutputSchema.safeParse(valid).success, true);
  assertEquals(AgentCallbackOutputSchema.safeParse({ ...valid, token: "secret" }).success, false);
  assertEquals(AgentCallbackOutputSchema.safeParse({ ...valid, status: "queued" }).success, false);
});
