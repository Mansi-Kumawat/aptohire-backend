import { z } from "npm:zod@3.23.8";

// TODO(decision): confirm these operational limits with the product/security owner.
const BorderlineSchema = z.tuple([z.number().min(0).max(100), z.number().min(0).max(100)])
  .refine(([low, high]) => low <= high, "Lower threshold must not exceed upper threshold");
const MatchLevelFloorsSchema = z.object({
  Emerging: z.number().int().min(1).max(100),
  Competent: z.number().int().min(1).max(100),
  Proficient: z.number().int().min(1).max(100),
  Advanced: z.number().int().min(1).max(100),
}).strict().refine((v) => v.Emerging <= v.Competent && v.Competent <= v.Proficient && v.Proficient <= v.Advanced,
  "Level floors must be nondecreasing from Emerging through Advanced");

export const AdminUpdateConfigInputSchema = z.discriminatedUnion("key", [
  z.object({ key: z.literal("AGENT_MODE"), value: z.enum(["mock", "direct", "n8n"]) }).strict(),
  z.object({ key: z.literal("PASS_MARK"), value: z.number().min(0).max(100) }).strict(),
  z.object({ key: z.literal("REQUIRE_VIDEO"), value: z.boolean() }).strict(),
  z.object({ key: z.literal("AI_KILL_SWITCH"), value: z.boolean() }).strict(),
  z.object({ key: z.literal("AI_DAILY_CAP_PER_USER"), value: z.number().int().min(1).max(100) }).strict(),
  z.object({ key: z.literal("VIDEO_MAX_MB"), value: z.number().int().min(1).max(500) }).strict(),
  z.object({ key: z.literal("VIDEO_MAX_SECONDS"), value: z.number().int().min(1).max(3600) }).strict(),
  z.object({ key: z.literal("BORDERLINE"), value: BorderlineSchema }).strict(),
  z.object({ key: z.literal("MATCH_COVERAGE_FLOOR"), value: z.number().min(0.05).max(0.75).multipleOf(0.01) }).strict(),
  z.object({ key: z.literal("MATCH_LEVEL_FLOORS"), value: MatchLevelFloorsSchema }).strict(),
]);

export const AdminUpdateConfigOutputSchema = z.object({
  key: z.enum(["AGENT_MODE", "PASS_MARK", "REQUIRE_VIDEO", "AI_KILL_SWITCH", "AI_DAILY_CAP_PER_USER", "VIDEO_MAX_MB", "VIDEO_MAX_SECONDS", "BORDERLINE", "MATCH_COVERAGE_FLOOR", "MATCH_LEVEL_FLOORS"]),
  updated_at: z.string().datetime(),
}).strict();
