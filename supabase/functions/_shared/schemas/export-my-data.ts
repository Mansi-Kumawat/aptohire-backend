import { z } from "npm:zod@3.23.8";

export const ExportMyDataInputSchema = z.object({}).strict();
export const ExportMyDataOutputSchema = z.object({ signed_url: z.string().url() }).strict();
