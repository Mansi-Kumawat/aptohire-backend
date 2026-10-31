import { z } from "zod";

export const DeleteMyAccountInputSchema = z.object({
  password: z.string().min(1).max(1024),
  confirm: z.literal("DELETE"),
}).strict();

export const DeleteMyAccountOutputSchema = z.object({}).strict();
