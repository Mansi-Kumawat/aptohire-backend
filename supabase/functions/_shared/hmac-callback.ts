import { hmacHex } from "./hash.ts";

function constantTimeEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left); const b = new TextEncoder().encode(right);
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return difference === 0;
}

export async function verifyHmacCallback(
  secret: string,
  timestamp: string,
  rawBody: string,
  signature: string,
  nowMs = Date.now(),
): Promise<boolean> {
  const normalized = signature.replace(/^sha256=/i, "").toLowerCase();
  if (!secret || !/^\d{10}$/.test(timestamp) || !/^[a-f0-9]{64}$/.test(normalized)) return false;
  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds) || Math.abs(nowMs / 1000 - timestampSeconds) > 300) return false;
  return constantTimeEqual(await hmacHex(secret, `${timestamp}.${rawBody}`), normalized);
}
