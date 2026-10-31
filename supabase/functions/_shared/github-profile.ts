export async function boundedGitHubJson(response: Response, maxBytes = 1_000_000): Promise<unknown> {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 1 || maxBytes > 10_000_000) throw new RangeError("Invalid response byte limit");
  const declaredBytes = Number(response.headers.get("content-length") ?? "0");
  if (declaredBytes > maxBytes) {
    try { await response.body?.cancel(); } catch { /* close an oversized response best-effort */ }
    throw new Error("GITHUB_RESPONSE_TOO_LARGE");
  }
  const reader = response.body?.getReader();
  if (!reader) throw new Error("GITHUB_RESPONSE_EMPTY");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) {
        await reader.cancel();
        throw new Error("GITHUB_RESPONSE_TOO_LARGE");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  try { return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
  catch { throw new Error("GITHUB_RESPONSE_INVALID_JSON"); }
}

export function normalizedGitHubRepositoryUrl(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 512) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.hostname.toLowerCase() !== "github.com" || url.port ||
      url.username || url.password || url.search || url.hash) return null;
    const match = url.pathname.match(/^\/([A-Za-z0-9_.-]{1,39})\/([A-Za-z0-9_.-]{1,100})\/?$/);
    if (!match || match[1] === "." || match[1] === ".." || match[2] === "." || match[2] === "..") return null;
    return `https://github.com/${match[1]}/${match[2]}`;
  } catch {
    return null;
  }
}
