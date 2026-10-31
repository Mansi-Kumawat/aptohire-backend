import { assertEquals } from "@std/assert";
import { ExportMyDataInputSchema, ExportMyDataOutputSchema } from "./export-my-data.ts";

Deno.test("export-my-data accepts only an empty input object", () => {
  assertEquals(ExportMyDataInputSchema.safeParse({}).success, true);
  assertEquals(ExportMyDataInputSchema.safeParse({ student_id: crypto.randomUUID() }).success, false);
});

Deno.test("export-my-data output requires a valid signed URL", () => {
  assertEquals(ExportMyDataOutputSchema.safeParse({ signed_url: "https://storage.example.test/signed" }).success, true);
  assertEquals(ExportMyDataOutputSchema.safeParse({ signed_url: "not-a-url" }).success, false);
});
