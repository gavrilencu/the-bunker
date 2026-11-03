// Usage:
//   node search.mjs <id> [id...]        search candidates for given catalog ids
//   node search.mjs --prio 1            all entries of a priority
//   options: --per 8 (candidates per entry), --rows 6 (entries per sheet), --q "extra query"
// Output: .cache/candidates/<id>.json and contact sheets .cache/sheets/sheet_<n>.png + sheet_<n>.json (code -> candidate)
import fs from 'node:fs';
import path from 'node:path';
import { buildSheet } from './sheet.mjs';
import {
  catalog, entryById, CACHE_DIR, TOOL_DIR, sketchfabSearch, scoreSketchfab, pickThumb, polyhavenModels, phThumb, sleep,
} from './lib.mjs';

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(name); if (i < 0) return def; const v = args[i + 1]; args.splice(i, 2); return v; };
const prio = opt('--prio');
const per = +opt('--per', 8);
const rowsPerSheet = +opt('--rows', 6);
const extraQ = opt('--q');
const sheetTag = opt('--tag', String(Date.now()).slice(-6));
const ids = prio ? catalog.models.filter((m) => String(m.prio) === prio).map((m) => m.id) : args;
if (!ids.length) { console.error('no ids'); process.exit(1); }

const PH_HINTS = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'ph_hints.json'), 'utf8'));

const candDir = path.join(CACHE_DIR, 'candidates');
fs.mkdirSync(candDir, { recursive: true });

async function gather(entry) {
  const ph = await polyhavenModels();
  const out = [];
  for (const pid of PH_HINTS[entry.id] || []) {
    const a = ph[pid];
    if (!a) continue;
    out.push({ source: 'polyhaven', id: pid, name: a.name, faces: a.polycount, tex: a.max_resolution?.[0], thumb: a.thumbnail_url || phThumb(pid), score: 99 });
  }
  const seen = new Map();
  const queries = extraQ ? [extraQ] : entry.q.slice(0, 3);
  const jobs = [];
  queries.forEach((q, qi) => {
    jobs.push({ q, license: 'by', sort: '-likeCount' });
    jobs.push({ q, license: 'cc0', sort: '-likeCount' });
    if (qi === 0) { jobs.push({ q, license: 'by' }); jobs.push({ q, license: 'by-sa', sort: '-likeCount' }); }
  });
  for (const j of jobs) {
    try {
      const res = await sketchfabSearch(j.q, { license: j.license, sort: j.sort, maxFaces: entry.faces, rigged: entry.rigged });
      for (const m of res) if (!seen.has(m.uid)) seen.set(m.uid, m);
    } catch (e) { console.warn(`  search fail ${entry.id} "${j.q}": ${e.message}`); }
    await sleep(250);
  }
  const sf = [...seen.values()]
    .map((m) => ({ m, score: scoreSketchfab(m, entry) }))
    .filter((x) => x.score > -Infinity)
    .sort((a, b) => b.score - a.score)
    .map(({ m, score }) => ({
      source: 'sketchfab', uid: m.uid, name: m.name, author: m.user?.displayName, license: m.license?.label,
      likes: m.likeCount, views: m.viewCount, staff: !!m.staffpickedAt, faces: m.archives.glb.faceCount,
      mb: +(m.archives.glb.size / 1e6).toFixed(1), tex: m.archives.glb.textureMaxResolution, anims: m.animationCount,
      thumb: pickThumb(m), url: m.viewerUrl, score: +score.toFixed(2),
    }));
  return [...out, ...sf];
}

const rows = [];
for (const id of ids) {
  const entry = entryById[id];
  if (!entry) { console.warn('unknown id', id); continue; }
  process.stdout.write(`searching ${id} ... `);
  const cands = await gather(entry);
  fs.writeFileSync(path.join(candDir, `${id}.json`), JSON.stringify(cands, null, 1));
  console.log(`${cands.length} candidates`);
  rows.push({ entry, cands });
}
let n = 0;
for (let i = 0; i < rows.length; i += rowsPerSheet) {
  const f = await buildSheet(rows.slice(i, i + rowsPerSheet), n++, { per, sheetTag });
  console.log('sheet:', f);
}
