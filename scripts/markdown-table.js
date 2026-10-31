// Split one pipe-delimited Markdown table row while preserving escaped `\\|` inside cells.
export function splitMarkdownTableRow(line) {
  const cells = [];
  let cell = "";
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (char === "\\" && line[index + 1] === "|") {
      cell += "\\|";
      index += 1;
    } else if (char === "|") {
      cells.push(cell.trim());
      cell = "";
    } else {
      cell += char;
    }
  }
  cells.push(cell.trim());
  if (cells[0] === "") cells.shift();
  if (cells.at(-1) === "") cells.pop();
  return cells;
}
