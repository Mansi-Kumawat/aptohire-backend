import { assertEquals } from "jsr:@std/assert@1";
import { evidenceItemFromRef } from "./evidence-item.ts";

Deno.test("evidence refs map to the frozen frontend locator shape", () => {
  assertEquals(evidenceItemFromRef("video:102"), { ref: "video:102", kind: "video", label: "Video 01:42", pointer: "102" });
  assertEquals(evidenceItemFromRef("repo:src/cart.tsx#L2-L4", "small excerpt"), {
    ref: "repo:src/cart.tsx#L2-L4", kind: "repo", label: "src/cart.tsx", pointer: "src/cart.tsx#L2-L4", excerpt: "small excerpt",
  });
  assertEquals(evidenceItemFromRef("file:README.md#L1-L3")?.kind, "file");
  assertEquals(evidenceItemFromRef("doc:design/notes.md#L4-L8")?.kind, "doc");
  assertEquals(evidenceItemFromRef("live:https://portfolio.example.test")?.label, "Live site");
});

Deno.test("evidence refs reject traversal, malformed ranges and unsafe live URLs", () => {
  assertEquals(evidenceItemFromRef("repo:../secret.txt#L1-L2"), null);
  assertEquals(evidenceItemFromRef("file:src/app.ts#L8-L2"), null);
  assertEquals(evidenceItemFromRef("live:http://portfolio.example.test"), null);
  assertEquals(evidenceItemFromRef("live:https://user:password@portfolio.example.test"), null);
  assertEquals(evidenceItemFromRef("submission:00000000-0000-4000-8000-000000000001"), null);
});
