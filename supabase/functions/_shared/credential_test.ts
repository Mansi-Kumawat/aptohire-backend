import { assertEquals } from "@std/assert";
import { isPublicCredentialSkillEligible, publicCredentialDisplayName } from "./credential.ts";

Deno.test("public credential exposes only verified, shareable skills outside human review", () => {
  assertEquals(isPublicCredentialSkillEligible({ verified: true, share_ok: true, pending_review: false }), true);
  assertEquals(isPublicCredentialSkillEligible({ verified: false, share_ok: true, pending_review: false }), false);
  assertEquals(isPublicCredentialSkillEligible({ verified: true, share_ok: false, pending_review: false }), false);
  assertEquals(isPublicCredentialSkillEligible({ verified: true, share_ok: true, pending_review: true }), false);
});

Deno.test("public credential name is minimized and single-word names have no stray initial", () => {
  assertEquals(publicCredentialDisplayName("  Ada   Lovelace Byron "), "Ada B.");
  assertEquals(publicCredentialDisplayName("Grace"), "Grace");
  assertEquals(publicCredentialDisplayName("  "), undefined);
});
