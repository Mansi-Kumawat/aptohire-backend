import { assertEquals } from "@std/assert";
import { hmacHex } from "./hash.ts";
import { verifyHmacCallback } from "./hmac-callback.ts";

Deno.test("HMAC callback accepts fresh valid signatures and sha256 prefix", async () => {
  const secret = "synthetic-callback-secret";
  const timestamp = "1790000000";
  const body = '{"run_id":"synthetic"}';
  const signature = await hmacHex(secret, `${timestamp}.${body}`);
  assertEquals(await verifyHmacCallback(secret, timestamp, body, signature, 1_790_000_000_000), true);
  assertEquals(await verifyHmacCallback(secret, timestamp, body, `sha256=${signature}`, 1_790_000_000_000), true);
});

Deno.test("HMAC callback rejects stale, tampered, malformed, and wrong-secret requests", async () => {
  const secret = "synthetic-callback-secret";
  const timestamp = "1790000000";
  const body = '{"run_id":"synthetic"}';
  const signature = await hmacHex(secret, `${timestamp}.${body}`);
  assertEquals(await verifyHmacCallback(secret, timestamp, body, signature, 1_790_000_400_000), false);
  assertEquals(await verifyHmacCallback(secret, timestamp, `${body} `, signature, 1_790_000_000_000), false);
  assertEquals(await verifyHmacCallback("wrong-secret", timestamp, body, signature, 1_790_000_000_000), false);
  assertEquals(await verifyHmacCallback(secret, "not-a-time", body, signature, 1_790_000_000_000), false);
});
