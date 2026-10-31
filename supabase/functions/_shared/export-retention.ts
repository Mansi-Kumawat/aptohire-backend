const UUID = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
const EXPORT_PATH = new RegExp(`^${UUID}/exports/${UUID}\\.json$`, "i");

export function isSafeDataExportObjectPath(path: string): boolean {
  return EXPORT_PATH.test(path);
}

export function isExpiredDataExport(createdAt: string | null | undefined, cutoff: Date): boolean {
  if (!createdAt) return false;
  const timestamp = Date.parse(createdAt);
  return Number.isFinite(timestamp) && timestamp <= cutoff.getTime();
}
