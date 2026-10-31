import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { withHandler } from "../_shared/handler.ts";
import { RespondAccessInputSchema, RespondAccessOutputSchema } from "../_shared/schemas/respond-access.ts";

const handler = withHandler({ auth: "jwt", roles: ["student"], input: RespondAccessInputSchema, output: RespondAccessOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: student, error: studentError } = await auth.client.from("students").select("id")
    .eq("user_id", auth.user.id).maybeSingle();
  if (studentError) throw new HttpError("SERVICE_UNAVAILABLE", "Student profile lookup failed");
  if (!student) throw new HttpError("FORBIDDEN", "A student profile is required");

  const admin = createAdminClient();
  const { data, error } = await admin.rpc("respond_access", {
    p_student_id: student.id,
    p_actor_id: auth.user.id,
    p_request_id: input.request_id,
    p_decision: input.decision,
    p_granted_scope: input.granted_scope ?? null,
    p_duration_days: input.duration_days ?? null,
  });
  if (error) {
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "Access request not found");
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "This access request is not yours to respond to");
    if (error.code === "40001") throw new HttpError("CONFLICT", "This access request has already been answered");
    if (error.code === "23514" || error.code === "22023") throw new HttpError("VALIDATION_FAILED", "The requested access terms are invalid");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not respond to access request");
  }
  const raw = data as { status: "accepted" | "declined"; expires_at: string | null };
  if (raw.status === "declined") return { body: { status: "declined" as const } };
  if (!raw.expires_at) throw new HttpError("SERVICE_UNAVAILABLE", "Grant expiry was not set");
  return { body: { status: "accepted" as const, expires_at: new Date(raw.expires_at).toISOString() } };
});

Deno.serve(handler);
