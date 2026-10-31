import { assertEquals, assertThrows } from "@std/assert";
import { parseStrictCsv } from "./csv.ts";

Deno.test("strict CSV parser handles quoted delimiters, escaped quotes, and CRLF", () => {
  const parsed = parseStrictCsv('full_name,email,program\r\n"Demo, Student",learner@example.test,"He said ""hello"""\r\n');
  assertEquals(parsed.headers, ["full_name", "email", "program"]);
  assertEquals(parsed.rows, [["Demo, Student", "learner@example.test", 'He said "hello"']]);
});

Deno.test("strict CSV parser rejects malformed quoting and duplicate headers", () => {
  assertThrows(() => parseStrictCsv('name,email\n"unfinished,x@example.test'));
  assertThrows(() => parseStrictCsv('name,name\nA,B'));
});
