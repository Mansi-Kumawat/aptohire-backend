export type ParsedCsv = { headers: string[]; rows: string[][] };

export function parseStrictCsv(text: string): { headers: string[]; rows: string[][] } {
  text = text.replace(/^\uFEFF/, "");
  const records: string[][] = [];
  let row: string[] = [], cell = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') {
      if (cell.length) throw new Error("Malformed CSV quoting");
      quoted = true;
    } else if (ch === ",") { row.push(cell); cell = ""; }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(cell); cell = "";
      if (row.some((value) => value.trim() !== "")) records.push(row);
      row = [];
    } else cell += ch;
  }
  if (quoted) throw new Error("Malformed CSV quoting");
  row.push(cell);
  if (row.some((value) => value.trim() !== "")) records.push(row);
  if (records.length === 0) return { headers: [], rows: [] };
  const headers = records[0].map((value) => value.trim());
  if (headers.some((header) => !header) || new Set(headers).size !== headers.length) throw new Error("CSV headers must be non-empty and unique");
  return { headers, rows: records.slice(1).map((cells) => headers.map((_, index) => cells[index] ?? "")) };
}

