import { createAdminClient } from "../_shared/admin.ts";
import { containsContactDetails } from "../_shared/contact.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { AdminReviewAuditInputSchema, AdminReviewAuditOutputSchema } from "../_shared/schemas/admin-review-audit.ts";

type ReviewRow = { audit_id: string; review_status: string; reviewed_score: number };
const handler = withHandler({ auth: "jwt", roles: ["admin"], aal2: true, input: AdminReviewAuditInputSchema, output: AdminReviewAuditOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  if (containsContactDetails(input.note)) throw new HttpError("VALIDATION_FAILED", "Review notes cannot contain contact details", { note: "Remove email addresses, phone numbers, URLs, and social handles." });
  const { data: gate, error: gateError } = await auth.client.from("admin_counts_v").select("pending_reviews").limit(1);
  if (gateError || !gate?.length) throw new HttpError("FORBIDDEN", "A current MFA-verified admin session is required");
  const admin = createAdminClient();
  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  const actorHash = await hmacHex(pepper, auth.user.id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", { p_bucket: "admin-review-audit", p_key_hash: actorHash, p_max: 60, p_window_seconds: 60 });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Audit review rate limit reached", undefined, limits[0].retry_after);
  const { data, error } = await admin.rpc("admin_review_audit", {
    p_actor_id: auth.user.id,
    p_audit_id: input.audit_id,
    p_decision: input.decision,
    p_adjusted_scores: input.decision === "adjust" ? input.adjusted_scores : null,
    p_note: input.note,
  });
  if (error) {
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "Admin authorization failed");
    if (error.code === "22023") throw new HttpError("VALIDATION_FAILED", "Review input is not permitted");
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "Pending audit not found");
    if (error.code === "40001") throw new HttpError("CONFLICT", "Audit is no longer awaiting review");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not complete audit review");
  }
  const row = (data as ReviewRow[] | null)?.[0];
  if (!row) throw new HttpError("SERVICE_UNAVAILABLE", "Audit review did not return a result");
  return { body: { audit_id: row.audit_id, review_status: row.review_status as "complete", reviewed_score: Number(row.reviewed_score) } };
});
Deno.serve(handler);
