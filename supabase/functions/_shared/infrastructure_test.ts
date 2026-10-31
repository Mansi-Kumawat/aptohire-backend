import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { writeAuditEvent } from "./audit.ts";
import { loadAppConfig, configBoolean, configNumber, configString } from "./config.ts";
import { HttpError } from "./errors.ts";
import { requestFingerprint, validateIdempotencyKey } from "./idempotency.ts";
import { enforceRateLimit } from "./rate-limit.ts";

Deno.test("idempotency keys are UUIDs and request fingerprints ignore object key order", async () => {
  assertEquals(validateIdempotencyKey("00000000-0000-4000-8000-000000000001"), "00000000-0000-4000-8000-000000000001");
  await assertRejects(() => Promise.resolve().then(() => validateIdempotencyKey("not-a-key")), HttpError);
  assertEquals(await requestFingerprint({ a: 1, b: { x: true } }), await requestFingerprint({ b: { x: true }, a: 1 }));
  assertEquals(await requestFingerprint({ a: 1 }) === await requestFingerprint({ a: 2 }), false);
});

Deno.test("shared rate limiter sends only an HMAC digest to the atomic RPC", async () => {
  const receivedArgs: Record<string, unknown>[] = [];
  const client = {
    rpc: (name: string, args: Record<string, unknown>) => {
      assertEquals(name, "consume_rate_limit");
      receivedArgs.push(args);
      return Promise.resolve({ data: [{ allowed: true, retry_after: 0 }], error: null });
    },
  } as unknown as SupabaseClient;
  await enforceRateLimit(client, { bucket: "profile-sync", subject: "person@example.test", pepper: "unit-test-pepper", max: 3, windowSeconds: 60 });
  const received = receivedArgs[0];
  assertEquals(typeof received?.p_key_hash, "string");
  assertEquals((received?.p_key_hash as string).length, 64);
  assertEquals(received?.p_key_hash === "person@example.test", false);
});

Deno.test("shared rate limiter fails closed when the RPC rejects", async () => {
  const client = { rpc: () => Promise.resolve({ data: [{ allowed: false, retry_after: 12 }], error: null }) } as unknown as SupabaseClient;
  const error = await assertRejects(
    () => enforceRateLimit(client, { bucket: "public-verify", subject: "hashed-ip", pepper: "pepper", max: 1, windowSeconds: 60 }),
    HttpError,
  );
  assertEquals(error.code, "RATE_LIMITED");
});

Deno.test("shared config loader only queries named keys and typed accessors fail to safe defaults", async () => {
  let queried: string[] = [];
  const client = {
    from: (table: string) => {
      assertEquals(table, "app_config");
      return {
        select: (columns: string) => {
          assertEquals(columns, "key,value");
          return { in: (_column: string, keys: string[]) => {
            queried = keys;
            return Promise.resolve({ data: [{ key: "AI_KILL_SWITCH", value: true }, { key: "PASS_MARK", value: "55" }], error: null });
          } };
        },
      };
    },
  } as unknown as SupabaseClient;
  const config = await loadAppConfig(client, ["AI_KILL_SWITCH", "PASS_MARK", "PASS_MARK"]);
  assertEquals(queried, ["AI_KILL_SWITCH", "PASS_MARK"]);
  assertEquals(configBoolean(config, "AI_KILL_SWITCH", false), true);
  assertEquals(configNumber(config, "PASS_MARK", 50), 55);
  assertEquals(configString(config, "MISSING", "mock"), "mock");
});

Deno.test("audit helper rejects PII-named metadata and writes minimized events", async () => {
  const rows: Record<string, unknown>[] = [];
  const client = { from: (table: string) => {
    assertEquals(table, "audit_log");
    return { insert: (row: Record<string, unknown>) => { rows.push(row); return Promise.resolve({ error: null }); } };
  } } as unknown as SupabaseClient;
  await writeAuditEvent(client, { actorId: null, action: "demo_reset_requested", targetType: "demo", targetId: null, metadata: { count: 2, state: "preview" } });
  assertEquals(rows.length, 1);
  assertEquals(rows[0].metadata, { count: 2, state: "preview" });
  await assertRejects(() => writeAuditEvent(client, {
    actorId: null, action: "unsafe_audit", targetType: "demo", targetId: null, metadata: { email: "person@example.test" },
  }), HttpError);
});
