import { z } from "npm:zod@3.23.8";
export const AdminViewStudentInputSchema = z.object({ student_id: z.string().uuid() }).strict();
const AffiliationSchema = z.object({ id: z.string().uuid(), university_id: z.string().uuid().nullable(), university_name_text: z.string().nullable(), verification: z.string(), program_level: z.string(), year: z.number().nullable(), status: z.string(), is_current: z.boolean() }).strict();
const SkillScoreSchema = z.object({ skill_id: z.string().uuid(), skill_name: z.string(), score: z.number(), level: z.string(), verified: z.boolean(), pending_review: z.boolean(), share_ok: z.boolean(), updated_at: z.string() }).strict();
const SubmissionSchema = z.object({ id: z.string().uuid(), title: z.string(), status: z.string(), created_at: z.string(), updated_at: z.string() }).strict();
export const AdminViewStudentOutputSchema = z.object({
  student: z.object({ id: z.string().uuid(), full_name: z.string(), primary_email: z.string().nullable(), headline: z.string().nullable(), bio: z.string().nullable(), location: z.string().nullable(), credential_id: z.string().nullable() }).strict(),
  affiliations: z.array(AffiliationSchema), skill_scores: z.array(SkillScoreSchema), submissions: z.array(SubmissionSchema),
}).strict();
