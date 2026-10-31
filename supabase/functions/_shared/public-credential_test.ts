import { assertEquals, assert } from "@std/assert";
import { buildPublicCredentialResponse } from "./public-credential.ts";

const source = {
  credentialId: "a1b2c3d4e5f6a7b8c9",
  fullName: "Aarav Sharma",
  createdAt: "2026-01-02T00:00:00.000Z",
  updatedAt: "2026-03-04T00:00:00.000Z",
  skills: [
    { name: "React", score: 82, level: "Proficient", verified: true, share_ok: true, pending_review: false, updated_at: "2026-02-10T12:00:00.000Z" },
    { name: "Hidden", score: 50, level: "Emerging", verified: true, share_ok: false, pending_review: false, updated_at: "2026-02-11T12:00:00.000Z" },
    { name: "Under review", score: 70, level: "Competent", verified: true, share_ok: true, pending_review: true, updated_at: "2026-02-12T12:00:00.000Z" },
    { name: "Unverified", score: 90, level: "Advanced", verified: false, share_ok: true, pending_review: false, updated_at: "2026-02-13T12:00:00.000Z" },
  ],
  affiliation: { label: "Uni A", verification: "roster" as const },
};

Deno.test("public credential visibility matrix exposes only selected fields", () => {
  const options = ["name", "university", "skills", "levels", "scores"];
  for (let mask = 0; mask < 2 ** options.length; mask++) {
    const selected = options.filter((_, index) => (mask & (1 << index)) !== 0);
    const { credential } = buildPublicCredentialResponse({ ...source, sharedFields: selected });
    assertEquals(credential.shared_fields, selected);
    assertEquals("display_name" in credential, selected.includes("name"));
    assertEquals("affiliation" in credential, selected.includes("university"));
    if (!selected.includes("skills")) assertEquals(credential.skills, []);
    else {
      assertEquals(credential.skills.length, 1);
      assertEquals(credential.skills[0].name, "React");
      assertEquals(credential.skills[0].level, selected.includes("levels") ? "Proficient" : "Verified");
      assertEquals("score" in credential.skills[0], selected.includes("scores"));
      assertEquals(credential.skills[0].verified, true);
    }
    assertEquals("student_id" in credential, false);
    assertEquals("email" in credential, false);
    assertEquals("photo" in credential, false);
    assertEquals("file_path" in credential, false);
  }
});

Deno.test("public credential excludes unknown visibility labels and computes dates from eligible skills only", () => {
  const { credential } = buildPublicCredentialResponse({ ...source, sharedFields: ["skills", "internal_id"], fullName: "Grace" });
  assertEquals(credential.shared_fields, ["skills"]);
  assertEquals(credential.issued_at, "2026-02-10");
  assertEquals(credential.last_updated, "2026-02-10");
  assertEquals(credential.skills[0].verified_on, "2026-02-10");
  assertEquals("display_name" in credential, false);
});

Deno.test("public credential schema is strict about extra response properties", () => {
  const result = buildPublicCredentialResponse({ ...source, sharedFields: ["skills"] });
  assert(!("student_id" in result.credential));
});
