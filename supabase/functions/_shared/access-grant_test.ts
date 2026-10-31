import { assertEquals } from "jsr:@std/assert@1";
import { isAccessGrantActive } from "./access-grant.ts";

const now = Date.parse("2026-10-26T10:00:00Z");
const active = { status: "accepted", expires_at: "2026-10-26T10:01:00Z", granted_scope: ["profile", "scorecard"] };

Deno.test("access reveal requires an active grant retaining every requested scope", () => {
  assertEquals(isAccessGrantActive(active, ["profile"], now), true);
  assertEquals(isAccessGrantActive(active, ["profile", "contact"], now), false);
  assertEquals(isAccessGrantActive({ ...active, granted_scope: ["profile"] }, ["profile", "scorecard"], now), false);
});

Deno.test("access reveal rejects withdrawn, expired, malformed, and absent grants", () => {
  assertEquals(isAccessGrantActive({ ...active, status: "withdrawn" }, ["profile"], now), false);
  assertEquals(isAccessGrantActive({ ...active, expires_at: "2026-10-26T10:00:00Z" }, ["profile"], now), false);
  assertEquals(isAccessGrantActive({ ...active, expires_at: "bad-date" }, ["profile"], now), false);
  assertEquals(isAccessGrantActive({ ...active, granted_scope: "profile" }, ["profile"], now), false);
  assertEquals(isAccessGrantActive(null, ["profile"], now), false);
});
