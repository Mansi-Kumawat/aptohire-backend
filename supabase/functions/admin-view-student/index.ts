import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { AdminViewStudentInputSchema, AdminViewStudentOutputSchema } from "../_shared/schemas/admin-view-student.ts";

const handler = withHandler({ auth: "jwt", roles: ["admin"], aal2: true, input: AdminViewStudentInputSchema, output: AdminViewStudentOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: gate, error: gateError } = await auth.client.from("admin_counts_v").select("pending_reviews").limit(1);
  if (gateError || !gate?.length) throw new HttpError("FORBIDDEN", "A current MFA-verified admin session is required");
  const admin = createAdminClient(); const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  const key = await hmacHex(pepper, auth.user.id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", { p_bucket: "admin-view-student", p_key_hash: key, p_max: 30, p_window_seconds: 3600 });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Admin rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Student detail view limit reached", undefined, limits[0].retry_after);
  const { error: auditError } = await admin.from("audit_log").insert({
    actor_id: auth.user.id, action: "admin_view_student", target_type: "student", target_id: input.student_id,
    metadata: { fields: ["profile", "affiliations", "skill_scores", "submissions"] },
  });
  if (auditError) throw new HttpError("SERVICE_UNAVAILABLE", "Sensitive read could not be audited");
  const { data: student, error: studentError } = await admin.from("students")
    .select("id,full_name,primary_email,headline,bio,location,credential_id").eq("id", input.student_id).maybeSingle();
  if (studentError || !student) throw new HttpError("NOT_FOUND", "Student not found");
  const [affiliationsResult, scoresResult, submissionsResult] = await Promise.all([
    admin.from("affiliations").select("id,university_id,university_name_text,verification,program_level,year,status,is_current").eq("student_id", input.student_id).order("started_on", { ascending: false }).limit(50),
    admin.from("skill_scores").select("skill_id,score,level,verified,pending_review,share_ok,updated_at,skills(name)").eq("student_id", input.student_id).order("updated_at", { ascending: false }).limit(100),
    admin.from("submissions").select("id,title,status,created_at,updated_at").eq("student_id", input.student_id).order("created_at", { ascending: false }).limit(50),
  ]);
  if (affiliationsResult.error || scoresResult.error || submissionsResult.error) throw new HttpError("SERVICE_UNAVAILABLE", "Student detail is temporarily unavailable");
  const scores = (scoresResult.data ?? []).map((row) => {
    const skill = Array.isArray(row.skills) ? row.skills[0] : row.skills;
    return { skill_id: row.skill_id, skill_name: skill?.name ?? "Unknown skill", score: Number(row.score), level: row.level, verified: row.verified, pending_review: row.pending_review, share_ok: row.share_ok, updated_at: row.updated_at };
  });
  return { body: {
    student: { id: student.id, full_name: student.full_name, primary_email: student.primary_email, headline: student.headline, bio: student.bio, location: student.location, credential_id: student.credential_id },
    affiliations: affiliationsResult.data ?? [], skill_scores: scores, submissions: submissionsResult.data ?? [],
  } };
});
Deno.serve(handler);
