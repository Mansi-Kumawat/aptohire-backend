import { assertEquals } from "@std/assert";
import { isFictionalTestAccountEmail, isLocalSyntheticDirectOptedIn, isLocalSyntheticProfileDirectAllowed } from "./synthetic-direct.ts";

Deno.test("direct provider opt-in fails closed unless local and explicitly enabled", () => {
  assertEquals(isLocalSyntheticDirectOptedIn("local", "true"), true);
  assertEquals(isLocalSyntheticDirectOptedIn("local", undefined), false);
  assertEquals(isLocalSyntheticDirectOptedIn("demo", "true"), false);
  assertEquals(isLocalSyntheticDirectOptedIn("production", "true"), false);
  assertEquals(isLocalSyntheticDirectOptedIn(undefined, "true"), false);
  assertEquals(isLocalSyntheticDirectOptedIn("local", "TRUE"), false);
});

Deno.test("direct provider caller must use a fictional .test email", () => {
  assertEquals(isFictionalTestAccountEmail("recruiter@example.test"), true);
  assertEquals(isFictionalTestAccountEmail("Student@Demo.TEST "), true);
  assertEquals(isFictionalTestAccountEmail("person@example.com"), false);
  assertEquals(isFictionalTestAccountEmail("user@not-test.example"), false);
  assertEquals(isFictionalTestAccountEmail("not-an-email.test"), false);
  assertEquals(isFictionalTestAccountEmail(null), false);
});

Deno.test("direct profile mode also requires a non-auto-approved source and an active kill switch", () => {
  const base = { agentMode: "direct", killSwitch: false, sourceAutoApprove: false, appEnv: "local", optIn: "true", email: "student@demo.test" };
  assertEquals(isLocalSyntheticProfileDirectAllowed(base), true);
  assertEquals(isLocalSyntheticProfileDirectAllowed({ ...base, sourceAutoApprove: true }), false);
  assertEquals(isLocalSyntheticProfileDirectAllowed({ ...base, killSwitch: true }), false);
  assertEquals(isLocalSyntheticProfileDirectAllowed({ ...base, agentMode: "mock" }), false);
  assertEquals(isLocalSyntheticProfileDirectAllowed({ ...base, appEnv: "production" }), false);
  assertEquals(isLocalSyntheticProfileDirectAllowed({ ...base, email: "student@example.com" }), false);
});
