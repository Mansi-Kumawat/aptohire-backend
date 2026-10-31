import test from "node:test";
import assert from "node:assert/strict";
import { adminHandlerViolations } from "./check-admin-aal2.js";

test("admin handler accepts the shared JWT/admin/AAL2 gate", () => {
  assert.deepEqual(adminHandlerViolations("admin-example", `const handler = withHandler({ auth: "jwt", roles: ["admin"], aal2: true, input: Input, output: Output }, async () => ({}));`), []);
});

test("admin handler rejects missing AAL2 and role/auth bypasses", () => {
  assert.deepEqual(adminHandlerViolations("admin-no-aal", `withHandler({ auth: "jwt", roles: ["admin"], input: Input }, fn);`), ["admin-no-aal: aal2: true is required"]);
  assert.deepEqual(adminHandlerViolations("admin-no-role", `withHandler({ auth: "jwt", roles: ["student"], aal2: true }, fn);`), ["admin-no-role: roles must include admin"]);
  assert.deepEqual(adminHandlerViolations("admin-no-jwt", `withHandler({ auth: "none", roles: ["admin"], aal2: true }, fn);`), ["admin-no-jwt: auth must be jwt"]);
  assert.deepEqual(adminHandlerViolations("admin-untyped", `Deno.serve(fn);`), ["admin-untyped: no statically recognizable withHandler config"]);
});
