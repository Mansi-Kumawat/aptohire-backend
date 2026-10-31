import { assertEquals } from "jsr:@std/assert@1";
import { createDataExportSignedUrl, DATA_EXPORT_SIGNED_URL_TTL_SECONDS, removeDataExportObject } from "./export-storage.ts";

const owner = "11111111-1111-4111-8111-111111111111";
const exportPath = `${owner}/exports/22222222-2222-4222-8222-222222222222.json`;

Deno.test("data export signer validates owner path and uses the fixed 600-second TTL", async () => {
  const calls: { path: string; ttl: number }[] = [];
  const bucket = {
    createSignedUrl(path: string, expiresIn: number) {
      calls.push({ path, ttl: expiresIn });
      return Promise.resolve({ data: { signedUrl: "https://signed.example.test/export" }, error: null });
    },
    remove() { return Promise.resolve({ error: null }); },
  };
  assertEquals(await createDataExportSignedUrl(bucket, exportPath), "https://signed.example.test/export");
  assertEquals(calls, [{ path: exportPath, ttl: DATA_EXPORT_SIGNED_URL_TTL_SECONDS }]);
  assertEquals(await createDataExportSignedUrl(bucket, `${owner}/exports/../../private.json`), null);
  assertEquals(calls.length, 1);
});

Deno.test("data export storage errors and thrown failures are suppressed and safe cleanup is bounded", async () => {
  const failedBucket = {
    createSignedUrl() { return Promise.resolve({ data: null, error: new Error("private storage detail") }); },
    remove(paths: string[]) { return Promise.resolve({ error: paths[0] === exportPath ? null : new Error("bad path") }); },
  };
  assertEquals(await createDataExportSignedUrl(failedBucket, exportPath), null);
  assertEquals(await removeDataExportObject(failedBucket, exportPath), true);
  assertEquals(await removeDataExportObject(failedBucket, `${owner}/exports/../bad.json`), false);
  const thrownBucket = {
    createSignedUrl() { return Promise.reject(new Error("private thrown detail")); },
    remove() { return Promise.reject(new Error("private remove detail")); },
  };
  assertEquals(await createDataExportSignedUrl(thrownBucket, exportPath), null);
  assertEquals(await removeDataExportObject(thrownBucket, exportPath), false);
});
