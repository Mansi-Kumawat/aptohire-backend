import { z } from "npm:zod@3.23.8";
import { authenticate, type AppRole, type AuthContext } from "./auth.ts";
import { corsHeaders, preflight } from "./cors.ts";
import { HttpError } from "./errors.ts";

export type HandlerContext = {
  request: Request;
  auth: AuthContext | null;
  /** Optional, allowlisted server config loaded before rate-limit/business logic. */
  config?: Readonly<Record<string, unknown>>;
};
export type HandlerResult<T> = { body?: T; status?: number };
type RateLimitHook<I> = (input: I, context: HandlerContext) => Promise<void>;
type ConfigHook = (context: HandlerContext) => Promise<Readonly<Record<string, unknown>>>;
type IdempotencyHook<I, O> = (
  input: I,
  context: HandlerContext,
  execute: () => Promise<HandlerResult<O>>,
) => Promise<HandlerResult<O>>;
type AuditHook<I, O> = (input: I, context: HandlerContext, result: HandlerResult<O>) => Promise<void>;

export interface HandlerOptions<I extends z.ZodType, O extends z.ZodType> {
  auth: "none" | "jwt";
  roles?: AppRole[];
  aal2?: boolean;
  input: I;
  output: O;
  /** Called after authentication/input validation and before business logic. Throw HttpError to fail closed. */
  loadConfig?: ConfigHook;
  /** Shared insertion point for keyed server-side rate limiting. */
  rateLimit?: RateLimitHook<z.infer<I>>;
  /** Wraps validated business execution with a durable, atomic idempotency store. */
  idempotent?: IdempotencyHook<z.infer<I>, z.infer<O>>;
  /** Called only after output validation; must write a minimized, allowlisted audit event. */
  audit?: AuditHook<z.infer<I>, z.infer<O>>;
}

export function withHandler<I extends z.ZodType, O extends z.ZodType>(
  options: HandlerOptions<I, O>,
  run: (input: z.infer<I>, context: HandlerContext) => Promise<HandlerResult<z.infer<O>>>,
): (request: Request) => Promise<Response> {
  return async (request) => {
    const headers = corsHeaders(request);
    const preflightResponse = preflight(request);
    if (preflightResponse) return preflightResponse;
    try {
      if (request.method !== "POST" && request.method !== "GET") throw new HttpError("VALIDATION_FAILED", "Method not allowed");
      let auth: AuthContext | null = null;
      if (options.auth === "jwt") {
        auth = await authenticate(request);
        if (options.roles?.length && !options.roles.includes(auth.role)) throw new HttpError("FORBIDDEN", "This account cannot use this operation");
        if (options.aal2 && auth.aal !== "aal2") throw new HttpError("MFA_REQUIRED", "Multi-factor authentication is required");
      }
      let raw: unknown = {};
      if (request.method === "POST") {
        const text = await request.text();
        try {
          raw = text ? JSON.parse(text) : {};
        } catch {
          throw new HttpError("VALIDATION_FAILED", "Request body must be valid JSON");
        }
      } else {
        raw = Object.fromEntries(new URL(request.url).searchParams.entries());
      }
      const parsed = options.input.safeParse(raw);
      if (!parsed.success) throw new HttpError("VALIDATION_FAILED", "Request validation failed", Object.fromEntries(parsed.error.issues.map((issue) => [issue.path.join(".") || "body", issue.message])));
      const context: HandlerContext = { request, auth };
      if (options.loadConfig) context.config = await options.loadConfig(context);
      if (options.rateLimit) await options.rateLimit(parsed.data, context);

      const execute = async (): Promise<HandlerResult<z.infer<O>>> => {
        const result = await run(parsed.data, context);
        const checked = options.output.safeParse(result.body ?? {});
        if (!checked.success) throw new HttpError("SERVICE_UNAVAILABLE", "Response validation failed");
        return { body: checked.data, status: result.status ?? 200 };
      };
      const result = options.idempotent
        ? await options.idempotent(parsed.data, context, execute)
        : await execute();
      // Revalidate cached/replayed bodies too; never return an untrusted idempotency record.
      const checked = options.output.safeParse(result.body ?? {});
      if (!checked.success) throw new HttpError("SERVICE_UNAVAILABLE", "Response validation failed");
      const validatedResult = { body: checked.data, status: result.status ?? 200 };
      if (options.audit) await options.audit(parsed.data, context, validatedResult);
      return Response.json(validatedResult.body, { status: validatedResult.status, headers });
    } catch (error) {
      if (error instanceof HttpError) return error.toResponse(headers);
      return new HttpError("SERVICE_UNAVAILABLE", "Service is temporarily unavailable").toResponse(headers);
    }
  };
}
