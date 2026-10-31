import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { assertEquals } from "jsr:@std/assert@1";
import { createDataExportSignedUrl, removeDataExportObject } from "./export-storage.ts";

function localStorageOrigin(value: string): string | null {
  try {
    const url = new URL(value);
    if (url.protocol !== "http:" || !["localhost", "127.0.0.1", "[::1]"].includes(url.hostname) ||
        url.username || url.password || url.search || url.hash || url.pathname !== "/") return null;
    return url.origin;
  } catch {
    return null;
  }
}

function getSafeLocalStorageConfig(): { url: string; serviceRoleKey: string } | null {
  if (Deno.env.get("APP_ENV") !== "local") return null;
  const urlValue = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!urlValue || !serviceRoleKey) return null;
  const url = localStorageOrigin(urlValue);
  return url ? { url, serviceRoleKey } : null;
}

Deno.test("local Storage integration accepts only clean loopback HTTP origins", () => {
  assertEquals(localStorageOrigin("http://127.0.0.1:54321"), "http://127.0.0.1:54321");
  assertEquals(localStorageOrigin("http://localhost:54321"), "http://localhost:54321");
  assertEquals(localStorageOrigin("http://[::1]:54321"), "http://[::1]:54321");
  assertEquals(localStorageOrigin("https://storage.example.test"), null);
  assertEquals(localStorageOrigin("http://example.test"), null);
  assertEquals(localStorageOrigin("http://localhost:54321/path"), null);
  assertEquals(localStorageOrigin("http://user:pass@localhost:54321"), null);
  assertEquals(localStorageOrigin("http://localhost:54321/?redirect=https://example.test"), null);
});

const localConfig = getSafeLocalStorageConfig();

Deno.test({
  name: "local Supabase Storage accepts owner-scoped export upload, signing, fetch, and cleanup",
  ignore: localConfig === null,
  fn: async () => {
    if (!localConfig) throw new Error("Local-only Storage integration precondition was not met");
    const client = createClient(localConfig.url, localConfig.serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: (input, init) => fetch(input, {
          ...init,
          signal: init?.signal ?? AbortSignal.timeout(5_000),
        }),
      },
    });
    const studentId = crypto.randomUUID();
    const exportId = crypto.randomUUID();
    const path = `${studentId}/exports/${exportId}.json`;
    const contents = JSON.stringify({ schema_version: 1, synthetic: true });
    const bucket = client.storage.from("data-exports");

    const { error: uploadError } = await bucket.upload(path, new Blob([contents], { type: "application/json" }), {
      contentType: "application/json",
      upsert: false,
    });
    if (uploadError) throw new Error(`Local Storage fixture upload failed: ${uploadError.message}`);

    try {
      const signedUrl = await createDataExportSignedUrl(bucket, path);
      if (!signedUrl) throw new Error("Owner-scoped export signing failed");
      const signed = new URL(signedUrl);
      assertEquals(signed.origin, localConfig.url, "Storage must not return a signed URL for a non-local origin");
      assertEquals(signed.username, "");
      assertEquals(signed.password, "");
      if (!signed.pathname.startsWith("/storage/v1/object/sign/data-exports/")) {
        throw new Error("Storage returned a signed URL outside the private data-exports object endpoint");
      }
      const response = await fetch(signed, { signal: AbortSignal.timeout(5_000) });
      assertEquals(response.status, 200);
      assertEquals(await response.text(), contents);
    } finally {
      assertEquals(await removeDataExportObject(bucket, path), true, "synthetic export fixture must be cleaned up");
    }
  },
});
