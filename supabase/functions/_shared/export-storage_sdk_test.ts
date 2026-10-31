import { createClient } from "@supabase/supabase-js";
import { assertEquals, assertStringIncludes } from "@std/assert";
import {
  createDataExportSignedUrl,
  DATA_EXPORT_SIGNED_URL_TTL_SECONDS,
  removeDataExportObject,
} from "./export-storage.ts";

const owner = "11111111-1111-4111-8111-111111111111";
const exportPath = `${owner}/exports/22222222-2222-4222-8222-222222222222.json`;

type CapturedRequest = { url: string; method: string; body: unknown };

Deno.test("export helpers interoperate with the Supabase Storage SDK request contract", async () => {
  const requests: CapturedRequest[] = [];
  const fakeFetch: typeof fetch = async (input, init) => {
    const request = input instanceof Request ? input : null;
    const url = request?.url ?? String(input);
    const method = init?.method ?? request?.method ?? "GET";
    const rawBody = init?.body ?? (request ? await request.clone().text() : null);
    requests.push({ url, method, body: typeof rawBody === "string" ? JSON.parse(rawBody) : rawBody });

    if (url.includes("/object/sign/")) {
      return new Response(JSON.stringify({ signedURL: `/object/sign/data-exports/${exportPath}?token=synthetic` }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response("[]", { status: 200, headers: { "Content-Type": "application/json" } });
  };
  const client = createClient("http://storage.example.test", "synthetic-anon-key", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: fakeFetch },
  });
  const bucket = client.storage.from("data-exports");

  const signedUrl = await createDataExportSignedUrl(bucket, exportPath);
  assertStringIncludes(signedUrl ?? "", "token=synthetic");
  assertEquals(requests.length, 1);
  assertStringIncludes(requests[0].url, `/storage/v1/object/sign/data-exports/${exportPath}`);
  assertEquals(requests[0].method, "POST");
  assertEquals(requests[0].body, { expiresIn: DATA_EXPORT_SIGNED_URL_TTL_SECONDS });

  assertEquals(await createDataExportSignedUrl(bucket, `${owner}/exports/../private.json`), null);
  assertEquals(requests.length, 1, "invalid owner paths must not reach the SDK/network layer");

  assertEquals(await removeDataExportObject(bucket, exportPath), true);
  assertEquals(requests.length, 2);
  assertStringIncludes(requests[1].url, "/storage/v1/object/data-exports");
  assertEquals(requests[1].method, "DELETE");
  assertEquals(requests[1].body, { prefixes: [exportPath] });
});
