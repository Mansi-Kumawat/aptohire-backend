import { assertEquals, assertNotEquals } from "@std/assert";
import { blindAlias, cosineScore, parseVector } from "./matching.ts";

Deno.test("blind aliases are deterministic, job-scoped, and pepper-dependent", async () => {
  const a = await blindAlias("pepper-a", "job-1", "student-1");
  assertEquals(a, await blindAlias("pepper-a", "job-1", "student-1"));
  assertNotEquals(a, await blindAlias("pepper-a", "job-2", "student-1"));
  assertNotEquals(a, await blindAlias("pepper-b", "job-1", "student-1"));
  assertEquals(a.startsWith("Candidate "), true);
  assertEquals(a.slice("Candidate ".length).length, 6);
});

Deno.test("vector helpers reject malformed vectors and map cosine similarity", () => {
  const same = Array(768).fill(1);
  assertEquals(parseVector(JSON.stringify(same))?.length, 768);
  assertEquals(parseVector("not-json"), null);
  assertEquals(parseVector([1, 2]), null);
  assertEquals(cosineScore(same, same), 100);
  assertEquals(cosineScore(same, null), null);
});
