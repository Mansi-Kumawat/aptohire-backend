import { assertEquals } from "jsr:@std/assert@1";
import { normalizeLifeStatus, normalizeProgramLevel } from "./university-contract.ts";

Deno.test("university program labels normalize to the frozen UG/PG vocabulary", () => {
  assertEquals(normalizeProgramLevel("ug"), "ug");
  assertEquals(normalizeProgramLevel("Bachelors"), "ug");
  assertEquals(normalizeProgramLevel("M.Sc."), "pg");
  assertEquals(normalizeProgramLevel("Masters"), "pg");
  assertEquals(normalizeProgramLevel("unknown program"), null);
});

Deno.test("university lifecycle compatibility maps legacy student status to enrolled", () => {
  assertEquals(normalizeLifeStatus("student"), "enrolled");
  assertEquals(normalizeLifeStatus("incoming"), "incoming");
  assertEquals(normalizeLifeStatus("alumni"), "alumni");
  assertEquals(normalizeLifeStatus("invalid"), null);
});
