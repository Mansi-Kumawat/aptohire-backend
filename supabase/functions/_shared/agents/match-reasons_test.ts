import { assertEquals } from "jsr:@std/assert@1";
import { appendConstrainedMatchReasons, constrainMatchReasonOutput, matchReasonPromptInput, type MatchReasonCandidate } from "./match-reasons.ts";

const candidates: MatchReasonCandidate[] = [
  { alias: "Candidate A1B2", facts: ["Verified React — Proficient (78)", "Verified TypeScript — Competent (62)"] },
  { alias: "Candidate C3D4", facts: ["Verified SQL — Advanced (88)"] },
];

Deno.test("match reason accepts only grounded wording for a requested blind alias", () => {
  const accepted = constrainMatchReasonOutput({
    reasons: [{ alias: "Candidate A1B2", reason: "Candidate A1B2 matches verified React at Proficient (78)." }],
  }, candidates);
  assertEquals(accepted.get("Candidate A1B2"), "Candidate A1B2 matches verified React at Proficient (78).");
});

Deno.test("match reason rejects ungrounded skills, unknown aliases, duplicates, and identity/contact content", () => {
  const accepted = constrainMatchReasonOutput({
    reasons: [
      { alias: "Candidate A1B2", reason: "Strong match in Go with verified React (78)." },
      { alias: "Candidate UNKNOWN", reason: "Verified SQL at Advanced (88)." },
      { alias: "Candidate C3D4", reason: "Verified SQL at Advanced (88) https://example.test" },
      { alias: "Candidate C3D4", reason: "Verified SQL at Advanced (88); email me at person@example.test" },
      { alias: "Candidate C3D4", reason: "Verified SQL at Advanced (88)." },
      { alias: "Candidate C3D4", reason: "Verified SQL at Advanced (88)." },
    ],
  }, candidates);
  assertEquals([...accepted.entries()], [["Candidate C3D4", "Verified SQL at Advanced (88)."]]);
});

Deno.test("prompt input is bounded and excludes fields other than alias and deterministic facts", () => {
  const result = matchReasonPromptInput([{ alias: "Candidate A1B2", facts: ["Fact one", "Fact two", "Fact three", "discarded"] }]);
  assertEquals(result, JSON.stringify([{ alias: "Candidate A1B2", facts: ["Fact one", "Fact two", "Fact three"] }]));
});

Deno.test("appended wording preserves deterministic fact priority and the three-reason RPC limit", () => {
  const matches = [{ alias: "Candidate A1B2", reasons: ["Fact one", "Fact two", "Fact three"] }];
  appendConstrainedMatchReasons(matches, new Map([["Candidate A1B2", "Candidate A1B2 matches verified React at Proficient (78)."]]));
  assertEquals(matches[0].reasons, ["Fact one", "Fact two", "Candidate A1B2 matches verified React at Proficient (78)."]);
  assertEquals(matches[0].reasons.length <= 3, true);
});
