import { z } from "npm:zod@3.23.8";

const UUID = z.string().uuid();
const SourceId = UUID;
const ProposalChangeSchema = z.object({
  field: z.enum(["headline", "skills_interest", "experience", "education", "links", "project_candidate"]),
  action: z.enum(["add", "update"]),
  value: z.unknown(),
  evidence: z.string().min(1).max(500),
}).strict();
const ProposalSchema = z.object({
  source: z.enum(["github", "linkedin_export"]),
  changes: z.array(ProposalChangeSchema).max(30),
}).strict();

export const ProfileSyncInputSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("github_start") }).strict(),
  z.object({ action: z.literal("github_sync"), source_id: SourceId }).strict(),
  z.object({
    action: z.literal("linkedin_parse"),
    source_id: SourceId.optional(),
    text: z.string().max(20_000).optional(),
    file_path: z.string().max(1024).optional(),
  }).strict(),
  z.object({ action: z.literal("revoke"), source_id: SourceId, delete_data: z.boolean().optional() }).strict(),
]).superRefine((value, context) => {
  if (value.action === "linkedin_parse" && Boolean(value.text?.trim()) === Boolean(value.file_path)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: "Provide either text or file_path, but not both" });
  }
});

export const ProfileSyncOutputSchema = z.union([
  z.object({ authorize_url: z.string().url().refine((value) => {
    try { return new URL(value).protocol === "https:"; } catch { return false; }
  }) }).strict(),
  z.object({ proposals: z.array(ProposalSchema).optional(), last_synced_at: z.string().datetime() }).strict(),
]);

export type ProfileSyncInput = z.infer<typeof ProfileSyncInputSchema>;
export type ProfileProposal = z.infer<typeof ProposalSchema>;
