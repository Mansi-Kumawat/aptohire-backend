import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { withHandler } from "../_shared/handler.ts";
import { hmacHex } from "../_shared/hash.ts";
import { isAgentModeConfigurable } from "../_shared/admin-config.ts";
import { isLocalSyntheticN8nOptedIn, isSafeN8nCallbackBaseUrl, isSafeN8nWebhookUrl } from "../_shared/agents/n8n-webhook.ts";
import { isSafeN8nAgentWebhookUrl } from "../_shared/agents/n8n-agent.ts";
import { AdminUpdateConfigInputSchema, AdminUpdateConfigOutputSchema } from "../_shared/schemas/admin-update-config.ts";

const handler = withHandler({
  auth: "jwt",
  roles: ["admin"],
  aal2: true,
  input: AdminUpdateConfigInputSchema,
  output: AdminUpdateConfigOutputSchema,
}, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const appEnv = Deno.env.get("APP_ENV");
  const webhookSecret = Deno.env.get("N8N_WEBHOOK_SECRET") ?? "";
  const callbackSecret = Deno.env.get("CALLBACK_SECRET") ?? "";
  const n8nConfigured = isLocalSyntheticN8nOptedIn(appEnv, Deno.env.get("N8N_ALLOW_SYNTHETIC")) &&
    Deno.env.get("N8N_AUDIT_ENABLED") === "true" &&
    isSafeN8nWebhookUrl(Deno.env.get("N8N_AUDIT_WEBHOOK_URL") ?? "", appEnv) &&
    isSafeN8nAgentWebhookUrl(Deno.env.get("N8N_ASSIGN_WEBHOOK_URL") ?? "", "assign") &&
    isSafeN8nAgentWebhookUrl(Deno.env.get("N8N_MATCH_WEBHOOK_URL") ?? "", "match") &&
    isSafeN8nAgentWebhookUrl(Deno.env.get("N8N_PROFILE_WEBHOOK_URL") ?? "", "profile") &&
    webhookSecret.length >= 32 && callbackSecret.length >= 32 && isSafeN8nCallbackBaseUrl(Deno.env.get("SUPABASE_URL") ?? "");
  if (input.key === "AGENT_MODE" && !isAgentModeConfigurable(
    input.value, appEnv, Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"), n8nConfigured,
  )) {
    if (input.value === "n8n") throw new HttpError("SERVICE_UNAVAILABLE", "The n8n audit adapter requires local synthetic opt-in and safe webhook configuration");
    throw new HttpError("FORBIDDEN", "Direct mode requires explicit local synthetic-data opt-in");
  }

  // This caller-scoped view evaluates private.is_admin() inside Postgres using the JWT claims.
  const { data: adminGate, error: gateError } = await auth.client.from("admin_counts_v")
    .select("pending_approvals").limit(1);
  if (gateError || !adminGate?.length) throw new HttpError("FORBIDDEN", "A current MFA-verified admin session is required");

  const admin = createAdminClient();
  const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!ratePepper) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  const actorHash = await hmacHex(ratePepper, auth.user.id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", {
    p_bucket: "admin-update-config", p_key_hash: actorHash, p_max: 20, p_window_seconds: 60,
  });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Configuration update rate limit reached", undefined, limits[0].retry_after);

  const { data, error } = await admin.rpc("admin_update_config", {
    p_actor_id: auth.user.id,
    p_key: input.key,
    p_value: input.value,
  });
  if (error) {
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "Admin authorization failed");
    if (error.code === "22023") throw new HttpError("VALIDATION_FAILED", "Configuration value is not permitted");
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "Configuration key is not configured");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not update configuration");
  }
  const row = (data as { config_key: string; updated_at: string }[] | null)?.[0];
  if (!row) throw new HttpError("SERVICE_UNAVAILABLE", "Configuration update did not return a result");
  return { body: { key: row.config_key as typeof input.key, updated_at: row.updated_at } };
});

Deno.serve(handler);
