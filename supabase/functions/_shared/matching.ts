import { hmacHex } from "./hash.ts";

const BASE32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
export async function blindAlias(pepper: string, jobId: string, studentId: string): Promise<string> {
  const hex = await hmacHex(pepper, `${jobId}:${studentId}`);
  const first = Number.parseInt(hex.slice(0, 8), 16) >>> 0;
  const code = [27, 22, 17, 12, 7, 2].map((shift) => BASE32[(first >>> shift) & 31]).join("");
  return `Candidate ${code}`;
}

export function parseVector(value: unknown): number[] | null {
  let raw: unknown = value;
  if (typeof value === "string") {
    try { raw = JSON.parse(value); } catch { return null; }
  }
  if (!Array.isArray(raw) || raw.length !== 768 || !raw.every((v) => typeof v === "number" && Number.isFinite(v))) return null;
  return raw as number[];
}

export function cosineScore(a: number[] | null, b: number[] | null): number | null {
  if (!a || !b || a.length !== b.length || !a.length) return null;
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) { dot += a[i] * b[i]; normA += a[i] ** 2; normB += b[i] ** 2; }
  if (!normA || !normB) return null;
  const cosine = Math.max(-1, Math.min(1, dot / (Math.sqrt(normA) * Math.sqrt(normB))));
  return Math.round(((cosine + 1) * 50) * 100) / 100;
}
