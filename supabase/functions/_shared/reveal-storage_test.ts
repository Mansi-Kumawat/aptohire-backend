import { assertEquals } from "jsr:@std/assert@1";
import { createRevealSignedUrl, createSafeDocumentRevealFile, createSafeSubmissionVideoRevealUrl, isSafeSubmissionVideoPath, REVEAL_SIGNED_URL_TTL_SECONDS, safeDocumentDisplayName } from "./reveal-storage.ts";

const student = "11111111-1111-4111-8111-111111111111";
const submission = "22222222-2222-4222-8222-222222222222";

Deno.test("document signing accepts only safe basenames below the owning student's submission prefix", () => {
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/portfolio.pdf`, student, submission), "portfolio.pdf");
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/my_file-v2.pdf`, student, submission), "my_file-v2.pdf");
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/../private.pdf`, student, submission), null);
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/folder/file.pdf`, student, submission), null);
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/.hidden`, student, submission), null);
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/x`.padEnd(`${student}/${submission}/`.length + 121, "a"), student, submission), null);
  assertEquals(safeDocumentDisplayName(`${student}/${submission}/other.pdf`, "33333333-3333-4333-8333-333333333333", submission), null);
  assertEquals(safeDocumentDisplayName(`${student}/33333333-3333-4333-8333-333333333333/other.pdf`, student, submission), null);
  assertEquals(safeDocumentDisplayName(null, student, submission), null);
});

Deno.test("video signing accepts only exact demo video names below the owning submission prefix", () => {
  assertEquals(isSafeSubmissionVideoPath(`${student}/${submission}/demo.mp4`, student, submission), true);
  assertEquals(isSafeSubmissionVideoPath(`${student}/${submission}/DEMO.WebM`, student, submission), true);
  assertEquals(isSafeSubmissionVideoPath(`${student}/${submission}/other.mp4`, student, submission), false);
  assertEquals(isSafeSubmissionVideoPath(`${student}/${submission}/demo.mp4/extra`, student, submission), false);
  assertEquals(isSafeSubmissionVideoPath(`${student}/33333333-3333-4333-8333-333333333333/demo.mov`, student, submission), false);
  assertEquals(isSafeSubmissionVideoPath(`${student}/${submission}/demo.mp4`, "33333333-3333-4333-8333-333333333333", submission), false);
  assertEquals(isSafeSubmissionVideoPath(undefined, student, submission), false);
});

Deno.test("reveal signed URLs use a fixed short TTL and do not surface storage errors", async () => {
  const calls: { path: string; ttl: number }[] = [];
  const okBucket = {
    createSignedUrl(path: string, expiresIn: number) {
      calls.push({ path, ttl: expiresIn });
      return Promise.resolve({ data: { signedUrl: "https://signed.example.test/file?token=synthetic" }, error: null });
    },
  };
  assertEquals(await createRevealSignedUrl(okBucket, `${student}/${submission}/portfolio.pdf`), "https://signed.example.test/file?token=synthetic");
  assertEquals(calls, [{ path: `${student}/${submission}/portfolio.pdf`, ttl: 600 }]);
  assertEquals(REVEAL_SIGNED_URL_TTL_SECONDS, 600);

  const failedBucket = {
    createSignedUrl() {
      return Promise.resolve({ data: null, error: new Error("private storage error") });
    },
  };
  assertEquals(await createRevealSignedUrl(failedBucket, `${student}/${submission}/portfolio.pdf`), null);

  const thrownBucket = {
    createSignedUrl() {
      return Promise.reject(new Error("private thrown storage detail"));
    },
  };
  assertEquals(await createRevealSignedUrl(thrownBucket, `${student}/${submission}/portfolio.pdf`), null);
});

Deno.test("document reveal helper validates ownership before invoking signed URL storage", async () => {
  const calls: { path: string; ttl: number }[] = [];
  const bucket = {
    createSignedUrl(path: string, expiresIn: number) {
      calls.push({ path, ttl: expiresIn });
      return Promise.resolve({ data: { signedUrl: "https://signed.example.test/document" }, error: null });
    },
  };
  assertEquals(await createSafeDocumentRevealFile(bucket, `${student}/${submission}/portfolio.pdf`, student, submission), {
    name: "portfolio.pdf",
    url: "https://signed.example.test/document",
  });
  assertEquals(await createSafeDocumentRevealFile(bucket, `${student}/other/portfolio.pdf`, student, submission), null);
  assertEquals(calls, [{ path: `${student}/${submission}/portfolio.pdf`, ttl: REVEAL_SIGNED_URL_TTL_SECONDS }]);
});

Deno.test("video reveal helper signs only the exact demo video under the owning submission", async () => {
  const calls: { path: string; ttl: number }[] = [];
  const bucket = {
    createSignedUrl(path: string, expiresIn: number) {
      calls.push({ path, ttl: expiresIn });
      return Promise.resolve({ data: { signedUrl: "https://signed.example.test/video" }, error: null });
    },
  };
  assertEquals(await createSafeSubmissionVideoRevealUrl(bucket, `${student}/${submission}/demo.mp4`, student, submission),
    "https://signed.example.test/video");
  assertEquals(await createSafeSubmissionVideoRevealUrl(bucket, `${student}/${submission}/other.mp4`, student, submission), null);
  assertEquals(calls, [{ path: `${student}/${submission}/demo.mp4`, ttl: REVEAL_SIGNED_URL_TTL_SECONDS }]);
});
