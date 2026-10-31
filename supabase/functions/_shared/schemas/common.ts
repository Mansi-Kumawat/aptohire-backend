import { z } from "npm:zod@3.23.8";

export const ScopeSchema = z.enum(["profile", "scorecard", "projects", "contact"]);
export const ProjectBriefSchema = z.object({
  title: z.string().min(1).max(100),
  objective: z.string().min(1).max(1200),
  deliverables: z.array(z.string().min(1).max(240)).min(1).max(8),
  rubric_version: z.string().min(1).max(80),
  level: z.enum(["Emerging", "Competent", "Proficient", "Advanced"]),
}).strict();
export const EvidenceItemSchema = z.object({
  criterion: z.string().min(1).max(120),
  evidence_ref: z.string().min(1).max(160),
  excerpt: z.string().max(1200).optional(),
}).strict();
export const CredentialResponseSchema = z.object({
  credential: z.object({
    credential_id: z.string().regex(/^[a-f0-9]{18}$/),
    issued_at: z.string(),
    last_updated: z.string(),
    display_name: z.string().optional(),
    affiliation: z.object({ label: z.string(), verification: z.enum(["roster", "student_id", "unverified"]) }).optional(),
    skills: z.array(z.object({ name: z.string(), level: z.string(), verified: z.boolean(), score: z.number().optional(), verified_on: z.string().optional() })),
    shared_fields: z.array(z.string()),
  }).strict(),
}).strict();
