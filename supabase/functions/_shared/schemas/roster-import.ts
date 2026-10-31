import { z } from "npm:zod@3.23.8";
import { isSafeRosterCsvPath } from "../roster-utils.ts";

const CsvRowSchema = z.object({
  email: z.string().trim().email().max(254).optional().or(z.literal("")),
  full_name: z.string().trim().min(1).max(160),
  student_id_number: z.string().trim().max(120).optional().or(z.literal("")),
  program_level: z.enum(["ug", "pg"]),
  program: z.string().trim().max(160).optional().or(z.literal("")),
  year: z.union([
    z.number().int().min(1).max(10),
    z.string().trim().regex(/^\d{1,2}$/).transform(Number).pipe(z.number().int().min(1).max(10)),
  ]).optional().or(z.literal("")),
  status: z.enum(["incoming", "enrolled", "dropout", "alumni"]),
}).strict();

const RosterSourceSchema = z.union([
  z.object({ csv_path: z.string().trim().min(1).max(500) }).strict(),
  z.object({ rows: z.array(z.unknown()).min(1).max(500) }).strict(),
]);

export const RosterImportInputSchema = z.object({
  university_id: z.string().uuid(),
  source: RosterSourceSchema,
  dry_run: z.boolean().default(false),
}).strict().superRefine((input, context) => {
  if ("csv_path" in input.source && !isSafeRosterCsvPath(input.source.csv_path, input.university_id)) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ["source", "csv_path"], message: "CSV path must be a safe CSV inside this university's roster folder" });
  }
});

export const RosterImportOutputSchema = z.object({
  total: z.number().int().nonnegative(),
  valid: z.number().int().nonnegative(),
  invalid: z.array(z.object({ row: z.number().int().positive(), field: z.string(), reason: z.string() }).strict()),
  duplicates: z.number().int().nonnegative(),
  created: z.number().int().nonnegative(),
  updated: z.number().int().nonnegative(),
  matched_existing: z.number().int().nonnegative(),
  proposals_created: z.number().int().nonnegative(),
}).strict();

export const CsvRosterRowSchema = CsvRowSchema;
export type RosterImportInput = z.infer<typeof RosterImportInputSchema>;
