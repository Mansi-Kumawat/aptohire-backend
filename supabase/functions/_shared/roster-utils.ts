export function isSafeRosterCsvPath(path: string, universityId: string): boolean {
  const hasControlCharacter = [...path].some((character) => {
    const code = character.charCodeAt(0);
    return code < 32 || code === 127;
  });
  if (!universityId || path.startsWith("/") || path.includes("\\") || hasControlCharacter) return false;
  if (!path.startsWith(`${universityId}/`) || !/\.csv$/i.test(path)) return false;
  const segments = path.split("/");
  if (segments[0] !== universityId || segments.length < 2) return false;
  return segments.slice(1).every((segment) =>
    segment !== "" && segment !== "." && segment !== ".." && /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(segment)
  );
}

/** Treat either a repeated normalized ID or email as a duplicate, even if the other key differs. */
export function rosterStorageObjectSize(metadata: unknown): number | undefined {
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) return undefined;
  const rawSize = (metadata as Record<string, unknown>).size;
  const size = typeof rawSize === "number" ? rawSize : typeof rawSize === "string" && rawSize.trim() ? Number(rawSize) : NaN;
  return Number.isSafeInteger(size) && size >= 0 ? size : undefined;
}

export function isDuplicateRosterIdentity(seen: Set<string>, email: string | null, idHash: string | null): boolean {
  const keys = [
    ...(idHash ? [`id:${idHash}`] : []),
    ...(email ? [`email:${email.trim().toLowerCase()}`] : []),
  ];
  const duplicate = keys.some((key) => seen.has(key));
  for (const key of keys) seen.add(key);
  return duplicate;
}
