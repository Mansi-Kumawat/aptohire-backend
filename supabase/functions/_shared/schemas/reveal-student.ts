import { z } from "npm:zod@3.23.8";

export const RevealStudentInputSchema = z.object({ request_id: z.string().uuid() }).strict();
const LinkSchema = z.object({ label: z.string().max(80), url: z.string().url().max(2000) }).strict();
export const RevealStudentOutputSchema = z.object({
  request_id: z.string().uuid(),
  granted_scope: z.array(z.enum(["profile", "scorecard", "projects", "contact"])),
  expires_at: z.string().datetime(),
  profile: z.object({
    full_name: z.string(), headline: z.string().optional(), bio: z.string().optional(), location: z.string().optional(),
    links: z.array(LinkSchema).optional(), university: z.object({ name: z.string(), verification: z.string() }).strict().optional(), avatar_url: z.string().url().optional(),
  }).strict().optional(),
  scorecard: z.object({ skills: z.array(z.object({ name: z.string(), level: z.string(), score: z.number().optional(), verified: z.boolean(), verified_on: z.string().optional(), summary: z.string().optional() }).strict()) }).strict().optional(),
  projects: z.array(z.object({ id: z.string().uuid(), title: z.string(), description: z.string().optional(), skills: z.array(z.string()), live_url: z.string().url().optional(), github_url: z.string().url().optional(), files: z.array(z.object({ name: z.string(), url: z.string().url() }).strict()).optional(), video_url: z.string().url().optional() }).strict()).optional(),
  contact: z.object({ email: z.string().email() }).strict().optional(),
}).strict();
