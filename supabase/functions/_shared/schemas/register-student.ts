import { z } from "zod";
import { StudentIdNumberSchema } from "./student-id.ts";

const ChoiceSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("detect") }).strict(),
  z.object({ kind: z.literal("student_id"), university_id: z.string().uuid(), student_id_number: StudentIdNumberSchema }).strict(),
  z.object({ kind: z.literal("unregistered"), university_name: z.string().trim().min(1).max(160), university_id: z.string().uuid().optional() }).strict(),
]);

export const RegisterStudentInputSchema = z.object({
  full_name: z.string().trim().min(1).max(120),
  program_level: z.enum(["ug", "pg"]),
  year: z.number().int().min(1).max(10).optional(),
  choice: ChoiceSchema,
}).strict();

export const RegisterStudentOutputSchema = z.object({
  student_id: z.string().uuid(),
  outcome: z.enum(["verified_roster", "needs_student_id", "verified_student_id", "unverified", "confirm_existing", "roster_no_match"]),
  affiliation: z.object({ university_id: z.string().uuid().optional(), label: z.string(), verification: z.enum(["roster", "student_id", "unverified"]) }).strict().optional(),
  matched_existing_person: z.boolean(),
}).strict();
