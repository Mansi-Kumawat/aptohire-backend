import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const seed = await readFile(new URL('../supabase/seed.sql', import.meta.url), 'utf8');

test('fictional affiliation seed clears final-state rows before replaying lifecycle upserts', () => {
  const resetBlock = seed.indexOf("-- Make reruns safe when the previous seed left these lifecycle fixtures at their final state.");
  const firstAffiliationInsert = seed.indexOf('insert into public.affiliations(');
  assert.ok(resetBlock >= 0 && resetBlock < firstAffiliationInsert, 'lifecycle cleanup must run before the first affiliation insert');
  const cleanup = seed.slice(resetBlock, firstAffiliationInsert);
  assert.match(cleanup, /seed:student:aarti/);
  assert.match(cleanup, /seed:unib:affiliation:aarti/);
  assert.match(cleanup, /seed:student:niya/);
  assert.match(cleanup, /seed:affiliation:niya:university-d/);
  assert.match(cleanup, /set is_current=false, ended_on=current_date/);
});
