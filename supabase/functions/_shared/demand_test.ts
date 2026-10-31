import { assertEquals } from "@std/assert";
import { demandReason, emptyDemandCounts } from "./demand.ts";

const complete = {
  discoverable: true,
  hasCandidateProfile: true,
  insufficientEvidence: false,
  verifiedSkillCount: 3,
  requirementCount: 3,
  coverage: 0.75,
  coverageFloor: 0.25,
};

Deno.test("demand reason assigns one mutually exclusive category in documented priority order", () => {
  assertEquals(demandReason({ ...complete, discoverable: false }), "opted_out");
  assertEquals(demandReason({ ...complete, hasCandidateProfile: false }), "no_eligible");
  assertEquals(demandReason({ ...complete, insufficientEvidence: true }), "insufficient_evidence");
  assertEquals(demandReason({ ...complete, verifiedSkillCount: 0 }), "not_assessed");
  assertEquals(demandReason({ ...complete, verifiedSkillCount: 2 }), "incomplete_assessments");
  assertEquals(demandReason({ ...complete, coverage: 0.2 }), "skills_mismatch");
  assertEquals(demandReason(complete), null);
});

Deno.test("empty candidate pool categorizes current students without requiring a candidate profile", () => {
  assertEquals(demandReason({ ...complete, hasCandidateProfile: false }), "no_eligible");
  assertEquals(demandReason({ ...complete, hasCandidateProfile: false, discoverable: false }), "opted_out");
});

Deno.test("empty demand aggregate contains all six documented integer counters", () => {
  assertEquals(emptyDemandCounts(), {
    no_eligible: 0,
    incomplete_assessments: 0,
    insufficient_evidence: 0,
    skills_mismatch: 0,
    opted_out: 0,
    not_assessed: 0,
  });
});
