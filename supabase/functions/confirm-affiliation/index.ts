import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { withHandler } from "../_shared/handler.ts";
import { hmacHex, normalizeStudentId } from "../_shared/hash.ts";
import { normalizeLifeStatus, normalizeProgramLevel } from "../_shared/university-contract.ts";
import { ConfirmAffiliationInputSchema, ConfirmAffiliationOutputSchema } from "../_shared/schemas/confirm-affiliation.ts";

const handler = withHandler({ auth: "jwt", roles: ["student"], input: ConfirmAffiliationInputSchema, output: ConfirmAffiliationOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: student, error: studentError } = await auth.client.from("students").select("id")
    .eq("user_id", auth.user.id).maybeSingle();
  if (studentError) throw new HttpError("SERVICE_UNAVAILABLE", "Student profile lookup failed");
  if (!student) throw new HttpError("FORBIDDEN", "A student profile is required");

  const admin = createAdminClient();
  let proposalId: string | null = null;
  let universityId: string | null = null;
  let universityName: string | null = null;
  let idHash: string | null = null;
  let programLevel: string | null = null;
  let year: number | null = null;
  let status: "incoming" | "enrolled" | "alumni" | "dropout" | null = null;

  if (input.kind === "proposal") {
    proposalId = input.proposal_id;
  } else {
    const affiliation = input.new;
    universityId = affiliation.university_id ?? null;
    universityName = affiliation.university_name_text ?? null;
    programLevel = affiliation.program_level;
    year = affiliation.year ?? null;
    status = affiliation.status;
    if (affiliation.student_id_number) {
      const idPepper = Deno.env.get("ID_HASH_PEPPER");
      const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
      if (!idPepper || !ratePepper) throw new HttpError("SERVICE_UNAVAILABLE", "Affiliation verification is unavailable");
      const ip = context.request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
      const userKey = await hmacHex(ratePepper, `student-id-verify:user:${auth.user.id}`);
      const ipKey = await hmacHex(ratePepper, `student-id-verify:ip:${ip}`);
      for (const [key, bucket, max, seconds] of [[userKey, "student-id-verify-user", 5, 3600], [ipKey, "student-id-verify-ip", 20, 86400]] as const) {
        const { data, error } = await admin.rpc("consume_rate_limit", { p_bucket: bucket, p_key_hash: key, p_max: max, p_window_seconds: seconds });
        if (error || !data?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Affiliation rate limiter is unavailable");
        if (!data[0].allowed) throw new HttpError("RATE_LIMITED", "Verification attempt limit reached", undefined, data[0].retry_after);
      }
      idHash = await hmacHex(idPepper, normalizeStudentId(affiliation.student_id_number));
    }
  }

  const { data, error } = await admin.rpc("confirm_affiliation", {
    p_student_id: student.id,
    p_actor_id: auth.user.id,
    p_proposal_id: proposalId,
    p_university_id: universityId,
    p_university_name_text: universityName,
    p_student_id_hash: idHash,
    p_program_level: programLevel,
    p_year: year,
    p_status: status,
  });
  if (error) {
    if (error.code === "P0002") throw new HttpError("NOT_FOUND", "Affiliation or roster match was not found");
    if (error.code === "23505" || error.code === "40001") throw new HttpError("CONFLICT", "Affiliation changed; refresh and try again");
    if (error.code === "42501") throw new HttpError("FORBIDDEN", "This affiliation cannot be changed by this account");
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not confirm affiliation");
  }
  const returned = data as Record<string, unknown>;
  const normalizedProgramLevel = normalizeProgramLevel(returned.program_level);
  const normalizedStatus = normalizeLifeStatus(returned.status);
  if (!normalizedStatus || (returned.program_level !== null && !normalizedProgramLevel)) {
    throw new HttpError("SERVICE_UNAVAILABLE", "Affiliation contains unsupported university values");
  }
  // Parsing here both enforces the frozen API response contract and preserves its
  // complete inferred TypeScript shape for withHandler's output type.
  const output = ConfirmAffiliationOutputSchema.parse({
    affiliation: {
      id: returned.id,
      university_id: returned.university_id,
      university_name_text: returned.university_name_text,
      verification: returned.verification,
      program_level: normalizedProgramLevel,
      year: returned.year,
      status: normalizedStatus,
      is_current: returned.is_current,
    },
  });
  return { body: output };
});

Deno.serve(handler);
