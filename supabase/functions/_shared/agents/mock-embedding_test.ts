import { assertEquals, assertGreater, assertThrows } from "jsr:@std/assert@1";
import { cosineScore } from "../matching.ts";
import { mockEmbedding } from "./mock-embedding.ts";

Deno.test("mock embedding is deterministic, bounded, and normalized", () => {
  const first = mockEmbedding("React TypeScript Accessibility");
  const second = mockEmbedding("React TypeScript Accessibility");
  assertEquals(first, second);
  assertEquals(first.length, 768);
  assertEquals(first.every((value) => Number.isFinite(value) && value >= -1 && value <= 1), true);
  const norm = Math.sqrt(first.reduce((sum, value) => sum + value * value, 0));
  assertEquals(Math.abs(norm - 1) < 1e-10, true);
});

Deno.test("mock embedding provides a deterministic skill-token similarity fallback", () => {
  const requested = mockEmbedding("React TypeScript Accessibility");
  const overlapping = mockEmbedding("React TypeScript Testing");
  const unrelated = mockEmbedding("Accounting Financial Modelling");
  const overlapScore = cosineScore(requested, overlapping);
  const unrelatedScore = cosineScore(requested, unrelated);
  assertEquals(overlapScore === null, false);
  assertEquals(unrelatedScore === null, false);
  assertGreater(overlapScore!, unrelatedScore!);
});

Deno.test("mock embedding rejects invalid dimensions and represents empty input as a zero vector", () => {
  assertThrows(() => mockEmbedding("React", 2), RangeError);
  assertEquals(mockEmbedding("", 16), new Array(16).fill(0));
});
