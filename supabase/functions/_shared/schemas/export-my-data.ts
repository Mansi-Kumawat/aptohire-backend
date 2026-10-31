import { z } from "zod";

export const ExportMyDataInputSchema = z.object({}).strict();
export const ExportMyDataOutputSchema = z.object({ signed_url: z.string().url() }).strict();
