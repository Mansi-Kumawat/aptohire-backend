import { createAdminClient } from "../_shared/admin.ts";
import { withHandler } from "../_shared/handler.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex } from "../_shared/hash.ts";
import { buildTemplateBrief, nextProjectLevel, type AssignmentTemplate } from "../_shared/agents/project-assignment.ts";
import { chooseDiverseTemplate } from "../_shared/agents/project-similarity.ts";
import { chooseProjectVariation } from "../_shared/agents/project-variation.ts";
import { applyTemplateWording, personalizeTemplateBrief } from "../_shared/agents/project-assignment-llm.ts";
import { providerConfigFingerprint } from "../_shared/agents/providers/direct.ts";
import { isFictionalTestAccountEmail, isLocalSyntheticDirectOptedIn } from "../_shared/agents/synthetic-direct.ts";
import { dispatchN8nAgentJson, isSafeN8nAgentWebhookUrl } from "../_shared/agents/n8n-agent.ts";
import { scrubExcerpt } from "../_shared/agents/postprocess-audit.ts";
import { isLocalSyntheticN8nOptedIn } from "../_shared/agents/n8n-webhook.ts";
import { AssignProjectInputSchema, AssignProjectOutputSchema, ProjectBriefSchema, type ProjectBrief } from "../_shared/schemas/assign-project.ts";

type SkillRow = { id: string; slug: string; family_id: string };
type TemplateRow = AssignmentTemplate & { role_text: string | null };
type ScoreRow = { level: string };
type RecentRow = { template_id: string | null; brief: unknown };
type AssignmentTarget = { skill_slug: string } | { role_text: string };
function targetSkillSlug(target: AssignmentTarget): string | null {
  const value = (target as { skill_slug?: unknown }).skill_slug;
  return typeof value === "string" ? value : null;
}
function targetRoleText(target: AssignmentTarget): string | null {
  const value = (target as { role_text?: unknown }).role_text;
  return typeof value === "string" ? value : null;
}
function preservesTemplateFields(candidate: ProjectBrief, template: ProjectBrief): boolean {
  return candidate.level === template.level
    && JSON.stringify(candidate.target_skills) === JSON.stringify(template.target_skills)
    && JSON.stringify(candidate.deliverables) === JSON.stringify(template.deliverables)
    && JSON.stringify(candidate.constraints) === JSON.stringify(template.constraints)
    && JSON.stringify(candidate.suggested_stack ?? []) === JSON.stringify(template.suggested_stack ?? [])
    && candidate.estimated_hours === template.estimated_hours
    && JSON.stringify(candidate.rubric_preview) === JSON.stringify(template.rubric_preview);
}

