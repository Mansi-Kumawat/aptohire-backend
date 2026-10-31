import { createAdminClient } from "../admin.ts";
import { mockAudit } from "./mock.ts";
import { evidenceItemFromRef } from "./evidence-item.ts";
import { postprocessAudit } from "./postprocess-audit.ts";

type ConfigRow = { key: string; value: unknown };
type SubmissionRow = {
  id: string; title: string; status: string; claimed_skill_ids: string[];
  video_path: string | null; video_url: string | null; video_seconds: number | null; originality_answers: unknown;
};
function configNumber(config: Map<string, unknown>, key: string, fallback: number): number {
  const value = config.get(key); return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function configBoolean(config: Map<string, unknown>, key: string, fallback: boolean): boolean {
  const value = config.get(key); return typeof value === "boolean" ? value : fallback;
}
function configString(config: Map<string, unknown>, key: string): string | null {
  const value = config.get(key); return typeof value === "string" ? value : null;
}

export async function processDemoAudit(runId: string, submissionId: string): Promise<void> {
  const admin = createAdminClient();
  let claimed = false;
  try {
    const { data: run, error: runError } = await admin.from("agent_runs").select("id,mode,status").eq("id", runId).maybeSingle();
    if (runError || !run || run.mode !== "mock" || run.status !== "queued") throw new Error("RUN_NOT_QUEUEABLE");
    const { data: submission, error: submissionError } = await admin.from("submissions")
      .select("id,title,status,claimed_skill_ids,video_path,video_url,video_seconds,originality_answers")
      .eq("id", submissionId).maybeSingle();
    if (submissionError || !submission || submission.status !== "auditing" || !submission.claimed_skill_ids?.length) throw new Error("SUBMISSION_NOT_AUDITING");
    const row = submission as SubmissionRow;
    const { data: claimedRun, error: stageError } = await admin.from("agent_runs").update({ stage: "reading", status: "running" })
      .eq("id", runId).eq("status", "queued").select("id").maybeSingle();
    if (stageError || !claimedRun) throw new Error("RUN_NOT_CLAIMABLE");
    claimed = true;

    const configResult = await admin.from("app_config").select("key,value").in("key", ["PASS_MARK", "BORDERLINE", "AGENT_MODE", "AI_KILL_SWITCH"]);
    if (configResult.error) throw new Error("SCORING_CONFIG_UNAVAILABLE");
    const config = new Map<string, unknown>(((configResult.data ?? []) as ConfigRow[]).map((item) => [item.key, item.value]));
    if (configString(config, "AGENT_MODE") !== "mock" || configBoolean(config, "AI_KILL_SWITCH", true)) throw new Error("AUDIT_MODE_DISABLED");
    const passMark = configNumber(config, "PASS_MARK", NaN);
    const border = config.get("BORDERLINE");
    if (!Number.isFinite(passMark) || passMark < 0 || passMark > 100 || !Array.isArray(border) || border.length !== 2 ||
      !border.every((n) => typeof n === "number" && Number.isFinite(n) && n >= 0 && n <= 100) || border[0] > border[1]) {
      throw new Error("SCORING_CONFIG_INVALID");
    }
    const borderlineLow = border[0] as number;
    const borderlineHigh = border[1] as number;

    const untrustedContent = `${row.title}\n${JSON.stringify(row.originality_answers ?? {})}`.slice(0, 20_000);
    const { error: scoringStageError } = await admin.from("agent_runs").update({ stage: "scoring" }).eq("id", runId);
    if (scoringStageError) throw new Error("RUN_STAGE_UPDATE_FAILED");
    const raw = await mockAudit({
      submission_id: submissionId,
      title: row.title,
      // A submission identifier is only a record locator, not evidence. The current demo worker
      // has no extracted repository/video bundle, so it must not fabricate citations or confidence.
      bundle_refs: [],
      prompt_version: "demo-mock@1",
      untrusted_content: untrustedContent,
    });
    const processed = postprocessAudit(raw, new Set(), untrustedContent, borderlineLow, borderlineHigh);

    // Mock mode is synthetic. It stores criterion detail plus one aggregate skill row per claim;
    // this is explicitly not represented as a real evaluation of uploaded work.
    const rubric = [
      ...processed.criteria.map((criterion) => ({ ...criterion, criterion: criterion.key })),
      ...row.claimed_skill_ids.map((skillId) => ({
        key: "skill_score",
        skill_id: skillId,
        score: processed.overall_score,
        confidence: processed.confidence,
        rationale: "Synthetic mock score for local demo only; not an evaluation of real work.",
        insufficient_evidence: true,
        evidence: [],
      })),
    ];
    const evidence = processed.criteria.flatMap((criterion) => criterion.evidence.flatMap((item) => {
      const normalized = evidenceItemFromRef(item.evidence_ref, item.excerpt);
      return normalized ? [normalized] : [];
    }));
    const { error: writingStageError } = await admin.from("agent_runs").update({ stage: "writing" }).eq("id", runId);
    if (writingStageError) throw new Error("RUN_STAGE_UPDATE_FAILED");
    const { data: audit, error: auditError } = await admin.from("audits").insert({
      submission_id: submissionId,
      rubric_version: processed.rubric_version,
      prompt_version: processed.prompt_version,
      overall_score: processed.overall_score,
      confidence: processed.confidence,
      summary: processed.summary,
      rubric,
      evidence,
      transcript: processed.transcript,
      visual_observations: processed.visual_observations,
      next_steps: processed.next_steps,
      review_status: "unreviewed",
      flags: processed.prompt_injection_attempt ? ["prompt_injection_attempt"] : [],
    }).select("id").single();
    if (auditError || !audit) throw new Error("AUDIT_WRITE_FAILED");
    const { error: applyError } = await admin.rpc("apply_audit", {
      p_audit_id: audit.id,
      p_pass_mark: passMark,
      p_borderline_low: borderlineLow,
      p_borderline_high: borderlineHigh,
    });
    if (applyError) throw new Error("AUDIT_APPLY_FAILED");
    const { error: doneError } = await admin.from("agent_runs").update({ stage: "done", status: "completed", error_code: null }).eq("id", runId);
    if (doneError) throw new Error("RUN_FINISH_FAILED");
  } catch {
    if (!claimed) return;
    await admin.from("agent_runs").update({ status: "failed", error_code: "AUDIT_PIPELINE_FAILED" }).eq("id", runId).eq("status", "running");
    await admin.from("submissions").update({ status: "failed", updated_at: new Date().toISOString() })
      .eq("id", submissionId).eq("status", "auditing");
  }
}
