import { assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import type { AssignmentTemplate } from "./project-assignment.ts";
import { chooseProjectVariation } from "./project-variation.ts";

const template: AssignmentTemplate = {
  id: "template-variation-1", skill_id: "skill-1", level: "Competent", title: "Build a {{domain}} dashboard",
  brief: {
    objective: "Use {{dataset}} to build a dashboard for {{domain}}. Support {{constraint}} and include {{twist}}.",
    deliverables: ["Source code", "Tests"],
    variation_slots: {
      domain: ["a fictional library", "a fictional community garden", "a fictional transit service"],
      dataset: ["synthetic book records", "synthetic plant records", "synthetic transit records"],
      constraint: ["keyboard-only operation", "low-bandwidth mode", "screen-reader support"],
      twist: ["an offline state", "a data-quality warning", "a printable summary"],
    },
  },
};
const secret = "local-synthetic-variation-hmac-key-not-real";

Deno.test("project variation fills bounded slots reproducibly without changing template invariants", async () => {
  const a = await chooseProjectVariation(template, "fixed-seed", secret, new Map());
  const b = await chooseProjectVariation(template, "fixed-seed", secret, new Map());
  assertEquals(a, b);
  assertEquals(a.template.brief && JSON.stringify(a.template.brief).includes("{{"), false);
  assertEquals(JSON.stringify(a.template.brief).includes("variation_slots"), false);
  assertEquals(a.template.id, template.id);
  assertEquals(a.template.level, template.level);
  assertEquals(typeof a.fingerprint, "string");
  assertEquals(a.fingerprint?.length, 64);
});

Deno.test("project variation re-rolls away from overused fingerprints when alternatives exist", async () => {
  const first = await chooseProjectVariation(template, "variation-seed", secret, new Map(), 1, 1);
  const counts = new Map([[first.fingerprint!, 1]]);
  const rerolled = await chooseProjectVariation(template, "variation-seed", secret, counts, 1, 16);
  assertNotEquals(rerolled.fingerprint, first.fingerprint);
  assertEquals(JSON.stringify(rerolled.template.brief).includes("{{"), false);
});

Deno.test("project variation omits fingerprint without configured slots and rejects short secrets", async () => {
  const plain = { ...template, brief: { objective: "Build a fixed project." } };
  assertEquals(await chooseProjectVariation(plain, "seed", secret, new Map()), { template: plain, fingerprint: null, values: {} });
  await assertRejects(() => chooseProjectVariation(template, "seed", "short", new Map()), Error);
});
