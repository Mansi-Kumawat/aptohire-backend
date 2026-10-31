import { createAdminClient } from "../_shared/admin.ts";
import { withHandler } from "../_shared/handler.ts";
import { HttpError } from "../_shared/errors.ts";
import { RevealStudentInputSchema, RevealStudentOutputSchema } from "../_shared/schemas/reveal-student.ts";
import { scrubExcerpt } from "../_shared/agents/postprocess-audit.ts";
import { isAccessGrantActive } from "../_shared/access-grant.ts";
import { createRevealSignedUrl, createSafeDocumentRevealFile, createSafeSubmissionVideoRevealUrl } from "../_shared/reveal-storage.ts";

const handler = withHandler({ auth: "jwt", roles: ["organization"], input: RevealStudentInputSchema, output: RevealStudentOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: memberships, error: membershipsError } = await auth.client.from("organization_members")
    .select("organization_id").eq("user_id", auth.user.id);
  if (membershipsError || !memberships?.length) throw new HttpError("FORBIDDEN", "Organization membership is required");
  const allowedOrgIds = memberships.map((item) => item.organization_id);
  const admin = createAdminClient();
  const logAttempt = async (action: string, orgId?: string) => {
    const { error } = await admin.from("audit_log").insert({ actor_id: auth.user.id, action, target_type: "access_request", target_id: input.request_id, metadata: orgId ? { organization_id: orgId } : {} });
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Audit logging is unavailable");
  };

  const { data: requestRow, error: requestError } = await admin.from("access_requests")
    .select("id,organization_id,student_id,granted_scope,status,expires_at,duration_days")
    .eq("id", input.request_id).maybeSingle();
  if (requestError || !requestRow || !allowedOrgIds.includes(requestRow.organization_id)) {
    await logAttempt("identity_reveal_denied");
    throw new HttpError("GRANT_EXPIRED", "Access grant is unavailable");
  }
  if (!isAccessGrantActive(requestRow, [])) {
    await logAttempt("identity_reveal_denied", requestRow.organization_id);
    throw new HttpError("GRANT_EXPIRED", "Access grant has expired or been withdrawn");
  }
  await logAttempt("identity_reveal_attempted", requestRow.organization_id);
  const scopes = requestRow.granted_scope as string[];
  const expiresAt = new Date(requestRow.expires_at).toISOString();
  const { data: student, error: studentError } = await admin.from("students")
    .select("id,full_name,primary_email,headline,bio,location,links")
    .eq("id", requestRow.student_id).maybeSingle();
  if (studentError || !student) throw new HttpError("GRANT_EXPIRED", "Access grant is unavailable");

  const response: Record<string, unknown> = { request_id: requestRow.id, granted_scope: scopes, expires_at: expiresAt };
  if (scopes.includes("profile")) {
    const profile: Record<string, unknown> = { full_name: student.full_name };
    if (student.headline) profile.headline = student.headline;
    if (student.bio) profile.bio = student.bio;
    if (student.location) profile.location = student.location;
    if (Array.isArray(student.links)) profile.links = student.links.filter((link) => typeof link?.label === "string" && typeof link?.url === "string");
    const { data: affiliation, error: affiliationError } = await admin.from("affiliations").select("verification,universities(name)").eq("student_id", student.id).eq("is_current", true).maybeSingle();
    if (affiliationError) throw new HttpError("SERVICE_UNAVAILABLE", "Affiliation details are unavailable");
    if (affiliation) {
      const university = affiliation.universities as { name?: string } | null;
      if (university?.name) profile.university = { name: university.name, verification: affiliation.verification };
    }
    const avatarPath = `${student.id}.jpg`;
    const avatarUrl = await createRevealSignedUrl(admin.storage.from("avatars"), avatarPath);
    if (avatarUrl) profile.avatar_url = avatarUrl;
    response.profile = profile;
  }
  if (scopes.includes("contact")) {
    if (student.primary_email) response.contact = { email: String(student.primary_email) };
  }
  if (scopes.includes("scorecard")) {
    const { data: scores, error: scoreError } = await admin.from("skill_scores")
      .select("score,level,verified,updated_at,skills(name),audits(summary)")
      .eq("student_id", student.id).eq("share_ok", true).eq("pending_review", false);
    if (scoreError) throw new HttpError("SERVICE_UNAVAILABLE", "Scorecard is unavailable");
    const skills = (scores ?? []).map((row) => {
      const skill = row.skills as { name?: string } | null;
      const audit = row.audits as { summary?: string } | null;
      return {
        name: skill?.name ?? "",
        level: row.level,
        ...(row.verified ? { score: Number(row.score) } : {}),
        verified: row.verified,
        ...(row.verified ? { verified_on: new Date(row.updated_at).toISOString().slice(0, 10) } : {}),
        ...(audit?.summary ? { summary: scrubExcerpt(audit.summary).slice(0, 600) } : {}),
      };
    }).filter((row) => row.name);
    response.scorecard = { skills };
  }
  if (scopes.includes("projects")) {
    const { data: submissions, error: submissionsError } = await admin.from("submissions")
      .select("id,title,description,live_url,github_url,document_paths,template_id,claimed_skill_ids,video_path,project_templates(brief)")
      .eq("student_id", student.id).in("status", ["scored", "needs_review"]);
    if (submissionsError) throw new HttpError("SERVICE_UNAVAILABLE", "Projects are unavailable");
    const projects = await Promise.all((submissions ?? []).map(async (submission) => {
      const template = submission.project_templates as { brief?: { objective?: string } } | null;
      const project: Record<string, unknown> = { id: submission.id, title: submission.title, skills: [] as string[] };
      const description = typeof submission.description === "string" ? submission.description : template?.brief?.objective;
      if (description) project.description = scrubExcerpt(description);
      if (typeof submission.live_url === "string" && submission.live_url.startsWith("https://")) project.live_url = submission.live_url;
      if (typeof submission.github_url === "string" && /^https:\/\/(?:www\.)?github\.com\//i.test(submission.github_url)) project.github_url = submission.github_url;
      if (Array.isArray(submission.document_paths) && submission.document_paths.length) {
        const fileResults = await Promise.all(submission.document_paths.slice(0, 10).map((path: unknown) =>
          createSafeDocumentRevealFile(admin.storage.from("documents"), path, student.id, submission.id)
        ));
        const files = fileResults.filter((file): file is { name: string; url: string } => file !== null);
        if (files.length) project.files = files;
      }
      if (Array.isArray(submission.claimed_skill_ids) && submission.claimed_skill_ids.length) {
        const { data: skills, error: skillsError } = await admin.from("skills").select("name").in("id", submission.claimed_skill_ids);
        if (skillsError) throw new HttpError("SERVICE_UNAVAILABLE", "Project details are unavailable");
        project.skills = (skills ?? []).map((skill) => skill.name);
      }
      const videoUrl = await createSafeSubmissionVideoRevealUrl(
        admin.storage.from("videos"), submission.video_path, student.id, submission.id,
      );
      if (videoUrl) project.video_url = videoUrl;
      return project;
    }));
    response.projects = projects;
  }
  // The grant may be withdrawn or narrowed while signed URLs and scoped data are being gathered.
  // Revalidate immediately before returning any identity-bearing response.
  const { data: currentGrant, error: currentGrantError } = await admin.from("access_requests")
    .select("status,expires_at,granted_scope").eq("id", requestRow.id).eq("organization_id", requestRow.organization_id)
    .eq("student_id", student.id).maybeSingle();
  if (currentGrantError) throw new HttpError("SERVICE_UNAVAILABLE", "Access grant could not be revalidated");
  const stillGranted = isAccessGrantActive(currentGrant, scopes);
  if (!stillGranted) {
    await logAttempt("identity_reveal_denied", requestRow.organization_id);
    throw new HttpError("GRANT_EXPIRED", "Access grant has expired or been withdrawn");
  }
  await logAttempt("identity_revealed", requestRow.organization_id);
  const validatedOutput = RevealStudentOutputSchema.parse(response);
  return { body: validatedOutput };
});

Deno.serve(handler);
