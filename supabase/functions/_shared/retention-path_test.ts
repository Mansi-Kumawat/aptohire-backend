import { assertEquals } from "@std/assert";
import { confirmedRemovedPaths, isOwnedVideoObjectPath, isSafeVideoObjectPath } from "./retention-path.ts";

Deno.test("retention cleanup accepts only student-owned submission video paths", () => {
  assertEquals(isSafeVideoObjectPath("a0460000-0000-4000-8000-000000000001/a0460000-0000-4000-8000-000000000002/demo.mp4"), true);
  assertEquals(isSafeVideoObjectPath("a0460000-0000-4000-8000-000000000001/a0460000-0000-4000-8000-000000000002/demo.webm"), true);
  assertEquals(isSafeVideoObjectPath("../private/file.mp4"), false);
  assertEquals(isSafeVideoObjectPath("a0460000-0000-4000-8000-000000000001/demo.mp4"), false);
  assertEquals(isSafeVideoObjectPath("a0460000-0000-4000-8000-000000000001/a0460000-0000-4000-8000-000000000002/other.mp4"), false);
});

Deno.test("submission video paths are bound to the current student and submission", () => {
  const valid = "a0460000-0000-4000-8000-000000000001/a0460000-0000-4000-8000-000000000002/demo.mp4";
  assertEquals(isOwnedVideoObjectPath(valid, "a0460000-0000-4000-8000-000000000001", "a0460000-0000-4000-8000-000000000002"), true);
  assertEquals(isOwnedVideoObjectPath(valid, "a0460000-0000-4000-8000-000000000009", "a0460000-0000-4000-8000-000000000002"), false);
  assertEquals(isOwnedVideoObjectPath(valid, "a0460000-0000-4000-8000-000000000001", "a0460000-0000-4000-8000-000000000009"), false);
});

Deno.test("retention cleanup confirms only objects actually reported removed by Storage", () => {
  const requested = [
    "a0460000-0000-4000-8000-000000000001/a0460000-0000-4000-8000-000000000002/demo.mp4",
    "a0460000-0000-4000-8000-000000000003/a0460000-0000-4000-8000-000000000004/demo.mov",
  ];
  assertEquals(confirmedRemovedPaths(requested, [requested[1], null, 42]), [requested[1]]);
});
