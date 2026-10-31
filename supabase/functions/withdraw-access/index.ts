import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { withHandler } from "../_shared/handler.ts";
import { WithdrawAccessInputSchema, WithdrawAccessOutputSchema } from "../_shared/schemas/withdraw-access.ts";

const handler = withHandler({ auth: "jwt", roles: ["student"], input: WithdrawAccessInputSchema, output: WithdrawAccessOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: student, error: studentError } = await auth.client.from("students").select("id")
    .eq("user_id", auth.user.id).maybeSingle();
  if (studentError) throw new HttpError("SERVICE_UNAVAILABLE", "Student profile lookup failed");
  if (!student) throw new HttpError("FORBIDDEN", "A student profile is required");

  const admin = createAdminClient();
  const { data, error } = await admin.rpc("withdraw_access", {
    p_student_id: student.id,
    p_actor_id: auth.user.id,
    p_request_id: input.request_id,
  });
  if (error) {
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "Access request not found");
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "This access request is not yours to withdraw");
    if (error.code === "40001") throw new HttpError("CONFLICT", "Only an active accepted request can be withdrawn");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not withdraw access");
  }
  return { body: data };
});

Deno.serve(handler);
