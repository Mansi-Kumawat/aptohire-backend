import { z } from "zod";
export const CompleteSignupInputSchema = z.object({ portal: z.enum(["student", "university", "organization"]), application_ref: z.string().regex(/^AH-[A-Z2-9]{6}$/).optional() }).strict();
export const CompleteSignupOutputSchema = z.undefined();
