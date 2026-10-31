import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { HttpError } from "./errors.ts";
import { hmacHex } from "./hash.ts";

export interface RateLimitOptions {
  bucket: string;
  subject: string;
  pepper: string;
  max: number;
  windowSeconds: number;
}

/** Consume the database's atomic, service-role-only limiter using an HMAC key (never raw identity/IP). */
export async function enforceRateLimit(client: SupabaseClient, options: RateLimitOptions): Promise<void> {
  if (!/^[a-z0-9][a-z0-9:_-]{0,63}$/i.test(options.bucket) || !options.subject || !options.pepper ||
    !Number.isSafeInteger(options.max) || options.max < 1 || !Number.isSafeInteger(options.windowSeconds) || options.windowSeconds < 1) {
    throw new HttpError("SERVICE_UNAVAILABLE", "Rate limiter is unavailable");
  }
  const keyHash = await hmacHex(options.pepper, `${options.bucket}:${options.subject}`);
  const { data, error } = await client.rpc("consume_rate_limit", {
    p_bucket: options.bucket,
    p_key_hash: keyHash,
    p_max: options.max,
    p_window_seconds: options.windowSeconds,
  });
  const row = Array.isArray(data) ? data[0] as { allowed?: unknown; retry_after?: unknown } | undefined : undefined;
  if (error || !row || typeof row.allowed !== "boolean") {
    throw new HttpError("SERVICE_UNAVAILABLE", "Rate limiter is unavailable");
  }
  if (!row.allowed) {
    const retryAfter = typeof row.retry_after === "number" && Number.isFinite(row.retry_after) && row.retry_after > 0
      ? row.retry_after
      : undefined;
    throw new HttpError("RATE_LIMITED", "Request limit reached", undefined, retryAfter);
  }
}
