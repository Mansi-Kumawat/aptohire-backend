import { createAdminClient } from "../_shared/admin.ts";
import { containsContactDetails } from "../_shared/contact.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { AdminDecideTicketInputSchema, AdminDecideTicketOutputSchema } from "../_shared/schemas/admin-decide-ticket.ts";

type TicketActionRow = { ticket_id: string; status: string; decision: string | null };
const handler = withHandler({ auth: "jwt", roles: ["admin"], aal2: true, input: AdminDecideTicketInputSchema, output: AdminDecideTicketOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  if (input.action === "decide" && input.note && containsContactDetails(input.note)) {
    throw new HttpError("VALIDATION_FAILED", "Ticket notes cannot contain contact details", { note: "Remove email addresses, phone numbers, URLs, and social handles." });
  }
  const { data: gate, error: gateError } = await auth.client.from("admin_counts_v").select("open_tickets").limit(1);
  if (gateError || !gate?.length) throw new HttpError("FORBIDDEN", "A current MFA-verified admin session is required");
  const admin = createAdminClient();
  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  const actorHash = await hmacHex(pepper, auth.user.id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", { p_bucket: "admin-decide-ticket", p_key_hash: actorHash, p_max: 60, p_window_seconds: 60 });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Ticket action rate limit reached", undefined, limits[0].retry_after);

  const { data, error } = await admin.rpc("admin_decide_ticket", {
    p_actor_id: auth.user.id,
    p_ticket_id: input.ticket_id,
    p_action: input.action,
    p_assigned_to: input.action === "assign" ? input.assigned_to : null,
    p_decision: input.action === "decide" ? input.decision : null,
    p_criterion: input.action === "decide" ? input.criterion ?? null : null,
    p_note: input.action === "decide" ? input.note ?? null : null,
    p_adjusted_scores: input.action === "decide" && input.decision === "adjusted" ? input.adjusted_scores : null,
  });
  if (error) {
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "Admin authorization failed or appeal reviewer conflicts with the original reviewer");
    if (error.code === "22023") throw new HttpError("VALIDATION_FAILED", "Ticket action is not permitted");
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "Ticket not found");
    if (error.code === "40001") throw new HttpError("CONFLICT", "Ticket state changed; refresh and retry");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not update ticket");
  }
  const row = (data as TicketActionRow[] | null)?.[0];
  if (!row) throw new HttpError("SERVICE_UNAVAILABLE", "Ticket action did not return a result");
  return { body: { ticket_id: row.ticket_id, status: row.status as "assigned" | "closed", ...(row.decision ? { decision: row.decision as "upheld" | "overturned" | "adjusted" } : {}) } };
});
Deno.serve(handler);
