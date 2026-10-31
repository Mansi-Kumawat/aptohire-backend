import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { AdminApproveUniversityInputSchema, AdminApproveUniversityOutputSchema } from "../_shared/schemas/admin-approve-university.ts";

type ApprovalRow = { university_id: string; status: string; matched_existing: number; proposals_created: number };
const handler = withHandler({ auth: "jwt", roles: ["admin"], aal2: true, input: AdminApproveUniversityInputSchema, output: AdminApproveUniversityOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: gate, error: gateError } = await auth.client.from("admin_counts_v").select("pending_approvals").limit(1);
  if (gateError || !gate?.length) throw new HttpError("FORBIDDEN", "A current MFA-verified admin session is required");
  const admin = createAdminClient();
  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  const key = await hmacHex(pepper, auth.user.id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", { p_bucket: "admin-university-approve", p_key_hash: key, p_max: 30, p_window_seconds: 60 });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Admin action rate limit reached", undefined, limits[0].retry_after);
  const { data, error } = await admin.rpc("admin_university_action", {
    p_actor_id: auth.user.id, p_university_id: input.university_id, p_decision: input.decision, p_note: input.note ?? null,
  });
  if (error) {
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "Admin authorization failed");
    if (error.code === "22023") throw new HttpError("VALIDATION_FAILED", "University decision is not permitted");
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "University not found");
    if (error.code === "40001") throw new HttpError("CONFLICT", "A roster row was claimed concurrently; retry the decision");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not update university approval");
  }
  const row = (data as ApprovalRow[] | null)?.[0];
  if (!row) throw new HttpError("SERVICE_UNAVAILABLE", "University approval did not return a result");
  return { body: { university_id: row.university_id, status: row.status as "approved" | "rejected", matched_existing: row.matched_existing, proposals_created: row.proposals_created } };
});
Deno.serve(handler);
