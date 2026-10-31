import { HttpError } from "./errors.ts";

export interface IdempotencyReceipt<T> {
  result: T;
  replayed: boolean;
}

export interface IdempotencyAdapter<T> {
  /** Implement with one atomic database operation; never use an in-memory cache in Edge Functions. */
  execute(input: {
    namespace: string;
    key: string;
    requestHash: string;
    operation: () => Promise<T>;
  }): Promise<IdempotencyReceipt<T>>;
}

export function validateIdempotencyKey(raw: string | null): string {
  const key = raw?.trim() ?? "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(key)) {
    throw new HttpError("VALIDATION_FAILED", "A valid Idempotency-Key header is required");
  }
  return key.toLowerCase();
}

function canonical(value: unknown): string {
  if (value === null || typeof value === "string" || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new HttpError("VALIDATION_FAILED", "Request cannot be fingerprinted");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (typeof value === "object") {
    const record = value as Record<string, unknown>;
    return `{${Object.keys(record).sort().map((key) => `${JSON.stringify(key)}:${canonical(record[key])}`).join(",")}}`;
  }
  throw new HttpError("VALIDATION_FAILED", "Request cannot be fingerprinted");
}

/** Stable SHA-256 request fingerprint; do not include secrets or unvalidated raw bodies. */
export async function requestFingerprint(input: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(canonical(input));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (value) => value.toString(16).padStart(2, "0")).join("");
}

export async function runIdempotently<T>(options: {
  adapter: IdempotencyAdapter<T>;
  namespace: string;
  key: string;
  validatedInput: unknown;
  operation: () => Promise<T>;
}): Promise<IdempotencyReceipt<T>> {
  if (!/^[a-z][a-z0-9-]{1,63}$/.test(options.namespace)) {
    throw new HttpError("VALIDATION_FAILED", "Idempotency namespace is invalid");
  }
  const key = validateIdempotencyKey(options.key);
  const requestHash = await requestFingerprint(options.validatedInput);
  return await options.adapter.execute({
    namespace: options.namespace,
    key,
    requestHash,
    operation: options.operation,
  });
}
