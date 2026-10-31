const pathPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/demo\.(?:mp4|webm|mov)$/i;

export function isSafeVideoObjectPath(path: string): boolean {
  return pathPattern.test(path);
}

export function isOwnedVideoObjectPath(path: string, studentId: string, submissionId: string): boolean {
  if (!isSafeVideoObjectPath(path)) return false;
  const [pathStudentId, pathSubmissionId] = path.split("/");
  return pathStudentId === studentId && pathSubmissionId === submissionId;
}

export function confirmedRemovedPaths(requested: readonly string[], removedNames: readonly unknown[]): string[] {
  const confirmed = new Set(removedNames.filter((name): name is string => typeof name === "string"));
  return requested.filter((path) => confirmed.has(path));
}
