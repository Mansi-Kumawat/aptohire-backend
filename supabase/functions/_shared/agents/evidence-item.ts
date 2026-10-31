export type EvidenceKind = "video" | "file" | "repo" | "doc" | "live";
export interface EvidenceItem {
  ref: string;
  kind: EvidenceKind;
  label: string;
  pointer: string;
  excerpt?: string;
}

function safePath(value: string): boolean {
  return value.length > 0 && value.length <= 240 && !value.startsWith("/") && !value.includes("\\") &&
    !value.split("/").some((segment) => segment === "" || segment === "." || segment === "..") &&
    /^[A-Za-z0-9._/-]+$/.test(value);
}

/** Convert a server-manifested locator into the frozen frontend EvidenceItem. */
export function evidenceItemFromRef(ref: string, excerpt?: string): EvidenceItem | null {
  if (ref.length > 500) return null;
  const video = /^video:(\d{1,6}(?:\.\d{1,3})?)$/.exec(ref);
  if (video) {
    const seconds = Number(video[1]);
    if (!Number.isFinite(seconds) || seconds < 0 || seconds > 999_999) return null;
    const whole = Math.floor(seconds);
    const label = `Video ${String(Math.floor(whole / 60)).padStart(2, "0")}:${String(whole % 60).padStart(2, "0")}`;
    return { ref, kind: "video", label, pointer: video[1], ...(excerpt ? { excerpt } : {}) };
  }
  const pathRef = /^(repo|file|doc):(.+?)#L([1-9]\d{0,8})-L([1-9]\d{0,8})$/.exec(ref);
  if (pathRef) {
    const [, kind, path, start, end] = pathRef;
    if (!safePath(path) || Number(start) > Number(end)) return null;
    return { ref, kind: kind as "repo" | "file" | "doc", label: path, pointer: `${path}#L${start}-L${end}`, ...(excerpt ? { excerpt } : {}) };
  }
  const liveRef = /^live:(https:\/\/[^\s]+)$/.exec(ref);
  if (liveRef) {
    try {
      const url = new URL(liveRef[1]);
      if (url.protocol !== "https:" || url.username || url.password || !url.hostname) return null;
      return { ref, kind: "live", label: "Live site", pointer: url.toString(), ...(excerpt ? { excerpt } : {}) };
    } catch { return null; }
  }
  return null;
}
