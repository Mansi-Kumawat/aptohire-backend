import { assertEquals } from "@std/assert";
import { isExpiredDataExport, isSafeDataExportObjectPath } from "./export-retention.ts";

Deno.test("export retention accepts only UUID-owned export JSON paths", () => {
  assertEquals(isSafeDataExportObjectPath("123e4567-e89b-12d3-a456-426614174000/exports/123e4567-e89b-12d3-a456-426614174001.json"), true);
  assertEquals(isSafeDataExportObjectPath("123e4567-e89b-12d3-a456-426614174000/exports/../private.json"), false);
  assertEquals(isSafeDataExportObjectPath("student@example.test/exports/export.json"), false);
  assertEquals(isSafeDataExportObjectPath("123e4567-e89b-12d3-a456-426614174000/exports/123e4567-e89b-12d3-a456-426614174001.txt"), false);
});

Deno.test("export retention deletes only objects with valid timestamps at or before cutoff", () => {
  const cutoff = new Date("2026-10-01T00:00:00.000Z");
  assertEquals(isExpiredDataExport("2026-09-30T23:59:59.000Z", cutoff), true);
  assertEquals(isExpiredDataExport("2026-10-01T00:00:00.000Z", cutoff), true);
  assertEquals(isExpiredDataExport("2026-10-01T00:00:01.000Z", cutoff), false);
  assertEquals(isExpiredDataExport("not-a-date", cutoff), false);
  assertEquals(isExpiredDataExport(null, cutoff), false);
});
