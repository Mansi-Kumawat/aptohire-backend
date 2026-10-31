export const CURATED_NOTIFICATION_TAIL_MARKER = "## Runtime verification still required";

/** Keep human-reviewed behavioral notes when replacing the generated text-match table. */
export function mergeNotificationMatrix(generated, existing) {
  const markerIndex = existing.indexOf(CURATED_NOTIFICATION_TAIL_MARKER);
  const curatedTail = markerIndex < 0 ? "" : existing.slice(markerIndex).trimEnd();
  return [generated.trimEnd(), curatedTail].filter(Boolean).join("\n\n") + "\n";
}
