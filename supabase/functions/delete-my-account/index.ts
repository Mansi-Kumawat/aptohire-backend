import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { authenticate } from "../_shared/auth.ts";
import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { DeleteMyAccountInputSchema } from "../_shared/schemas/delete-my-account.ts";

async function collectObjects(admin: ReturnType<typeof createAdminClient>, bucket: string, prefix: string): Promise<string[]> {
  const paths: string[] = [];
  let offset = 0;
  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 100, offset });
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not prepare secure account deletion");
    const items = data ?? [];
    for (const item of items) {
      if (!item.name || item.name === "." || item.name === "..") continue;
      const path = `${prefix}/${item.name}`;
      if (item.id === null) paths.push(...await collectObjects(admin, bucket, path));
      else paths.push(path);
    }
    if (items.length < 100) break;
    offset += 100;
  }
  return paths;
}

Deno.serve(async (request: Request): Promise<Response> => {
  const preflightResponse = preflight(request);
  if (preflightResponse) return preflightResponse;
  const headers = corsHeaders(request);
  const fail = (error: unknown) => error instanceof HttpError
    ? error.toResponse(headers)
    : new HttpError("SERVICE_UNAVAILABLE", "Account deletion is temporarily unavailable").toResponse(headers);
  try {
    if (request.method !== "POST") throw new HttpError("VALIDATION_FAILED", "POST required");
    const auth = await authenticate(request, { allowDeletionPending: true });
    if (auth.role !== "student") throw new HttpError("FORBIDDEN", "Only student accounts can use this operation");
    let raw: unknown;
    try { raw = await request.json(); } catch { throw new HttpError("VALIDATION_FAILED", "Request body must be valid JSON"); }
    const parsed = DeleteMyAccountInputSchema.safeParse(raw);
    if (!parsed.success) throw new HttpError("VALIDATION_FAILED", "Request validation failed", Object.fromEntries(parsed.error.issues.map((issue) => [issue.path.join(".") || "body", issue.message])));
    if (!auth.user.email) throw new HttpError("UNAUTHENTICATED", "A password-based account is required for deletion");

    const admin = createAdminClient();
    const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
    if (!ratePepper) throw new HttpError("SERVICE_UNAVAILABLE", "Account deletion is temporarily unavailable");
    const actorHash = await hmacHex(ratePepper, `delete-my-account:${auth.user.id}`);
    const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", {
      p_bucket: "delete-my-account", p_key_hash: actorHash, p_max: 5, p_window_seconds: 3600,
    });
    if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Account deletion is temporarily unavailable");
    if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Deletion attempt limit reached", undefined, limits[0].retry_after);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !anonKey) throw new HttpError("SERVICE_UNAVAILABLE", "Password verification is unavailable");
    const verifier = createClient(supabaseUrl, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: verified, error: passwordError } = await verifier.auth.signInWithPassword({ email: auth.user.email, password: parsed.data.password });
    if (passwordError || verified.user?.id !== auth.user.id) throw new HttpError("UNAUTHENTICATED", "Password verification failed");

    const { data: student, error: studentError } = await admin.from("students").select("id").eq("user_id", auth.user.id).maybeSingle();
    if (studentError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not prepare secure account deletion");
    const studentId = student?.id as string | undefined;
    if (studentId) {
      const buckets: Array<[string, string]> = [["videos", studentId], ["documents", studentId], ["resumes", studentId], ["data-exports", studentId]];
      for (const [bucket, prefix] of buckets) {
        const objects = await collectObjects(admin, bucket, prefix);
        if (objects.length) {
          const { error } = await admin.storage.from(bucket).remove(objects);
          if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not remove your stored files");
        }
      }
      const { error: avatarError } = await admin.storage.from("avatars").remove([`${studentId}.jpg`]);
      if (avatarError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not remove your stored files");
    }

    const { error: eraseError } = await admin.rpc("erase_student_account_data", { p_user_id: auth.user.id });
    if (eraseError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not erase your student data");

    // Soft deletion preserves immutable audit-log foreign keys while preventing future sign-in.
    const { error: authDeleteError } = await admin.auth.admin.deleteUser(auth.user.id, true);
    if (authDeleteError) throw new HttpError("SERVICE_UNAVAILABLE", "Data was erased but Auth deletion needs retry or administrator attention");
    const { error: finalizeError } = await admin.rpc("finalize_student_account_deletion", { p_user_id: auth.user.id });
    if (finalizeError) throw new HttpError("SERVICE_UNAVAILABLE", "Account access was disabled but final cleanup needs administrator attention");
    return new Response(null, { status: 204, headers });
  } catch (error) {
    return fail(error);
  }
});
