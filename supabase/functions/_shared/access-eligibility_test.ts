import { assertEquals } from "@std/assert";
import { isCurrentMatchRequestable } from "./access-eligibility.ts";

const eligible = {
  jobOpen: true,
  studentHasLogin: true,
  studentDiscoverable: true,
  candidateProjectionDiscoverable: true,
  shareableVerifiedSkillCount: 2,
};

Deno.test("request-access requires an open job and current discoverable verified candidate", () => {
  assertEquals(isCurrentMatchRequestable(eligible), true);
  assertEquals(isCurrentMatchRequestable({ ...eligible, jobOpen: false }), false);
  assertEquals(isCurrentMatchRequestable({ ...eligible, studentHasLogin: false }), false);
  assertEquals(isCurrentMatchRequestable({ ...eligible, studentDiscoverable: false }), false);
  assertEquals(isCurrentMatchRequestable({ ...eligible, candidateProjectionDiscoverable: false }), false);
  assertEquals(isCurrentMatchRequestable({ ...eligible, shareableVerifiedSkillCount: 0 }), false);
  assertEquals(isCurrentMatchRequestable({ ...eligible, shareableVerifiedSkillCount: null }), false);
});
