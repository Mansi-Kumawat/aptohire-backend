import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// URL.pathname leaves a leading slash before Windows drive letters. Convert the
// file URL with Node's platform-aware helper before joining repository paths.
const root = fileURLToPath(new URL('../', import.meta.url));
const functionsDir = join(root, 'supabase/functions');
const config = readFileSync(join(root, 'supabase/config.toml'), 'utf8');
const deno = JSON.parse(readFileSync(join(root, 'deno.json'), 'utf8'));
const edgeMap = JSON.parse(readFileSync(join(functionsDir, 'import_map.json'), 'utf8'));
const expectedMap = {
  '@supabase/supabase-js': 'npm:@supabase/supabase-js@2.45.4',
  '@std/assert': 'jsr:@std/assert@1',
  zod: 'npm:zod@3.23.8'
};
for (const [name, target] of Object.entries(expectedMap)) {
  if (deno.imports?.[name] !== target || edgeMap.imports?.[name] !== target) {
    throw new Error(`Deno and Supabase import maps must both pin ${name} to ${target}`);
  }
}
const functions = readdirSync(functionsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && !entry.name.startsWith('_') && entry.name !== 'tests')
  .map((entry) => entry.name);
for (const name of functions) {
  const section = new RegExp(`^\\[functions\\.${name.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&')}\\]$`, 'm');
  const start = config.search(section);
  if (start < 0) throw new Error(`Missing [functions.${name}] config section`);
  const rest = config.slice(start + config.slice(start).indexOf('\n') + 1);
  const next = rest.search(/^\[/m);
  const block = next < 0 ? rest : rest.slice(0, next);
  if (!/^import_map\s*=\s*"\.\/functions\/import_map\.json"\s*$/m.test(block)) {
    throw new Error(`[functions.${name}] must use the shared Supabase import map`);
  }
}
console.log(`Supabase Edge import-map check passed for ${functions.length} functions.`);
