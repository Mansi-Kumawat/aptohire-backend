const DOCUMENT_NAME_RE = /^[A-Za-z0-9_-][A-Za-z0-9._-]{0,119}$/;
const VIDEO_NAME_RE = /^demo\.(?:mp4|webm|mov)$/i;
export const REVEAL_SIGNED_URL_TTL_SECONDS = 600;

type SignedUrlBucket = {
  createSignedUrl(path: string, expiresIn: number): Promise<{
    data: { signedUrl: string } | null;
    error: unknown | null;
  }>;
};

/** Keep all scope-authorized reveal links short-lived and suppress storage error details. */
export async function createRevealSignedUrl(bucket: SignedUrlBucket, path: string): Promise<string | null> {
  try {
    const { data, error } = await bucket.createSignedUrl(path, REVEAL_SIGNED_URL_TTL_SECONDS);
    return error ? null : data?.signedUrl ?? null;
  } catch {
    return null;
  }
}

/** Return a safe display name only for a file stored below this student's submission prefix. */
export function safeDocumentDisplayName(path: unknown, studentId: string, submissionId: string): string | null {
  if (typeof path !== "string") return null;
  const prefix = `${studentId}/${submissionId}/`;
  if (!path.startsWith(prefix)) return null;
  const name = path.slice(prefix.length);
  if (!DOCUMENT_NAME_RE.test(name) || name === "." || name === "..") return null;
  return name;
}

/** Restrict signed video URLs to the exact demo-video object name under the owning submission. */
export function isSafeSubmissionVideoPath(path: unknown, studentId: string, submissionId: string): path is string {
  if (typeof path !== "string") return false;
  const prefix = `${studentId}/${submissionId}/`;
  if (!path.startsWith(prefix)) return false;
  return VIDEO_NAME_RE.test(path.slice(prefix.length));
}

/** Validate the owned document path before asking Storage to create a signed URL. */
export async function createSafeDocumentRevealFile(
  bucket: SignedUrlBucket,
  path: unknown,
  studentId: string,
  submissionId: string,
): Promise<{ name: string; url: string } | null> {
  const name = safeDocumentDisplayName(path, studentId, submissionId);
  if (!name || typeof path !== "string") return null;
  const url = await createRevealSignedUrl(bucket, path);
  return url ? { name, url } : null;
}

/** Validate the exact demo-video key before asking Storage to create a signed URL. */
export function createSafeSubmissionVideoRevealUrl(
  bucket: SignedUrlBucket,
  path: unknown,
  studentId: string,
  submissionId: string,
): Promise<string | null> {
  if (!isSafeSubmissionVideoPath(path, studentId, submissionId)) return Promise.resolve(null);
  return createRevealSignedUrl(bucket, path);
}
