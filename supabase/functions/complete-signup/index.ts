import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { z } from "npm:zod@3.23.8";
import { CompleteSignupInputSchema } from "../_shared/schemas/complete-signup.ts";
import { createAdminClient } from "../_shared/admin.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { HttpError } from "../_shared/errors.ts";

Deno.serve(async (request: Request) => {
  const preflightResponse = preflight(request);
  if (preflightResponse) return preflightResponse;
  const headers = corsHeaders(request);
  try {
    if (request.method !== "POST") throw new HttpError("VALIDATION_FAILED", "POST required");
    const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
    let raw: unknown;
    try { raw = await request.json(); } catch { throw new HttpError("VALIDATION_FAILED", "Request body must be valid JSON"); }
    const input = CompleteSignupInputSchema.parse(raw);
    const url = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!url || !anonKey) throw new HttpError("SERVICE_UNAVAILABLE", "Authentication is unavailable");
    const userClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: `Bearer ${token}` } } });
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) throw new HttpError("UNAUTHENTICATED", "Invalid or expired session");
    const admin = createAdminClient();
    const { data: currentProfile, error: profileError } = await userClient.from("profiles").select("role,deletion_started_at").eq("id", authData.user.id).maybeSingle();
    if (profileError) throw new HttpError("SERVICE_UNAVAILABLE", "Profile lookup failed");
    if (currentProfile?.deletion_started_at) throw new HttpError("FORBIDDEN", "Account deletion is in progress");
    if (currentProfile?.role && currentProfile.role !== input.portal) throw new HttpError("ROLE_ALREADY_SET", "This account already has a different portal role");
    const { error: roleError } = await admin.rpc("set_profile_role_once", { p_user_id: authData.user.id, p_role: input.portal });
    if (roleError) {
      // Keep user identifiers and request data out of logs; the PostgREST code is enough to diagnose migration/grant drift.
      console.error("complete-signup role initializer RPC failed", { code: roleError.code ?? "UNKNOWN" });
      if (roleError.code === "23505") throw new HttpError("ROLE_ALREADY_SET", "This account already has a different portal role");
      throw new HttpError("SERVICE_UNAVAILABLE", "Could not initialize account role");
    }

    // Membership is attached only by the atomic RPC when exactly one matching application and verified email exist.
    let claimedApplicationId: string | null = null;
    if (input.portal !== "student" && authData.user.email && authData.user.email_confirmed_at) {
      let query = admin.from("applications").select("id,type,subject_id,contact_email,status,reference")
        .eq("type", input.portal).eq("contact_email", authData.user.email).eq("status", "received").not("subject_id", "is", null).limit(2);
      if (input.application_ref) query = query.eq("reference", input.application_ref);
      const { data: apps, error: appsError } = await query;
      if (appsError) throw new HttpError("SERVICE_UNAVAILABLE", "Application lookup failed");
      if (apps?.length === 1 && apps[0].subject_id) {
        const application = apps[0];
        const { data: claimed, error: claimError } = await admin.rpc("claim_signup_application", {
          p_application_id: application.id,
          p_user_id: authData.user.id,
          p_portal: input.portal,
          p_verified_email: authData.user.email,
        });
        if (claimError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not attach applicant membership");
        if (claimed === true) claimedApplicationId = application.id;
      }
    }
    const { error: auditError } = await admin.from("audit_log").insert({ actor_id: authData.user.id, action: "signup_role_set", target_type: "profile", target_id: authData.user.id, metadata: { role: input.portal, ...(claimedApplicationId ? { application_id: claimedApplicationId } : {}) } });
    if (auditError) throw new HttpError("SERVICE_UNAVAILABLE", "Audit logging is unavailable");
    return new Response(null, { status: 204, headers });
  } catch (error) {
    if (error instanceof HttpError) return error.toResponse(headers);
    if (error instanceof z.ZodError) return new HttpError("VALIDATION_FAILED", "Request validation failed", Object.fromEntries(error.issues.map((issue) => [issue.path.join(".") || "body", issue.message]))).toResponse(headers);
    return new HttpError("SERVICE_UNAVAILABLE", "Service is temporarily unavailable").toResponse(headers);
  }
});
