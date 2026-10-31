import test from "node:test";
import assert from "node:assert/strict";
import { mergeNotificationMatrix } from "./notification-matrix-output.js";

test("notification matrix regeneration replaces generated content and preserves reviewed tail verbatim", () => {
  const reviewedTail = "## Runtime verification still required\n\nRun the mapped suites.\n\n## Manually reviewed behavioral evidence\n\nReviewed row.\n";
  const existing = `# Old generated table\n\n${reviewedTail}`;
  const result = mergeNotificationMatrix("# Fresh generated table\n\nNew rows.", existing);
  assert.equal(result, `# Fresh generated table\n\nNew rows.\n\n${reviewedTail.trimEnd()}\n`);
  assert.equal(result.includes("Old generated table"), false);
});

test("first notification matrix generation has no synthetic curated section", () => {
  assert.equal(mergeNotificationMatrix("# Fresh table\n", ""), "# Fresh table\n");
});
