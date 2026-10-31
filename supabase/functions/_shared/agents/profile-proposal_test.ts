import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { cleanProfileText, githubProposal, linkedinProposal } from "./profile-proposal.ts";

Deno.test("profile text normalization removes direct contacts, links, markup and controls", () => {
  const fakeGithubToken = "ghp_" + "abcdefghijklmnopqrstuvwxyz1234567890";
  const cleaned = cleanProfileText(`Ｆｕｌｌ-stack dev\u0000 at person@example.test +1 (415) 555-0132 https://example.test ${fakeGithubToken} password=hunter2 <b>React</b>`);
  assertStringIncludes(cleaned, "Full-stack dev");
  assertStringIncludes(cleaned, "[redacted email]");
  assertStringIncludes(cleaned, "[redacted phone]");
  assertStringIncludes(cleaned, "[redacted URL]");
  assertStringIncludes(cleaned, "React");
  assertEquals(cleaned.includes("person@example.test"), false);
  assertEquals(cleaned.includes("415"), false);
  assertEquals(cleaned.includes(fakeGithubToken), false);
  assertEquals(cleaned.includes("hunter2"), false);
  assertStringIncludes(cleaned, "[redacted secret]");
  assertStringIncludes(cleaned, "password=[redacted]");
  assertEquals(cleanProfileText("x".repeat(50), 12).length, 12);
});

Deno.test("GitHub proposal excludes forked, archived and non-canonical repository URLs", () => {
  const proposal = githubProposal(
    { bio: "Frontend builder at person@example.test", login: "fictional-user" },
    [
      { name: "portfolio", description: "React app https://outside.test", language: "TypeScript", html_url: "https://github.com/fictional-user/portfolio" },
      { name: "forked", language: "Go", fork: true, html_url: "https://github.com/fictional-user/forked" },
      { name: "archived", language: "Rust", archived: true, html_url: "https://github.com/fictional-user/archived" },
      { name: "bad", language: "Python", html_url: "https://evil.test/fictional-user/bad" },
    ],
  );
  assertEquals(proposal.source, "github");
  assertEquals(proposal.changes.find((change) => change.field === "headline")?.value, "Frontend builder at [redacted email]");
  const projects = proposal.changes.filter((change) => change.field === "project_candidate");
  assertEquals(projects.length, 1);
  assertEquals((projects[0].value as { url: string }).url, "https://github.com/fictional-user/portfolio");
  assertEquals(proposal.changes.some((change) => JSON.stringify(change).includes("outside.test")), false);
  assertEquals(proposal.changes.filter((change) => change.field === "skills_interest").length, 1);
});

Deno.test("LinkedIn proposal extracts bounded labeled fields and redacts contact values", () => {
  const proposal = linkedinProposal([
    "Headline: React developer, person@example.test",
    "Top skills: React, TypeScript",
    "Experience: Built dashboards; call +1 415 555 0132",
    "Education: Fictional University",
    "https://linkedin.example.test/profile",
  ].join("\n"));
  assertEquals(proposal.source, "linkedin_export");
  assertEquals(proposal.changes.length, 4);
  const serialized = JSON.stringify(proposal);
  assertEquals(serialized.includes("person@example.test"), false);
  assertEquals(serialized.includes("415 555"), false);
  assertEquals(serialized.includes("linkedin.example.test"), false);
  assertStringIncludes(serialized, "[redacted email]");
  assertStringIncludes(serialized, "[redacted phone]");
  assertStringIncludes(serialized, "Fictional University");
});
