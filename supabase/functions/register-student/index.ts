import { createAdminClient } from "../_shared/admin.ts";
import { withHandler } from "../_shared/handler.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex, normalizeStudentId } from "../_shared/hash.ts";
import { RegisterStudentInputSchema, RegisterStudentOutputSchema } from "../_shared/schemas/register-student.ts";
import { resolveDetectOutcome, resolveExistingAffiliationOutcome, resolveStudentIdOutcome, resolveUnregisteredOutcome } from "../_shared/identity/register-outcome.ts";

const handler = withHandler({ auth: "jwt", roles: ["student"], input: RegisterStudentInputSchema, output: RegisterStudentOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const verifiedEmail = auth.user.email_confirmed_at ? auth.user.email?.trim().toLowerCase() ?? null : null;
  const admin = createAdminClient();
  let matchedUniversity: { id: string; name: string; email_domains: string[] } | null = null;
  let roster: { id: string; university_id: string; student_id: string | null; program_level: string | null; year: number | null; status: string; full_name: string | null } | null = null;
  let outcome: "verified_roster" | "needs_student_id" | "verified_student_id" | "unverified" | "confirm_existing" | "roster_no_match" = "roster_no_match";
  let verification: "roster" | "student_id" | "unverified" | null = null;

  if (input.choice.kind === "detect") {
    if (!verifiedEmail) outcome = resolveDetectOutcome(false, 0, 0);
    else {
      const domain = verifiedEmail.split("@").at(-1) ?? "";
      const { data: universities, error } = await admin.from("universities").select("id,name,email_domains").eq("status", "approved");
      if (error) throw new HttpError("SERVICE_UNAVAILABLE", "University lookup failed");
      const universityRows = (universities ?? []) as Array<{ id: string; name: string; email_domains: string[] }>;
      const candidates = universityRows.filter((uni) => uni.email_domains.some((item) => item.trim().toLowerCase() === domain));
      if (candidates.length === 1) {
        matchedUniversity = candidates[0];
        const { data: rows, error: rosterError } = await admin.from("roster_entries")
          .select("id,university_id,student_id,program_level,year,status,full_name")
          .eq("university_id", matchedUniversity.id).eq("email", verifiedEmail).limit(2);
        if (rosterError) throw new HttpError("SERVICE_UNAVAILABLE", "Roster lookup failed");
        outcome = resolveDetectOutcome(true, candidates.length, rows?.length ?? 0);
        if (outcome === "verified_roster" && rows?.length === 1) { roster = rows[0]; verification = "roster"; }
      } else outcome = resolveDetectOutcome(true, candidates.length, 0);
    }
  } else if (input.choice.kind === "student_id") {
    const idPepper = Deno.env.get("ID_HASH_PEPPER");
    const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
    if (!idPepper || !ratePepper) throw new HttpError("SERVICE_UNAVAILABLE", "Registration is unavailable");
    const ip = context.request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const userKey = await hmacHex(ratePepper, `student-id-verify:user:${auth.user.id}`);
    const ipKey = await hmacHex(ratePepper, `student-id-verify:ip:${ip}`);
    for (const [key, bucket, max, seconds] of [[userKey, "student-id-verify-user", 5, 3600], [ipKey, "student-id-verify-ip", 20, 86400]] as const) {
      const { data, error } = await admin.rpc("consume_rate_limit", { p_bucket: bucket, p_key_hash: key, p_max: max, p_window_seconds: seconds });
      if (error || !data?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Registration rate limiter is unavailable");
      if (!data[0].allowed) throw new HttpError("RATE_LIMITED", "Registration attempt limit reached", undefined, data[0].retry_after);
    }
    const { data: university, error: universityError } = await admin.from("universities").select("id,name,email_domains").eq("id", input.choice.university_id).eq("status", "approved").maybeSingle();
    if (universityError) throw new HttpError("SERVICE_UNAVAILABLE", "University lookup failed");
    if (university) {
      matchedUniversity = university;
      const hash = await hmacHex(idPepper, normalizeStudentId(input.choice.student_id_number));
      const { data: row, error: rosterError } = await admin.from("roster_entries")
        .select("id,university_id,student_id,program_level,year,status,full_name")
        .eq("university_id", university.id).eq("student_id_hash", hash).maybeSingle();
      if (rosterError) throw new HttpError("SERVICE_UNAVAILABLE", "Roster lookup failed");
      outcome = resolveStudentIdOutcome(true, Boolean(row));
      if (row) { roster = row; verification = "student_id"; }
    } else outcome = resolveStudentIdOutcome(false, false);
  } else {
    if (input.choice.university_id) {
      const { data: university, error } = await admin.from("universities").select("id,name,email_domains").eq("id", input.choice.university_id).eq("status", "approved").maybeSingle();
      if (error) throw new HttpError("SERVICE_UNAVAILABLE", "University lookup failed");
      matchedUniversity = university;
    }
    outcome = resolveUnregisteredOutcome();
    verification = "unverified";
  }

  const { data: identityRows, error: identityError } = await admin.rpc("claim_student_identity", {
    p_user_id: auth.user.id,
    p_verified_email: verifiedEmail,
    p_roster_entry_id: roster?.id ?? null,
    p_full_name: input.full_name,
  });
  if (identityError) {
    if (identityError.code === "23505") throw new HttpError("ACCOUNT_EXISTS", "This student record is already linked to another account");
    if (identityError.code === "42501") throw new HttpError("FORBIDDEN", "This student identity cannot be claimed by this account");
    if (identityError.code === "P0002") throw new HttpError("CONFLICT", "Roster details changed; retry registration");
    throw new HttpError("SERVICE_UNAVAILABLE", "Student identity could not be resolved");
  }
  const identity = (identityRows as Array<{ student_id: string; matched_existing_person: boolean }> | null)?.[0];
  if (!identity?.student_id || typeof identity.matched_existing_person !== "boolean") {
    throw new HttpError("SERVICE_UNAVAILABLE", "Student identity resolution returned an invalid result");
  }
  const personId = identity.student_id;
  const matchedExisting = identity.matched_existing_person;

  let affiliationResult: { university_id?: string; label: string; verification: "roster" | "student_id" | "unverified" } | undefined;
  if (roster && matchedUniversity && verification) {
    const { data: currentAffiliation, error } = await admin.from("affiliations").select("id,university_id,is_current,verification")
      .eq("student_id", personId).eq("is_current", true).maybeSingle();
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Affiliation lookup failed");
    if (currentAffiliation && currentAffiliation.university_id !== matchedUniversity.id) {
      const { data: proposalId, error: proposalError } = await admin.rpc("ensure_affiliation_proposal", {
        p_student_id: personId,
        p_actor_id: auth.user.id,
        p_university_id: matchedUniversity.id,
        p_roster_entry_id: roster.id,
        p_program_level: roster.program_level ?? input.program_level,
        p_status: roster.status,
        p_year: roster.year ?? input.year,
      });
      if (proposalError) {
        if (proposalError.code === "42501") throw new HttpError("FORBIDDEN", "This student profile cannot be changed by this account");
        if (proposalError.code === "23505" || proposalError.code === "40001") throw new HttpError("CONFLICT", "Affiliation changed; refresh and try again");
        if (proposalError.code === "P0002") throw new HttpError("CONFLICT", "Roster or university details changed; retry registration");
        throw new HttpError("SERVICE_UNAVAILABLE", "Could not create affiliation proposal");
      }
      if (!proposalId) throw new HttpError("SERVICE_UNAVAILABLE", "Could not create affiliation proposal");
      outcome = resolveExistingAffiliationOutcome(outcome, true);
      affiliationResult = { university_id: matchedUniversity.id, label: matchedUniversity.name, verification };
    } else {
      if (!roster.student_id) {
        const { data: claimedRoster, error: claimError } = await admin.from("roster_entries")
          .update({ student_id: personId }).eq("id", roster.id).is("student_id", null).select("student_id").maybeSingle();
        if (claimError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not claim roster entry");
        if (claimedRoster?.student_id !== personId) {
          const { data: reread, error: rereadError } = await admin.from("roster_entries").select("student_id").eq("id", roster.id).maybeSingle();
          if (rereadError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not verify roster claim");
          if (reread?.student_id !== personId) throw new HttpError("ACCOUNT_EXISTS", "This roster record is already linked to another account");
        }
      }
      if (currentAffiliation) {
        const { error: updateError } = await admin.from("affiliations").update({ roster_entry_id: roster.id, verification, program_level: roster.program_level ?? input.program_level, year: roster.year ?? input.year, status: roster.status }).eq("id", currentAffiliation.id);
        if (updateError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not update verified affiliation");
      } else {
        const { error: affiliationError } = await admin.from("affiliations").insert({ student_id: personId, university_id: matchedUniversity.id, roster_entry_id: roster.id, verification, program_level: roster.program_level ?? input.program_level, year: roster.year ?? input.year, status: roster.status, is_current: true });
        if (affiliationError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not create affiliation");
      }
      affiliationResult = { university_id: matchedUniversity.id, label: matchedUniversity.name, verification };
    }
  } else if (input.choice.kind === "unregistered") {
    const { data: currentAffiliation, error } = await admin.from("affiliations").select("id,university_id,university_name_text,verification,is_current")
      .eq("student_id", personId).eq("is_current", true).maybeSingle();
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Affiliation lookup failed");
    if (currentAffiliation) {
      if (currentAffiliation.verification !== "unverified") throw new HttpError("CONFLICT", "Use affiliation confirmation to replace a verified affiliation");
      const { error: updateError } = await admin.from("affiliations").update({ university_id: matchedUniversity?.id ?? null, university_name_text: matchedUniversity ? null : input.choice.university_name, program_level: input.program_level, year: input.year }).eq("id", currentAffiliation.id);
      if (updateError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not update unverified affiliation");
      affiliationResult = { ...(matchedUniversity ? { university_id: matchedUniversity.id } : {}), label: matchedUniversity?.name ?? input.choice.university_name, verification: "unverified" };
    } else {
      const { error: affiliationError } = await admin.from("affiliations").insert({ student_id: personId, university_id: matchedUniversity?.id ?? null, university_name_text: matchedUniversity ? null : input.choice.university_name, verification: "unverified", program_level: input.program_level, year: input.year, is_current: true });
      if (affiliationError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not create unverified affiliation");
      affiliationResult = { ...(matchedUniversity ? { university_id: matchedUniversity.id } : {}), label: matchedUniversity?.name ?? input.choice.university_name, verification: "unverified" };
    }
  }

  const { error: auditError } = await admin.from("audit_log").insert({ actor_id: auth.user.id, action: "student_registration", target_type: "student", target_id: personId, metadata: { outcome } });
  if (auditError) throw new HttpError("SERVICE_UNAVAILABLE", "Audit logging is unavailable");
  return { body: { student_id: personId, outcome, ...(affiliationResult ? { affiliation: affiliationResult } : {}), matched_existing_person: matchedExisting } };
});

Deno.serve(handler);
