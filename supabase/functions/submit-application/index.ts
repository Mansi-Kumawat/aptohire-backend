import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { withHandler } from "../_shared/handler.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { requestClientIp } from "../_shared/request-ip.ts";
import {
  applicationBusinessPayload,
  isFreeOrganizationEmail,
  SubmitApplicationInputSchema,
  SubmitApplicationOutputSchema,
  type SubmitApplicationInput,
} from "../_shared/schemas/submit-application.ts";

const MAX_BODY_BYTES = 32 * 1024;
const IdempotencyKeySchema = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type LimitRow = { allowed: boolean; retry_after: number };
type TurnstileResult = { success?: boolean };

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b));
    return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${canonicalJson(item)}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}

function fakeReference(): string {
  const alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return `AH-${Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("")}`;
}

async function consumeLimit(admin: ReturnType<typeof createAdminClient>, bucket: string, keyHash: string, max: number, seconds: number): Promise<void> {
  const { data, error } = await admin.rpc("consume_rate_limit", {
    p_bucket: bucket,
    p_key_hash: keyHash,
    p_max: max,
    p_window_seconds: seconds,
  });
  const rows = (data ?? []) as LimitRow[];
  if (error || !rows[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Application submission is temporarily unavailable");
  if (!rows[0].allowed) throw new HttpError("RATE_LIMITED", "Please wait before submitting another application", undefined, rows[0].retry_after);
}

async function verifyTurnstile(token: string | undefined): Promise<void> {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY");
  if (!secret) return;
  if (!token) throw new HttpError("VALIDATION_FAILED", "Complete the security check", { captcha_token: "Please complete the security check." });
  let response: Response;
  try {
    const form = new URLSearchParams({ secret, response: token });
    response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: form,
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    throw new HttpError("SERVICE_UNAVAILABLE", "Security verification is temporarily unavailable");
  }
  if (!response.ok) throw new HttpError("SERVICE_UNAVAILABLE", "Security verification is temporarily unavailable");
  let result: TurnstileResult;
  try {
    result = await response.json() as TurnstileResult;
  } catch {
    throw new HttpError("SERVICE_UNAVAILABLE", "Security verification is temporarily unavailable");
  }
  if (result.success !== true) throw new HttpError("VALIDATION_FAILED", "Complete the security check", { captcha_token: "Please complete the security check." });
}

const baseHandler = withHandler({
  auth: "none",
  input: SubmitApplicationInputSchema,
  output: SubmitApplicationOutputSchema,
}, async (input: SubmitApplicationInput, context) => {
  const idempotencyKey = context.request.headers.get("Idempotency-Key")?.trim();
  if (!idempotencyKey || !IdempotencyKeySchema.test(idempotencyKey)) {
    throw new HttpError("VALIDATION_FAILED", "A valid Idempotency-Key header is required", { "Idempotency-Key": "Generate one UUID per form instance." });
  }
  const ip = requestClientIp(context.request);
  if (!ip) throw new HttpError("SERVICE_UNAVAILABLE", "Request origin could not be verified");
  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Application submission is not configured");
  const admin = createAdminClient();
  const email = input.type === "university" ? input.contact_email : input.work_email;
  const [ipHash, emailHash] = await Promise.all([
    hmacHex(pepper, `submit-application:ip:${ip}`),
    hmacHex(pepper, `submit-application:email:${email}`),
  ]);
  // Honeypot submissions look successful to bots but persist no application or idempotency record.
  // Keep them rate limited because they do not have a legitimate receipt to replay.
  if (input.hp.length > 0) {
    await consumeLimit(admin, "submit-application-ip", ipHash, 5, 3600);
    await consumeLimit(admin, "submit-application-email", emailHash, 3, 86400);
    return { status: 202, body: { reference: fakeReference(), status: "received" as const } };
  }
  if (input.type === "organization" && isFreeOrganizationEmail(input.work_email)) {
    await consumeLimit(admin, "submit-application-ip", ipHash, 5, 3600);
    await consumeLimit(admin, "submit-application-email", emailHash, 3, 86400);
    throw new HttpError("VALIDATION_FAILED", "Use your organization email address", {
      work_email: "Common personal email providers are not accepted for organization applications.",
    });
  }

  const payload = applicationBusinessPayload(input);
  const payloadJson = canonicalJson(payload);
  const requestHash = await hmacHex(pepper, `submit-application:body:${payloadJson}`);
  const key = idempotencyKey.toLowerCase();
  const { data: replay, error: lookupError } = await admin.rpc("lookup_submit_application_idempotency", {
    p_key: key,
    p_request_hash: requestHash,
  });
  if (lookupError?.code === "23505") throw new HttpError("CONFLICT", "This Idempotency-Key was already used for different form data");
  if (lookupError) throw new HttpError("SERVICE_UNAVAILABLE", "Application submission is temporarily unavailable");
  if (replay !== null && replay !== undefined) {
    const checked = SubmitApplicationOutputSchema.safeParse(replay);
    if (!checked.success) throw new HttpError("SERVICE_UNAVAILABLE", "Stored application receipt is invalid");
    return { status: 202, body: checked.data };
  }

  // A legitimate idempotent retry must replay its receipt even after consuming its quota.
  await consumeLimit(admin, "submit-application-ip", ipHash, 5, 3600);
  await consumeLimit(admin, "submit-application-email", emailHash, 3, 86400);
  await verifyTurnstile(input.captcha_token);
  const { data: result, error } = await admin.rpc("submit_application", {
    p_key: key,
    p_request_hash: requestHash,
    p_payload: payload,
  });
  if (error?.code === "23505") throw new HttpError("CONFLICT", "This Idempotency-Key was already used for different form data");
  if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Application submission is temporarily unavailable");
  const checked = SubmitApplicationOutputSchema.safeParse(result);
  if (!checked.success) throw new HttpError("SERVICE_UNAVAILABLE", "Application receipt could not be created");
  return { status: 202, body: checked.data };
});

async function boundedHandler(request: Request): Promise<Response> {
  const headers = corsHeaders(request);
  const preflightResponse = preflight(request);
  if (preflightResponse) return preflightResponse;
  if (request.method === "POST") {
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (declaredLength > MAX_BODY_BYTES) return new HttpError("VALIDATION_FAILED", "Application request is too large").toResponse(headers);
    const reader = request.clone().body?.getReader();
    if (reader) {
      let size = 0;
      try {
        while (true) {
          const part = await reader.read();
          if (part.done) break;
          size += part.value.byteLength;
          if (size > MAX_BODY_BYTES) {
            await reader.cancel();
            return new HttpError("VALIDATION_FAILED", "Application request is too large").toResponse(headers);
          }
        }
      } catch {
        return new HttpError("VALIDATION_FAILED", "Application request could not be read").toResponse(headers);
      }
    }
  }
  return baseHandler(request);
}

Deno.serve(boundedHandler);