const handler = withHandler({ auth: "jwt", roles: ["student"], input: AssignProjectInputSchema, output: AssignProjectOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const admin = createAdminClient();
  const { data: configRows, error: configError } = await admin.from("app_config").select("key,value").in("key", ["AI_KILL_SWITCH", "AI_DAILY_CAP_PER_USER", "AGENT_MODE"]);
  if (configError) throw new HttpError("SERVICE_UNAVAILABLE", "Project assignment is temporarily unavailable");
  const config = new Map<string, unknown>((configRows ?? []).map((row) => [row.key, row.value]));
  const killSwitch = config.get("AI_KILL_SWITCH");
  if (killSwitch === true || killSwitch === "true") throw new HttpError("KILL_SWITCH", "Project generation is temporarily paused");
  const rawAgentMode = config.get("AGENT_MODE");
  const agentMode = typeof rawAgentMode === "string" ? rawAgentMode : "mock";
  if (agentMode !== "mock" && agentMode !== "direct" && agentMode !== "n8n") throw new HttpError("SERVICE_UNAVAILABLE", "Agent mode is invalid");
  if (agentMode === "direct" && !isLocalSyntheticDirectOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("LLM_ALLOW_SYNTHETIC_DIRECT"))) throw new HttpError("SERVICE_UNAVAILABLE", "Direct LLM mode requires explicit local synthetic-data opt-in");
  if (agentMode === "direct" && !isFictionalTestAccountEmail(auth.user.email)) throw new HttpError("FORBIDDEN", "Direct LLM mode is restricted to fictional .test accounts");
  const n8nEndpoint = Deno.env.get("N8N_ASSIGN_WEBHOOK_URL") ?? "";
  const n8nRequestSecret = Deno.env.get("N8N_WEBHOOK_SECRET") ?? "";
  const n8nResponseSecret = Deno.env.get("CALLBACK_SECRET") ?? "";
  if (agentMode === "n8n" && (!isLocalSyntheticN8nOptedIn(Deno.env.get("APP_ENV"), Deno.env.get("N8N_ALLOW_SYNTHETIC")) ||
    !isFictionalTestAccountEmail(auth.user.email))) throw new HttpError("FORBIDDEN", "n8n assignment is restricted to opted-in local fictional accounts");
  if (agentMode === "n8n" && (!isSafeN8nAgentWebhookUrl(n8nEndpoint, "assign") || n8nRequestSecret.length < 32 || n8nResponseSecret.length < 32)) {
    throw new HttpError("SERVICE_UNAVAILABLE", "The n8n assignment workflow is not safely configured");
  }
  const dailyCapValue = config.get("AI_DAILY_CAP_PER_USER");
  const dailyCap = typeof dailyCapValue === "number" ? Math.max(1, Math.min(50, Math.floor(dailyCapValue))) : 5;
  const ratePepper = Deno.env.get("RATE_LIMIT_PEPPER");
  if (!ratePepper) throw new HttpError("SERVICE_UNAVAILABLE", "Project assignment is not configured");
  const userHash = await hmacHex(ratePepper, `assign-project:${auth.user.id}`);
  const { data: limitRows, error: limitError } = await admin.rpc("consume_rate_limit", {
    p_bucket: "assign-project", p_key_hash: userHash, p_max: dailyCap, p_window_seconds: 86400,
  });
  if (limitError || !limitRows?.[0]) throw new HttpError("SERVICE_UNAVAILABLE", "Project assignment rate limiter is unavailable");
  if (!limitRows[0].allowed) throw new HttpError("QUOTA_EXCEEDED", "Daily project assignment limit reached", undefined, limitRows[0].retry_after);

  const { data: student, error: studentError } = await auth.client.from("students").select("id").eq("user_id", auth.user.id).maybeSingle();
  if (studentError || !student) throw new HttpError("FORBIDDEN", "Complete student registration first");
  let targetSkills: SkillRow[] = [];
  let templates: TemplateRow[] = [];
  const requestedSkillSlug = targetSkillSlug(input.target);
  const requestedRoleText = targetRoleText(input.target);
  const targetLabel = requestedSkillSlug ?? requestedRoleText ?? "";
  if (requestedSkillSlug !== null) {
    const { data: target, error } = await auth.client.from("skills").select("id,slug,family_id").eq("slug", requestedSkillSlug).maybeSingle();
    if (error || !target) throw new HttpError("NO_TEMPLATE", "No project template is available for this skill");
    const { data: familySkills, error: familyError } = await auth.client.from("skills").select("id,slug,family_id").eq("family_id", target.family_id);
    if (familyError || !familySkills?.length) throw new HttpError("SERVICE_UNAVAILABLE", "Skill catalog is unavailable");
    targetSkills = familySkills as SkillRow[];
    const { data: rows, error: templateError } = await auth.client.from("project_templates").select("id,skill_id,role_text,level,title,brief").eq("active", true).in("skill_id", targetSkills.map((skill) => skill.id));
    if (templateError) throw new HttpError("SERVICE_UNAVAILABLE", "Project templates are unavailable");
    templates = (rows ?? []) as TemplateRow[];
  } else {
    const roleText = requestedRoleText;
    if (roleText === null) throw new HttpError("VALIDATION_FAILED", "A skill or role target is required");
    const normalizedRoleText = roleText.trim().toLocaleLowerCase();
    const { data: roleTemplates, error } = await auth.client.from("project_templates").select("id,skill_id,role_text,level,title,brief").eq("active", true).not("role_text", "is", null);
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Project templates are unavailable");
    const matching = (roleTemplates ?? []).filter((row) => typeof row.role_text === "string" && row.role_text.trim().toLocaleLowerCase() === normalizedRoleText);
    if (!matching.length) throw new HttpError("NO_TEMPLATE", "No project template is available for this role");
    const skillIds = [...new Set(matching.map((row) => row.skill_id).filter((id): id is string => typeof id === "string"))];
    if (skillIds.length) {
      const { data: skills, error: skillError } = await auth.client.from("skills").select("id,slug,family_id").in("id", skillIds);
      if (skillError) throw new HttpError("SERVICE_UNAVAILABLE", "Skill catalog is unavailable");
      targetSkills = (skills ?? []) as SkillRow[];
    }
    templates = matching as TemplateRow[];
  }
  if (!templates.length) throw new HttpError("NO_TEMPLATE", "No project template is available for this target");

  const primarySkillId = requestedSkillSlug !== null
    ? targetSkills.find((skill) => skill.slug === requestedSkillSlug)?.id
    : templates.find((template) => template.skill_id)?.skill_id;
  let currentLevel: string | null = null;
  if (primarySkillId) {
    const { data: score } = await auth.client.from("skill_scores").select("level").eq("student_id", student.id).eq("skill_id", primarySkillId).maybeSingle();
    currentLevel = (score as ScoreRow | null)?.level ?? null;
  }
  const desiredLevel = input.level ?? nextProjectLevel(currentLevel);
  const levelTemplates = templates.filter((template) => template.level === desiredLevel);
  if (!levelTemplates.length) throw new HttpError("NO_TEMPLATE", "No project template is available at the next level");

  const recentSince = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const { data: recentRows, error: recentError } = await auth.client.from("project_assignments").select("template_id,brief").eq("student_id", student.id).gte("created_at", recentSince);
  if (recentError) throw new HttpError("SERVICE_UNAVAILABLE", "Recent project history is unavailable");
  const recentAssignments = (recentRows ?? []) as RecentRow[];
  const recentIds = new Set(recentAssignments.map((row) => row.template_id).filter((id): id is string => typeof id === "string"));
  const selectionSeed = `${auth.user.id}:${targetLabel}:${new Date().toISOString().slice(0, 10)}`;
  const selected = chooseDiverseTemplate(
    levelTemplates,
    recentIds,
    recentAssignments.map((row) => row.brief),
    selectionSeed,
    (candidate) => {
      const candidateSkillIds = candidate.skill_id ? [candidate.skill_id] : targetSkills.map((skill) => skill.id);
      const candidateSkillSlugs = targetSkills.filter((skill) => candidateSkillIds.includes(skill.id)).map((skill) => skill.slug);
      return buildTemplateBrief(candidate, candidateSkillSlugs, desiredLevel);
    },
  );
  if (!selected) throw new HttpError("NO_TEMPLATE", "All suitable projects were assigned recently; try again later");

  const variationSince = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();
  const { data: fingerprintRows, error: fingerprintError } = await admin.from("project_assignments")
    .select("variation_fingerprint").eq("template_id", selected.id).gte("created_at", variationSince)
    .not("variation_fingerprint", "is", null).order("created_at", { ascending: false }).limit(5000);
  if (fingerprintError) throw new HttpError("SERVICE_UNAVAILABLE", "Project variation history is unavailable");
  const fingerprintCounts = new Map<string, number>();
  for (const row of fingerprintRows ?? []) {
    if (typeof row.variation_fingerprint === "string") {
      fingerprintCounts.set(row.variation_fingerprint, (fingerprintCounts.get(row.variation_fingerprint) ?? 0) + 1);
    }
  }
  const variation = await chooseProjectVariation(selected, `${selectionSeed}:${selected.id}`, ratePepper, fingerprintCounts);
  const selectedTemplate = variation.template;
  const templateSkillIds = selectedTemplate.skill_id ? [selectedTemplate.skill_id] : targetSkills.map((skill) => skill.id);
  const briefSkills = targetSkills.filter((skill) => templateSkillIds.includes(skill.id)).map((skill) => skill.slug);
  const templateBrief = buildTemplateBrief(selectedTemplate, briefSkills, desiredLevel);
  const startedAt = Date.now();
  const promptVersion = "assign@1";
  const providerConfig = providerConfigFingerprint("fast");
  const inputHash = await hmacHex(ratePepper, `${promptVersion}:${selected.id}:${targetLabel}:${JSON.stringify(templateBrief)}:${providerConfig}`);
  let brief = templateBrief;
  let provider = "mock";
  let model = "deterministic-template-v1";
  let tokenEstimate: number | null = null;
  if (agentMode === "direct") {
    try {
      const cacheResult = await admin.rpc("read_agent_response_cache", { p_kind: "assign", p_input_hash: inputHash, p_prompt_version: promptVersion });
      const cached = (cacheResult.data as { output?: unknown; provider?: string; model?: string }[] | null)?.[0];
      const allowedProviders = new Set(["gemini", "groq", "openrouter"]);
      let cacheUsed = false;
      if (!cacheResult.error && cached && typeof cached.provider === "string" && allowedProviders.has(cached.provider) && typeof cached.model === "string") {
        try {
          const cachedBrief = ProjectBriefSchema.parse(cached.output);
          if (preservesTemplateFields(cachedBrief, templateBrief)) {
            brief = cachedBrief;
            provider = cached.provider;
            model = cached.model;
            cacheUsed = true;
          }
        } catch { /* invalid cache entries are ignored and regenerated */ }
      }
      if (!cacheUsed) {
        const personalized = await personalizeTemplateBrief(templateBrief, targetLabel, undefined, async (providerName) => {
          const rawCap = Number(Deno.env.get("LLM_DAILY_CAP_PER_PROVIDER") ?? 1000);
          const max = Number.isInteger(rawCap) && rawCap > 0 ? Math.min(rawCap, 100_000) : 1000;
          const providerHash = await hmacHex(ratePepper, `llm-provider:${providerName}`);
          const { data, error } = await admin.rpc("consume_rate_limit", {
            p_bucket: `llm-provider:${providerName}`, p_key_hash: providerHash, p_max: max, p_window_seconds: 86400,
          });
          if (error || !data?.[0]) throw new Error("PROVIDER_CAP_UNAVAILABLE");
          return data[0].allowed === true;
        });
        brief = personalized.brief;
        provider = personalized.provider;
        model = personalized.model;
        tokenEstimate = personalized.tokenEstimate;
        await admin.rpc("store_agent_response_cache", { p_kind: "assign", p_input_hash: inputHash, p_prompt_version: promptVersion, p_output: brief, p_provider: provider, p_model: model });
      }
    } catch {
      await admin.from("agent_runs").insert({ user_id: auth.user.id, kind: "assign", mode: agentMode, status: "failed", stage: "writing", error_code: "DIRECT_PROVIDER_FAILED", prompt_version: promptVersion, input_hash: inputHash, latency_ms: Date.now() - startedAt, started_at: new Date(startedAt).toISOString(), finished_at: new Date().toISOString() });
      throw new HttpError("SERVICE_UNAVAILABLE", "Project wording assistance is temporarily unavailable");
    }
  }
  if (agentMode === "n8n") {
    const n8nRunId = crypto.randomUUID();
    const result = await dispatchN8nAgentJson({
      endpoint: n8nEndpoint, appEnv: Deno.env.get("APP_ENV"), syntheticOptIn: Deno.env.get("N8N_ALLOW_SYNTHETIC"),
      requestSecret: n8nRequestSecret, responseSecret: n8nResponseSecret, runId: n8nRunId, kind: "assign", promptVersion,
      payload: { template: templateBrief, target_label: scrubExcerpt(targetLabel).slice(0, 120) },
    });
    if (result !== null) {
      try {
        const personalized = applyTemplateWording(templateBrief, result);
        if (!preservesTemplateFields(personalized, templateBrief)) throw new Error("TEMPLATE_FIELDS_CHANGED");
        brief = personalized;
        provider = "n8n";
        model = "configured-n8n-assignment";
      } catch {
        provider = "deterministic-template";
        model = "n8n-output-rejected-fallback";
      }
    } else {
      provider = "deterministic-template";
      model = "n8n-unavailable-fallback";
    }
  }
  const { error: runError } = await admin.from("agent_runs").insert({
    user_id: auth.user.id, kind: "assign", mode: agentMode, status: "completed", stage: "done", provider, model,
    prompt_version: promptVersion, input_hash: inputHash, latency_ms: Date.now() - startedAt, token_estimate: tokenEstimate,
    started_at: new Date(startedAt).toISOString(), finished_at: new Date().toISOString(),
  });
  if (runError) throw new HttpError("SERVICE_UNAVAILABLE", "Assignment run could not be recorded");
  const { data: assignment, error: insertError } = await auth.client.from("project_assignments").insert({
    student_id: student.id,
    template_id: selected.id,
    status: "assigned",
    brief,
    variation_fingerprint: variation.fingerprint,
  }).select("id").single();
  if (insertError || !assignment) throw new HttpError("SERVICE_UNAVAILABLE", "Project assignment could not be saved");
  return { status: 201, body: { assignment_id: assignment.id, brief } };
});

Deno.serve(handler);
