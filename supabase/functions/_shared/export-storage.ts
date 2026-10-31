import { isSafeDataExportObjectPath } from "./export-retention.ts";

export const DATA_EXPORT_SIGNED_URL_TTL_SECONDS = 600;

type ExportStorageBucket = {
  createSignedUrl(path: string, expiresIn: number): Promise<{
    data: { signedUrl: string } | null;
    error: unknown | null;
  }>;
  remove(paths: string[]): Promise<{ error: unknown | null }>;
};

/** Sign only the exact owner-scoped export-object key; never surface Storage error details. */
export async function createDataExportSignedUrl(bucket: ExportStorageBucket, path: string): Promise<string | null> {
  if (!isSafeDataExportObjectPath(path)) return null;
  try {
    const { data, error } = await bucket.createSignedUrl(path, DATA_EXPORT_SIGNED_URL_TTL_SECONDS);
    return error ? null : data?.signedUrl ?? null;
  } catch {
    return null;
  }
}

/** Best-effort cleanup of an owner-scoped export if signing or subsequent audit logging fails. */
export async function removeDataExportObject(bucket: ExportStorageBucket, path: string): Promise<boolean> {
  if (!isSafeDataExportObjectPath(path)) return false;
  try {
    const { error } = await bucket.remove([path]);
    return !error;
  } catch {
    return false;
  }
}
