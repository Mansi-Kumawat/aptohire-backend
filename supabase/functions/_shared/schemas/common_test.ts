import { assert, assertEquals } from "@std/assert";
import { CredentialResponseSchema, EvidenceItemSchema, ProjectBriefSchema, ScopeSchema } from "./common.ts";

Deno.test("scope and brief schemas enforce allowed fields", () => {
  assert(ScopeSchema.safeParse("profile").success);
  assert(!ScopeSchema.safeParse("identity").success);
  const brief = { title: "Build a page", objective: "Implement accessible UI", deliverables: ["Source", "Tests"], rubric_version: "web-frontend@1", level: "Competent" };
  assert(ProjectBriefSchema.safeParse(brief).success);
  assert(!ProjectBriefSchema.safeParse({ ...brief, private_note: "unexpected" }).success);
});

Deno.test("evidence excerpt size is bounded", () => {
  assert(EvidenceItemSchema.safeParse({ criterion: "Testing", evidence_ref: "bundle:tests", excerpt: "a".repeat(1200) }).success);
  assert(!EvidenceItemSchema.safeParse({ criterion: "Testing", evidence_ref: "bundle:tests", excerpt: "a".repeat(1201) }).success);
});

Deno.test("credential response rejects identity and extra fields", () => {
  const response = { credential: { credential_id: "0123456789abcdefab", issued_at: "2026-01-01", last_updated: "2026-01-02", skills: [], shared_fields: ["skills"] } };
  assert(CredentialResponseSchema.safeParse(response).success);
  assertEquals(CredentialResponseSchema.safeParse({ credential: { ...response.credential, student_id: "private" } }).success, false);
});
