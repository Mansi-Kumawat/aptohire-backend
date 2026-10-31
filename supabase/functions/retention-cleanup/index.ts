import { createAdminClient } from "../_shared/admin.ts";
import { constantTimeSecretEqual } from "../_shared/internal-secret.ts";
import { confirmedRemovedPaths, isSafeVideoObjectPath } from "../_shared/retention-path.ts";
import { isSafeDataExportObjectPath } from "../_shared/export-retention.ts";

const jsonHeaders = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };
const responseError = (status: number, code: string, message: string) => Response.json({ error: { code, message } }, { status, headers: jsonHeaders });

Deno.serve(async (request) => {
  if (request.method !== "POST") return responseError(405, "VALIDATION_FAILED", "POST required");
  const secret = Deno.env.get("RETENTION_CLEANUP_SECRET") ?? "";
  const supplied = request.headers.get("x-retention-secret") ?? "";
  if (!secret) return responseError(503, "SERVICE_UNAVAILABLE", "Cleanup is not configured");
  if (!constantTimeSecretEqual(secret, supplied)) return responseError(401, "UNAUTHENTICATED", "Invalid internal credential");

  try {
    const reader = request.body?.getReader();
    const chunks: Uint8Array[] = [];
    let byteCount = 0;
    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        byteCount += value.byteLength;
        if (byteCount > 1024) {
          await reader.cancel();
          return responseError(413, "VALIDATION_FAILED", "Request is too large");
        }
        chunks.push(value);
      }
    }
    const bodyBytes = new Uint8Array(byteCount);
    let offset = 0;
    for (const chunk of chunks) { bodyBytes.set(chunk, offset); offset += chunk.byteLength; }
    const body = new TextDecoder().decode(bodyBytes);
    if (body.trim() && body.trim() !== "{}") return responseError(422, "VALIDATION_FAILED", "Expected an empty JSON object");
  } catch {
    return responseError(422, "VALIDATION_FAILED", "Request body could not be read");
  }

  try {
    const admin = createAdminClient();
    const { data, error } = await admin.rpc("expired_video_object_paths", { p_limit: 500 });
    if (error) throw new Error("PATH_LIST_FAILED");
    const rows = (data ?? []) as { object_path: unknown }[];
    const paths = rows.map((row) => row.object_path);
    if (paths.some((path) => typeof path !== "string" || !isSafeVideoObjectPath(path))) throw new Error("UNEXPECTED_STORAGE_PATH");
    const safePaths = paths as string[];
    let removed = 0;
    let referencesCleared = 0;
    for (let start = 0; start < safePaths.length; start += 100) {
      const batch = safePaths.slice(start, start + 100);
      const { data: removedObjects, error: removeError } = await admin.storage.from("videos").remove(batch);
      if (removeError || !Array.isArray(removedObjects)) throw new Error("STORAGE_DELETE_FAILED");
      const removedBatch = confirmedRemovedPaths(batch, removedObjects.map((object) => object.name));
      if (removedBatch.length) {
        const { data: cleared, error: clearError } = await admin.rpc("complete_video_retention_cleanup", { p_paths: removedBatch });
        if (clearError || typeof cleared !== "number") throw new Error("REFERENCE_CLEANUP_FAILED");
        removed += removedBatch.length;
        referencesCleared += cleared;
      }
      if (removedBatch.length !== batch.length) throw new Error("STORAGE_DELETE_INCOMPLETE");
    }

    const { data: exportRows, error: exportListError } = await admin.rpc("expired_data_export_object_paths", { p_limit: 500 });
    if (exportListError) throw new Error("EXPORT_PATH_LIST_FAILED");
    const exportPaths = ((exportRows ?? []) as { object_path: unknown }[]).map((row) => row.object_path);
    if (exportPaths.some((path) => typeof path !== "string" || !isSafeDataExportObjectPath(path))) throw new Error("UNEXPECTED_EXPORT_PATH");
    const safeExportPaths = exportPaths as string[];
    let exportsRemoved = 0;
    let exportDeleteFailed = false;
    for (let start = 0; start < safeExportPaths.length; start += 100) {
      const batch = safeExportPaths.slice(start, start + 100);
      const { data: removedObjects, error: removeError } = await admin.storage.from("data-exports").remove(batch);
      if (removeError || !Array.isArray(removedObjects)) { exportDeleteFailed = true; break; }
      const removedCount = confirmedRemovedPaths(batch, removedObjects.map((object) => object.name)).length;
      exportsRemoved += removedCount;
      if (removedCount !== batch.length) { exportDeleteFailed = true; break; }
    }
    const { data: auditedCount, error: exportAuditError } = await admin.rpc("complete_data_export_retention_cleanup", { p_removed: exportsRemoved });
    if (exportAuditError || auditedCount !== exportsRemoved) throw new Error("EXPORT_CLEANUP_AUDIT_FAILED");
    if (exportDeleteFailed) throw new Error("EXPORT_STORAGE_DELETE_FAILED");

    return Response.json({ removed, references_cleared: referencesCleared, export_files_removed: exportsRemoved }, { status: 200, headers: jsonHeaders });
  } catch {
    return responseError(503, "SERVICE_UNAVAILABLE", "Retention cleanup could not complete");
  }
});
