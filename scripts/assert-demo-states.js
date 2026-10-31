import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const config = await readFile(path.join(root, "supabase", "config.toml"), "utf8");
const projectId = config.match(/^project_id\s*=\s*"([^"]+)"/m)?.[1];
if (!projectId) {
  console.error("Could not read project_id from supabase/config.toml");
  process.exit(1);
}
const sql = await readFile(path.join(root, "scripts", "assert-demo-states.sql"), "utf8");
const container = `supabase_db_${projectId.toLowerCase().replace(/[^a-z0-9_-]/g, "-")}`;
const child = spawn("docker", [
  "exec", "-i", container,
  "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1",
], { stdio: ["pipe", "inherit", "inherit"] });
child.on("error", (error) => {
  console.error(`Could not start Docker/psql: ${error.message}`);
  process.exitCode = 1;
});
child.on("close", (code) => {
  if (code === 0) console.log("Demo-state assertions passed.");
  else process.exitCode = code ?? 1;
});
child.stdin.end(sql);
