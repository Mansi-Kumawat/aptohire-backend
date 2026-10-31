import { assertEquals } from "@std/assert";
import { parseMatchingThresholds } from "./matching-config.ts";

Deno.test("matching threshold parser accepts the default controlled configuration", () => {
  assertEquals(parseMatchingThresholds(0.25, {
    Emerging: 51,
    Competent: 51,
    Proficient: 70,
    Advanced: 85,
  }), {
    coverageFloor: 0.25,
    levelFloors: { Emerging: 51, Competent: 51, Proficient: 70, Advanced: 85 },
  });
});

Deno.test("matching threshold parser rejects missing, out-of-range, unordered, and extra-key settings", () => {
  assertEquals(parseMatchingThresholds(undefined, { Emerging: 51, Competent: 51, Proficient: 70, Advanced: 85 }), null);
  assertEquals(parseMatchingThresholds(0.8, { Emerging: 51, Competent: 51, Proficient: 70, Advanced: 85 }), null);
  assertEquals(parseMatchingThresholds(0.255, { Emerging: 51, Competent: 51, Proficient: 70, Advanced: 85 }), null);
  assertEquals(parseMatchingThresholds(0.25, { Emerging: 60, Competent: 50, Proficient: 70, Advanced: 85 }), null);
  assertEquals(parseMatchingThresholds(0.25, { Emerging: 51, Competent: 51, Proficient: 70, Advanced: 85, Extra: 1 }), null);
});
