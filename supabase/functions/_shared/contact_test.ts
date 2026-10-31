import { assertEquals } from "jsr:@std/assert@1";
import { containsContactDetails } from "./contact.ts";

Deno.test("contact detector rejects emails, URLs, handles and phone-like text", () => {
  assertEquals(containsContactDetails("Please email person@example.test"), true);
  assertEquals(containsContactDetails("Visit https://example.test/contact"), true);
  assertEquals(containsContactDetails("My handle is @candidate_7"), true);
  assertEquals(containsContactDetails("Message: (@candidate_7)"), true);
  assertEquals(containsContactDetails("My repo is github.com/person/repo"), true);
  assertEquals(containsContactDetails("person\u200b@example.test"), true);
  assertEquals(containsContactDetails("Call +1 (555) 123-4567"), true);
  assertEquals(containsContactDetails("Call ＋１ (５５５) １２３-４５６７"), true);
});

Deno.test("contact detector allows plain recruiter message", () => {
  assertEquals(containsContactDetails("I liked the accessible project and would like to discuss the role."), false);
});
