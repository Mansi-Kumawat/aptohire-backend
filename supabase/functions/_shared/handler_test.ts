import { assertEquals } from "@std/assert";
import { z } from "zod";
import { withHandler } from "./handler.ts";

Deno.test("withHandler validates input and output schemas", async () => {
  const handler = withHandler({ auth: "none", input: z.object({ value: z.string() }).strict(), output: z.object({ ok: z.boolean() }).strict() }, () => Promise.resolve({ body: { ok: true } }));
  const good = await handler(new Request("http://localhost/fn", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ value: "demo" }) }));
  assertEquals(good.status, 200);
  assertEquals(await good.json(), { ok: true });
  const bad = await handler(new Request("http://localhost/fn", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ value: "demo", extra: true }) }));
  assertEquals(bad.status, 422);
  const payload = await bad.json();
  assertEquals(payload.error.code, "VALIDATION_FAILED");
});

Deno.test("withHandler returns stable invalid JSON errors", async () => {
  const handler = withHandler({ auth: "none", input: z.object({}).strict(), output: z.object({ ok: z.boolean() }).strict() }, () => Promise.resolve({ body: { ok: true } }));
  const response = await handler(new Request("http://localhost/fn", { method: "POST", body: "not-json" }));
  assertEquals(response.status, 422);
  assertEquals((await response.json()).error.code, "VALIDATION_FAILED");
});

Deno.test("withHandler runs config, rate-limit, idempotency, validated business logic, then audit", async () => {
  const calls: string[] = [];
  const handler = withHandler({
    auth: "none",
    input: z.object({ value: z.string() }).strict(),
    output: z.object({ ok: z.boolean() }).strict(),
    loadConfig: () => {
      calls.push("config");
      return Promise.resolve({ safeMode: true });
    },
    rateLimit: (input, context) => Promise.resolve().then(() => {
      calls.push(`rate:${input.value}:${String(context.config?.safeMode)}`);
    }),
    idempotent: (_input, _context, execute) => {
      calls.push("idempotency");
      return execute();
    },
    audit: (_input, _context, result) => Promise.resolve().then(() => {
      calls.push(`audit:${String(result.body?.ok)}`);
    }),
  }, () => Promise.resolve().then(() => {
    calls.push("business");
    return { body: { ok: true } };
  }));
  const response = await handler(new Request("http://localhost/fn", {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ value: "demo" }),
  }));
  assertEquals(response.status, 200);
  assertEquals(calls, ["config", "rate:demo:true", "idempotency", "business", "audit:true"]);
});

Deno.test("withHandler fails closed on a rate-limit hook before business logic", async () => {
  let called = false;
  const handler = withHandler({
    auth: "none",
    input: z.object({}).strict(),
    output: z.object({ ok: z.boolean() }).strict(),
    rateLimit: () => Promise.reject(new Error("rate denied")),
  }, () => Promise.resolve().then(() => {
    called = true;
    return { body: { ok: true } };
  }));
  const response = await handler(new Request("http://localhost/fn", { method: "POST", body: "{}" }));
  assertEquals(response.status, 503);
  assertEquals(called, false);
});
