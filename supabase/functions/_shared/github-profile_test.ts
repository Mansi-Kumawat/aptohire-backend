import { assertEquals, assertRejects } from "@std/assert";
import { boundedGitHubJson, normalizedGitHubRepositoryUrl } from "./github-profile.ts";

Deno.test("GitHub JSON bodies are size-bounded and parsed strictly", async () => {
  assertEquals(await boundedGitHubJson(new Response('{"ok":true}'), 100), { ok: true });
  await assertRejects(() => boundedGitHubJson(new Response("12345"), 4), Error, "GITHUB_RESPONSE_TOO_LARGE");
  await assertRejects(() => boundedGitHubJson(new Response("not-json"), 100), Error, "GITHUB_RESPONSE_INVALID_JSON");
  const streamedOversize = new Response(new ReadableStream<Uint8Array>({
    start(controller) { controller.enqueue(new Uint8Array(5)); controller.close(); },
  }));
  await assertRejects(() => boundedGitHubJson(streamedOversize, 4), Error, "GITHUB_RESPONSE_TOO_LARGE");
  await assertRejects(() => boundedGitHubJson(new Response(""), 0), RangeError, "Invalid response byte limit");
  await assertRejects(() => boundedGitHubJson(new Response(null), 100), Error, "GITHUB_RESPONSE_EMPTY");
});

Deno.test("GitHub repository proposal links allow only canonical GitHub repo URLs", () => {
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com/owner/repo"), "https://github.com/owner/repo");
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com/owner/repo/"), "https://github.com/owner/repo");
  assertEquals(normalizedGitHubRepositoryUrl("http://github.com/owner/repo"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com.attacker.test/owner/repo"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://user:pass@github.com/owner/repo"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com:443/owner/repo"), "https://github.com/owner/repo");
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com:8443/owner/repo"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com/owner/repo?next=https://attacker.test"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com/owner/repo/../../attacker"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com/owner/%2e%2e"), null);
  assertEquals(normalizedGitHubRepositoryUrl("https://github.com//owner/repo"), null);
  assertEquals(normalizedGitHubRepositoryUrl("javascript:alert(1)"), null);
  assertEquals(normalizedGitHubRepositoryUrl(42), null);
});
