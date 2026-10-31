export type ErrorCode =
  | "VALIDATION_FAILED" | "UNAUTHENTICATED" | "FORBIDDEN" | "NOT_FOUND" | "CONFLICT"
  | "ROLE_ALREADY_SET" | "ACCOUNT_EXISTS" | "RATE_LIMITED" | "QUOTA_EXCEEDED"
  | "KILL_SWITCH" | "SERVICE_UNAVAILABLE" | "SUBSCRIPTION_INACTIVE" | "NO_TEMPLATE"
  | "VIDEO_REQUIRED" | "VIDEO_TOO_LONG" | "MISSING_SKILLS" | "GRANT_EXPIRED" | "MFA_REQUIRED";

const statusByCode: Record<ErrorCode, number> = {
  VALIDATION_FAILED: 422, UNAUTHENTICATED: 401, FORBIDDEN: 403, NOT_FOUND: 404,
  CONFLICT: 409, ROLE_ALREADY_SET: 409, ACCOUNT_EXISTS: 409, RATE_LIMITED: 429,
  QUOTA_EXCEEDED: 429, KILL_SWITCH: 503, SERVICE_UNAVAILABLE: 503,
  SUBSCRIPTION_INACTIVE: 402, NO_TEMPLATE: 422, VIDEO_REQUIRED: 422, VIDEO_TOO_LONG: 422,
  MISSING_SKILLS: 422, GRANT_EXPIRED: 403, MFA_REQUIRED: 403,
};

export class HttpError extends Error {
  readonly status: number;
  constructor(readonly code: ErrorCode, message: string, readonly fields?: Record<string, string>, readonly retryAfter?: number) {
    super(message);
    this.name = "HttpError";
    this.status = statusByCode[code];
  }
  toResponse(headers?: HeadersInit): Response {
    const responseHeaders = new Headers(headers);
    if (this.status === 429 && this.retryAfter !== undefined) responseHeaders.set("Retry-After", String(Math.max(1, this.retryAfter)));
    return Response.json({ error: { code: this.code, message: this.message, ...(this.fields ? { fields: this.fields } : {}) } }, { status: this.status, headers: responseHeaders });
  }
}
