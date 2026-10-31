import { z } from "npm:zod@3.23.8";

export const StudentIdNumberSchema = z.string().trim().min(1).max(120).refine(
  (value) => /[\p{L}\p{N}]/u.test(value.normalize("NFKC")),
  { message: "Student ID must contain at least one letter or number" },
);
