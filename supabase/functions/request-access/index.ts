import { z } from "npm:zod@3.23.8";
import { createAdminClient } from "../_shared/admin.ts";
import { RequestAccessInputSchema, RequestAccessOutputSchema } from "../_shared/schemas/request-access.ts";
import { withHandler } from "../_shared/handler.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { containsContactDetails } from "../_shared/contact.ts";
import { isCurrentMatchRequestable } from "../_shared/access-eligibility.ts";

const handler = withHandler({ auth: "jwt", roles: ["organization"], input: RequestAccessInputSchema, output: RequestAccessOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  if (input.message && containsContactDetails(input.message)) {
    throw new HttpError("VALIDATION_FAILED", "Messages cannot include contact details", { message: "Remove email addresses, phone numbers, URLs, and social handles." });
  }

  // First prove organization membership through the caller-scoped client and RLS.
  const { data: memberships, error: memberError } = await auth.client
    .from("organization_members").select("organization_id").eq("user_id", auth.user.id);
  if (memberError || !memberships?.length) throw new HttpError("FORBIDDEN", "Organization membership is required");
  const orgIds = memberships.map((row) => row.organization_id);

  // Privileged reads happen only after JWT verification, role authorization, and membership proof.
  const admin = createAdminClient();
  const { data: match, error: matchError } = await admin.from("match_results")
    .select("id,student_id,job_id,jobs!inner(id,organization_id,status),students!inner(id,user_id)")
    .eq("id", input.match_result_id).maybeSingle();
  const jobRelation = z.object({ id: z.string().uuid(), organization_id: z.string().uuid(), status: z.string() }).strict();
  const studentRelation = z.object({ id: z.string().uuid(), user_id: z.string().uuid().nullable() }).strict();
  const rawJob: unknown = Array.isArray(match?.jobs) ? match.jobs[0] : match?.jobs;
  const rawStudent: unknown = Array.isArray(match?.students) ? match.students[0] : match?.students;
  const parsedJob = jobRelation.safeParse(rawJob);
  const parsedStudent = studentRelation.safeParse(rawStudent);
  if (matchError || !match || !parsedJob.success || !parsedStudent.success || !orgIds.includes(parsedJob.data.organization_id)) {
    throw new HttpError("NOT_FOUND", "Candidate match not found");
  }
  const job = parsedJob.data;
  const student = parsedStudent.data;
  if (job.status !== "open") throw new HttpError("CONFLICT", "Only open jobs can receive access requests");
  if (!student.user_id) throw new HttpError("NOT_FOUND", "Candidate match not found");

  // A match card may be stale between display and click. Re-check current privacy and shared evidence.
  const { data: liveStudent, error: liveStudentError } = await admin.from("students").select("visibility").eq("id", student.id).maybeSingle();
  if (liveStudentError) throw new HttpError("SERVICE_UNAVAILABLE", "Candidate visibility could not be verified");
  const studentDiscoverable = liveStudent?.visibility?.discoverable === true;
  const { data: profile, error: profileError } = await admin.from("candidate_profiles").select("discoverable").eq("student_id", student.id).maybeSingle();
  if (profileError) throw new HttpError("SERVICE_UNAVAILABLE", "Candidate visibility could not be verified");
  const projectionDiscoverable = profile?.discoverable === true;
  const { count: shareableSkillCount, error: scoreError } = await admin.from("skill_scores").select("id", { count: "exact", head: true })
    .eq("student_id", student.id).eq("verified", true).eq("share_ok", true).eq("pending_review", false);
  if (scoreError) throw new HttpError("SERVICE_UNAVAILABLE", "Candidate skills could not be verified");
  if (!isCurrentMatchRequestable({
    jobOpen: job.status === "open",
    studentHasLogin: Boolean(student.user_id),
    studentDiscoverable,
    candidateProjectionDiscoverable: projectionDiscoverable,
    shareableVerifiedSkillCount: shareableSkillCount ?? null,
  })) throw new HttpError("NOT_FOUND", "Candidate match not found");
  const { data: org, error: orgError } = await admin.from("organizations")
    .select("id,status,subscription_status").eq("id", job.organization_id).maybeSingle();
  if (orgError || !org) throw new HttpError("NOT_FOUND", "Organization not found");
  if (org.status !== "approved" || org.subscription_status !== "active") {
    throw new HttpError("SUBSCRIPTION_INACTIVE", "An active organization subscription is required");
  }

  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Rate limiter is unavailable");
  const orgKey = await hmacHex(pepper, job.organization_id);
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", {
    p_bucket: "request-access-org", p_key_hash: orgKey, p_max: 20, p_window_seconds: 86400,
  });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Rate limiter is unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Organization request limit reached", undefined, limits[0].retry_after);

  const { data: requestId, error: requestError } = await admin.rpc("create_access_request", {
    p_actor_id: auth.user.id,
    p_match_result_id: match.id,
    p_message: input.message ?? null,
    p_requested_scope: input.requested_scope,
    p_duration_days: input.duration_days,
  });
  if (requestError) {
    if (requestError.code === "23505") throw new HttpError("CONFLICT", "An active request already exists for this job and candidate");
    if (requestError.code === "P0002") throw new HttpError("NOT_FOUND", "Candidate match not found");
    if (requestError.code === "42501") throw new HttpError("SUBSCRIPTION_INACTIVE", "An active organization subscription is required");
    if (requestError.code === "40001") throw new HttpError("CONFLICT", "Only open jobs can receive access requests");
    if (requestError.code === "22023") throw new HttpError("VALIDATION_FAILED", "Access request terms are invalid");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not create access request");
  }
  if (typeof requestId !== "string") throw new HttpError("SERVICE_UNAVAILABLE", "Access request receipt is invalid");
  return { status: 201, body: { request_id: requestId } };
});

Deno.serve(handler);
