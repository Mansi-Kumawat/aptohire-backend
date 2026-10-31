import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { ExportMyDataInputSchema, ExportMyDataOutputSchema } from "../_shared/schemas/export-my-data.ts";
import { isSafeDataExportObjectPath } from "../_shared/export-retention.ts";
import { createDataExportSignedUrl, removeDataExportObject } from "../_shared/export-storage.ts";

const handler = withHandler({ auth: "jwt", roles: ["student"], input: ExportMyDataInputSchema, output: ExportMyDataOutputSchema }, async (_input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: student, error: studentError } = await auth.client.from("students")
    .select("id,user_id,full_name,primary_email,photo_path,headline,bio,links,location,languages,target_skill_ids,target_roles,visibility,credential_id,created_at,updated_at")
    .eq("user_id", auth.user.id).maybeSingle();
  if (studentError) throw new HttpError("SERVICE_UNAVAILABLE", "Could not load your student profile");
  if (!student) throw new HttpError("NOT_FOUND", "Student profile not found");

  const pepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!pepper) throw new HttpError("SERVICE_UNAVAILABLE", "Data export is temporarily unavailable");
  const actorHash = await hmacHex(pepper, `export-my-data:${auth.user.id}`);
  const admin = createAdminClient();
  const { data: limits, error: limitError } = await admin.rpc("consume_rate_limit", {
    p_bucket: "export-my-data", p_key_hash: actorHash, p_max: 3, p_window_seconds: 3600,
  });
  if (limitError || !limits?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Data export is temporarily unavailable");
  if (!limits[0].allowed) throw new HttpError("RATE_LIMITED", "Export limit reached", undefined, limits[0].retry_after);

  const studentId = student.id as string;
  const query = async (table: string, columns: string, column: string, value: string) => {
    const { data, error } = await admin.from(table).select(columns).eq(column, value);
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not prepare your data export");
    return data ?? [];
  };
  const [affiliations, proposals, profileProposals, sources, rosterEntries, submissions, scores, scoreHistory, assignments, tickets, accessRequests, feedback, placements, notifications, ownAuditLog] = await Promise.all([
    query("affiliations", "id,university_id,university_name_text,verification,program_level,year,status,is_current,started_on,ended_on", "student_id", studentId),
    query("affiliation_proposals", "id,university_id,roster_entry_id,program_level,status,year,state,created_at", "student_id", studentId),
    query("profile_proposals", "id,source_id,changes,state,created_at", "student_id", studentId),
    query("profile_sources", "id,source_type,auto_approve,consented_at,revoked_at", "student_id", studentId),
    query("roster_entries", "id,university_id,email,full_name,program_level,program,year,status,created_at", "student_id", studentId),
    query("submissions",  "id,template_id,title,status,claimed_skill_ids,video_path,video_url,video_seconds,video_bytes,originality_answers,created_at,updated_at", "student_id", studentId),
    query("skill_scores", "id,skill_id,score,level,verified,pending_review,share_ok,audit_id,updated_at", "student_id", studentId),
    query("skill_score_history", "id,skill_id,score,level,verified,audit_id,created_at", "student_id", studentId),
    query("project_assignments", "id,template_id,status,brief,created_at", "student_id", studentId),
    query("tickets", "id,submission_id,reason,status,decision,created_at,resolved_at", "student_id", studentId),
    query("access_requests", "id,job_id,message,requested_scope,granted_scope,duration_days,status,expires_at,created_at,responded_at", "student_id", studentId),
    query("feedback", "id,organization_id,request_id,option_codes,note,created_at", "student_id", studentId),
    query("placements", "id,university_id,status,organization_name_text,role_text,source,updated_at", "student_id", studentId),
    query("notifications", "id,kind,payload,read_at,created_at", "user_id", auth.user.id),
    query("audit_log", "id,action,target_type,target_id,metadata,created_at", "actor_id", auth.user.id),
  ]);

  const submissionIds = (submissions as unknown as Array<{ id: string }>).map((row) => row.id);
  let audits: unknown[] = [];
  let runs: unknown[] = [];
  if (submissionIds.length) {
    const [auditResult, runResult] = await Promise.all([
      admin.from("audits").select("id,submission_id,rubric_version,prompt_version,overall_score,reviewed_score,confidence,summary,rubric,evidence,transcript,visual_observations,next_steps,review_status,review_note,created_at").in("submission_id", submissionIds),
      admin.from("agent_runs").select("id,submission_id,stage,attempt,mode,status,latency_ms,token_estimate,error_code,created_at").in("submission_id", submissionIds),
    ]);
    if (auditResult.error || runResult.error) throw new HttpError("SERVICE_UNAVAILABLE", "Could not prepare your data export");
    audits = auditResult.data ?? [];
    runs = runResult.data ?? [];
  }
  const exportData = {
    schema_version: 1,
    exported_at: new Date().toISOString(),
    student,
    affiliations,
    affiliation_proposals: proposals,
    profile_proposals: profileProposals,
    profile_sources: sources,
    roster_entries: rosterEntries,
    submissions,
    audits,
    agent_runs: runs,
    skill_scores: scores,
    skill_score_history: scoreHistory,
    project_assignments: assignments,
    tickets,
    access_requests: accessRequests,
    feedback,
    placements,
    notifications,
    audit_log: ownAuditLog,
  };
  const serialized = JSON.stringify(exportData, null, 2);
  const payloadBytes = new TextEncoder().encode(serialized).byteLength;
  if (payloadBytes > 19 * 1024 * 1024) throw new HttpError("SERVICE_UNAVAILABLE", "Your export is too large to prepare as a single file");

  const path = `${studentId}/exports/${crypto.randomUUID()}.json`;
  const exportBucket = admin.storage.from("data-exports");
  try {
    const { error: uploadError } = await exportBucket.upload(path, new Blob([serialized], { type: "application/json" }), { contentType: "application/json", upsert: false });
    if (uploadError) throw new Error("upload failed");
  } catch {
    await removeDataExportObject(exportBucket, path);
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not store your data export");
  }
  const signedUrl = await createDataExportSignedUrl(exportBucket, path);
  if (!signedUrl) {
    await removeDataExportObject(exportBucket, path);
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not create your temporary download link");
  }
  const { error: auditError } = await admin.from("audit_log").insert({
    actor_id: auth.user.id,
    action: "student_data_exported",
    target_type: "student",
    target_id: studentId,
    metadata: { expires_in_seconds: 600, bytes: payloadBytes },
  });
  if (auditError) {
    await removeDataExportObject(exportBucket, path);
    throw new HttpError("SERVICE_UNAVAILABLE", "Could not record the export event");
  }
  // Remove prior recent exports in bounded pages. The daily retention worker also clears files older than 30 days.
  const obsolete: string[] = [];
  const pageSize = 1000;
  for (let offset = 0; offset < 10_000; offset += pageSize) {
    let page: { name: string }[] | null;
    try {
      const result = await admin.storage.from("data-exports").list(`${studentId}/exports`, { limit: pageSize, offset });
      if (result.error) break; // Keep the new signed export usable; the retention worker handles stale files later.
      page = result.data;
    } catch {
      break;
    }
    const rows = page ?? [];
    obsolete.push(...rows.filter((object) => object.name !== path.split("/").at(-1))
      .map((object) => `${studentId}/exports/${object.name}`).filter(isSafeDataExportObjectPath));
    if (rows.length < pageSize) break;
  }
  for (let start = 0; start < obsolete.length; start += 100) {
    try {
      const { error: cleanupError } = await admin.storage.from("data-exports").remove(obsolete.slice(start, start + 100));
      if (cleanupError) break; // Do not invalidate a successful download because best-effort old-file cleanup failed.
    } catch {
      break;
    }
  }
  return { body: { signed_url: signedUrl } };
});

Deno.serve(handler);
