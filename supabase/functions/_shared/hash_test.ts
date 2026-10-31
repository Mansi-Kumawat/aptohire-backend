import { assertEquals, assertNotEquals } from "@std/assert";
import { hmacHex, normalizeStudentId } from "./hash.ts";

Deno.test("normalizes student ID consistently", () => {
  assertEquals(normalizeStudentId(" b-1042 "), "B1042");
  assertEquals(normalizeStudentId("Ｂ－１０４２"), "B1042");
});

Deno.test("HMAC is deterministic and secret-dependent", async () => {
  const a = await hmacHex("test-pepper-a", normalizeStudentId(" B-1042 "));
  const again = await hmacHex("test-pepper-a", normalizeStudentId("B1042"));
  const other = await hmacHex("test-pepper-b", normalizeStudentId("B1042"));
  assertEquals(a, again);
  assertNotEquals(a, other);
});
