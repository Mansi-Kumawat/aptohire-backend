import { z } from "zod";

export const WithdrawAccessInputSchema = z.object({ request_id: z.string().uuid() }).strict();
export const WithdrawAccessOutputSchema = z.object({ status: z.literal("withdrawn") }).strict();
