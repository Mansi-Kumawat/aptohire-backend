import { z } from "zod";
import { parseStrictCsv } from "../_shared/csv.ts";
import { createAdminClient } from "../_shared/admin.ts";
import { HttpError } from "../_shared/errors.ts";
import { hmacHex, normalizeStudentId } from "../_shared/hash.ts";
import { withHandler } from "../_shared/handler.ts";
import { CsvRosterRowSchema, RosterImportInputSchema, RosterImportOutputSchema } from "../_shared/schemas/roster-import.ts";
import { isDuplicateRosterIdentity, isSafeRosterCsvPath, rosterStorageObjectSize } from "../_shared/roster-utils.ts";

const MAX_CSV_BYTES = 20 * 1024 * 1024;
const MAX_ROWS = 500;
type Row = Record<string, unknown>;
type BadRow = { row: number; field: string; reason: string };

const handler = withHandler({ auth: "jwt", roles: ["university"], input: RosterImportInputSchema, output: RosterImportOutputSchema }, async (input, context) => {
  const auth = context.auth;
  if (!auth) throw new HttpError("UNAUTHENTICATED", "Sign-in required");
  const { data: membership, error: memberError } = await auth.client.from("university_members")
    .select("university_id").eq("university_id", input.university_id).eq("user_id", auth.user.id).maybeSingle();
  if (memberError) throw new HttpError("SERVICE_UNAVAILABLE", "Membership check failed");
  if (!membership) throw new HttpError("FORBIDDEN", "You are not a member of this university");

  const admin = createAdminClient();
  const { data: university, error: universityError } = await admin.from("universities").select("id,status")
    .eq("id", input.university_id).maybeSingle();
  if (universityError) throw new HttpError("SERVICE_UNAVAILABLE", "University lookup failed");
  if (!university) throw new HttpError("NOT_FOUND", "University not found");

  let rawRows: Row[];
  let csvPath: string | null = null;
  if ("rows" in input.source) {
    rawRows = input.source.rows.map((value) => typeof value === "object" && value !== null && !Array.isArray(value) ? value as Row : {});
  } else {
    csvPath = input.source.csv_path;
    if (!isSafeRosterCsvPath(csvPath, input.university_id)) {
      throw new HttpError("FORBIDDEN", "CSV path must be inside this university's roster folder");
    }
    const separator = csvPath.lastIndexOf("/");
    const folder = csvPath.slice(0, separator);
    const fileName = csvPath.slice(separator + 1);
    const { data: fileList, error: listError } = await admin.storage.from("rosters").list(folder, { search: fileName, limit: 100 });
    if (listError) throw new HttpError("SERVICE_UNAVAILABLE", "Roster file size could not be verified");
    const listedFile = (fileList ?? []).find((item) => item.name === fileName) as unknown as { metadata?: unknown } | undefined;
    if (!listedFile) throw new HttpError("NOT_FOUND", "Roster CSV could not be read");
    const listedSize = rosterStorageObjectSize(listedFile.metadata);
    if (listedSize === undefined) throw new HttpError("SERVICE_UNAVAILABLE", "Roster file size could not be verified");
    if (listedSize > MAX_CSV_BYTES) throw new HttpError("VALIDATION_FAILED", "CSV exceeds the 20 MB limit");
    const { data: file, error: downloadError } = await admin.storage.from("rosters").download(csvPath);
    if (downloadError || !file) throw new HttpError("NOT_FOUND", "Roster CSV could not be read");
    if (file.size > MAX_CSV_BYTES) throw new HttpError("VALIDATION_FAILED", "CSV exceeds the 20 MB limit");
    const parsed = parseStrictCsv(await file.text());
    if (parsed.rows.length > MAX_ROWS) throw new HttpError("VALIDATION_FAILED", `CSV is limited to ${MAX_ROWS} rows`);
    rawRows = parsed.rows.map((cells) => Object.fromEntries(parsed.headers.map((header, index) => [header, cells[index]])));
  }
  if (rawRows.length > MAX_ROWS) throw new HttpError("VALIDATION_FAILED", `Import is limited to ${MAX_ROWS} rows`);

  const invalid: BadRow[] = [];
  const accepted: Array<{ sourceRow: number; row: z.infer<typeof CsvRosterRowSchema>; email: string | null; idHash: string | null }> = [];
  const seenKeys = new Set<string>();
  let duplicates = 0;
  const pepper = Deno.env.get("ID_HASH_PEPPER");
  for (let index = 0; index < rawRows.length; index++) {
    const parsed = CsvRosterRowSchema.safeParse(rawRows[index]);
    if (!parsed.success) {
      for (const issue of parsed.error.issues) invalid.push({ row: index + 2, field: issue.path.join(".") || "row", reason: issue.message });
      continue;
    }
    const email = parsed.data.email ? parsed.data.email.trim().toLowerCase() : null;
    const idText = parsed.data.student_id_number ? normalizeStudentId(parsed.data.student_id_number) : null;
    if (!email && !idText) {
      invalid.push({ row: index + 2, field: "email", reason: "Provide an email or student ID" });
      continue;
    }
    if (idText && !pepper) throw new HttpError("SERVICE_UNAVAILABLE", "ID hashing is not configured");
    const idHash = idText && pepper ? await hmacHex(pepper, idText) : null;
    if (isDuplicateRosterIdentity(seenKeys, email, idHash)) { duplicates++; continue; }
    accepted.push({ sourceRow: index + 2, row: parsed.data, email, idHash });
  }

  const rowsForRpc = accepted.map(({ row, email, idHash }) => ({
    student_id_hash: idHash,
    email,
    full_name: row.full_name,
    program_level: row.program_level || null,
    program: row.program || null,
    year: row.year === undefined || row.year === "" ? null : Number(row.year),
    status: row.status,
  }));
  const matchEnabled = university.status === "approved";
  const { data: counts, error: importError } = await admin.rpc("process_roster_import", {
    p_university_id: input.university_id,
    p_rows: rowsForRpc,
    p_match_enabled: matchEnabled,
    p_dry_run: input.dry_run,
    p_actor_id: auth.user.id,
  });
  if (importError || !counts?.[0]) {
    if (importError?.code === "42501") throw new HttpError("FORBIDDEN", "University membership is required");
    if (importError?.code === "P0002") throw new HttpError("NOT_FOUND", "University or roster row was not found");
    if (importError?.code === "23505") throw new HttpError("CONFLICT", "A roster identity conflicts with another row in this university");
    if (["22023", "22P02", "23514"].includes(importError?.code ?? "")) throw new HttpError("VALIDATION_FAILED", "One or more roster rows contain invalid values");
    throw new HttpError("SERVICE_UNAVAILABLE", "Roster import could not be completed");
  }
  const result = counts[0] as { created: number; updated: number; matched_existing: number; proposals_created: number };
  const created = Number(result.created), updated = Number(result.updated);
  const matchedExisting = Number(result.matched_existing), proposalsCreated = Number(result.proposals_created);

  // Dry runs intentionally retain the uploaded CSV so the identical path can be imported later.
  if (csvPath && !input.dry_run) {
    const { error } = await admin.storage.from("rosters").remove([csvPath]);
    if (error) throw new HttpError("SERVICE_UNAVAILABLE", "Import finished but the source CSV could not be deleted");
  }
  return { body: { total: rawRows.length, valid: accepted.length, invalid, duplicates, created, updated, matched_existing: matchedExisting, proposals_created: proposalsCreated } };
});

Deno.serve(handler);
