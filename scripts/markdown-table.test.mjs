import test from "node:test";
import assert from "node:assert/strict";
import { splitMarkdownTableRow } from "./markdown-table.js";

test("Markdown row parser preserves escaped pipes inside SQL cells", () => {
  const row = "| `storage.objects` | `student_storage_select` | SELECT | (name = 'a\\|\\|b') | `0071.test.sql` |";
  assert.deepEqual(splitMarkdownTableRow(row), [
    "`storage.objects`",
    "`student_storage_select`",
    "SELECT",
    "(name = 'a\\|\\|b')",
    "`0071.test.sql`",
  ]);
});

test("Markdown row parser handles ordinary cells and outer delimiters", () => {
  assert.deepEqual(splitMarkdownTableRow("| A | B | C |"), ["A", "B", "C"]);
});
