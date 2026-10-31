import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { parseAppEnv, runResetAndAssert, validateResetEnvironment } from "./db-reset.js";

test("reset guard allows only explicit local/demo environments", () => {
  assert.deepEqual(validateResetEnvironment("local"), { ok: true, reason: "" });
  assert.deepEqual(validateResetEnvironment("demo"), { ok: true, reason: "" });
  assert.equal(validateResetEnvironment("production").ok, false);
  assert.equal(validateResetEnvironment(undefined).ok, false);
  assert.equal(validateResetEnvironment("staging").ok, false);
});

test("APP_ENV parser handles export, whitespace, comments, and quotes", () => {
  assert.equal(parseAppEnv("# APP_ENV=production\nexport APP_ENV = 'local' # only for this checkout\n"), "local");
  assert.equal(parseAppEnv("APP_ENV=demo\n"), "demo");
  assert.equal(parseAppEnv("SOME_OTHER_KEY=local\n"), undefined);
});

test("successful local reset runs the demo-state assertions afterward", () => {
  const calls = [];
  const run = (command, args, options) => {
    calls.push({ command, args, options });
    return { status: 0 };
  };
  assert.deepEqual(runResetAndAssert("/repo", run, "node"), { code: 0 });
  assert.equal(calls.length, 2);
  assert.deepEqual(calls[0], { command: "supabase", args: ["db", "reset"], options: { cwd: "/repo", stdio: "inherit" } });
  assert.deepEqual(calls[1], { command: "node", args: [path.join("/repo", "scripts", "assert-demo-states.js")], options: { cwd: "/repo", stdio: "inherit" } });
});

test("failed reset never runs demo-state assertions", () => {
  const calls = [];
  const result = runResetAndAssert("/repo", (command, args) => {
    calls.push({ command, args });
    return { status: 1 };
  }, "node");
  assert.deepEqual(result, { code: 1 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].command, "supabase");
});

test("reset command launch errors fail without running assertions", () => {
  const calls = [];
  const result = runResetAndAssert("/repo", (command) => {
    calls.push(command);
    return { status: null, error: new Error("missing CLI") };
  }, "node");
  assert.deepEqual(result, { code: 1, error: "Could not run Supabase CLI: missing CLI" });
  assert.deepEqual(calls, ["supabase"]);
});
