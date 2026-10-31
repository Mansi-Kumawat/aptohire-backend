import { assertEquals } from "@std/assert";
import { isAgentModeConfigurable } from "./admin-config.ts";

Deno.test("mock mode remains configurable in all environments", () => {
  assertEquals(isAgentModeConfigurable("mock", "production", undefined), true);
  assertEquals(isAgentModeConfigurable("mock", "local", "false"), true);
});

Deno.test("direct mode requires explicit local synthetic-data opt-in", () => {
  assertEquals(isAgentModeConfigurable("direct", "production", "true"), false);
  assertEquals(isAgentModeConfigurable("direct", "local", undefined), false);
  assertEquals(isAgentModeConfigurable("direct", "local", "false"), false);
  assertEquals(isAgentModeConfigurable("direct", "local", "true"), true);
});

Deno.test("n8n mode requires validated webhook configuration", () => {
  assertEquals(isAgentModeConfigurable("n8n", "local", "true"), false);
  assertEquals(isAgentModeConfigurable("n8n", "production", undefined), false);
  assertEquals(isAgentModeConfigurable("n8n", "local", undefined, true), true);
  assertEquals(isAgentModeConfigurable("n8n", "production", undefined, true), false);
});
