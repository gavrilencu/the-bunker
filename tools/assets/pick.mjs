// Usage: node pick.mjs <sheet tag_n, e.g. p1_0> <code> [code...] [--simplify r]
// Records the chosen contact-sheet candidates into picks.json (then run: node fetch.mjs --all)
import fs from 'node:fs';
import path from 'node:path';
import { CACHE_DIR, readPicks, writePicks } from './lib.mjs';
const args = process.argv.slice(2);
const si = args.indexOf('--simplify');
const simplify = si >= 0 ? +args.splice(si, 2)[1] : undefined;
const [sheet, ...codes] = args;
const index = JSON.parse(fs.readFileSync(path.join(CACHE_DIR, 'sheets', `sheet_${sheet}.json`), 'utf8'));
const picks = readPicks();
for (const code of codes) {
  const c = index[code];
  if (!c) { console.error('no candidate', code); continue; }
  const ref = c.source === 'polyhaven' ? `ph:${c.id}` : c.uid;
  picks[c.entryId] = { ref, ...(simplify ? { simplify } : {}) };
  console.log(`${c.entryId} <- ${c.name} (${ref})`);
}
writePicks(picks);
