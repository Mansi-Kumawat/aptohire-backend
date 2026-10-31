import { z } from "zod";
import { StudentIdNumberSchema } from "./student-id.ts";

const NewAffiliationSchema = z.object({
  university_id: z.string().uuid().optional(),
  university_name_text: z.string().trim().min(1).max(160).optional(),
  student_id_number: StudentIdNumberSchema.optional(),
  program_level: z.enum(["ug", "pg"]),
  year: z.number().int().min(1).max(10).optional(),
  status: z.enum(["incoming", "enrolled", "alumni", "dropout"]).default("enrolled"),
}).strict().refine((value) => Boolean(value.university_id || value.university_name_text), {
  message: "Choose a registered university or enter its name",
  path: ["university_id"],
}).refine((value) => !value.student_id_number || Boolean(value.university_id), {
  message: "A student ID can only be checked against a registered university",
  path: ["student_id_number"],
});

export const ConfirmAffiliationInputSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("proposal"), proposal_id: z.string().uuid() }).strict(),
  z.object({ kind: z.literal("new"), new: NewAffiliationSchema }).strict(),
]);

export const ConfirmAffiliationOutputSchema = z.object({
  affiliation: z.object({
    id: z.string().uuid(),
    university_id: z.string().uuid().nullable(),
    university_name_text: z.string().nullable(),
    verification: z.enum(["roster", "student_id", "unverified"]),
    program_level: z.enum(["ug", "pg"]).nullable(),
    year: z.number().int().nullable(),
    status: z.enum(["incoming", "enrolled", "alumni", "dropout"]),
    is_current: z.literal(true),
  }).strict(),
}).strict();
