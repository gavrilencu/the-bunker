// Usage: node adhoc.mjs <entryId> <tag> "query1" "query2" ... [--animated]
//   -> merged top-16 candidates in .cache/candidates/<id>__<tag>.json + contact sheet .cache/sheets/sheet_<id>_<tag>_0.png (codes 0a..1h)
import fs from 'node:fs';
import path from 'node:path';
import { entryById, CACHE_DIR, fetchJson, scoreSketchfab, pickThumb, sleep } from './lib.mjs';
import { buildSheet } from './sheet.mjs';
const args = process.argv.slice(2);
const animated = args.includes('--animated'); const a2 = args.filter((x) => x !== '--animated');
const [id, tag, ...qs] = a2;
const entry = { ...entryById[id] };
const seen = new Map();
for (const q of qs) for (const license of ['by', 'cc0', 'by-sa']) for (const sort of ['-likeCount', null]) {
  const p = new URLSearchParams({ type: 'models', downloadable: 'true', q, count: '24', license, max_face_count: String(entry.faces) });
  if (sort) p.set('sort_by', sort);
  if (animated) p.set('animated', 'true');
  try { for (const m of (await fetchJson(`https://api.sketchfab.com/v3/search?${p}`)).results) seen.set(m.uid, m); } catch (e) { console.warn(e.message); }
  await sleep(200);
}
const cands = [...seen.values()].map((m) => ({ m, s: scoreSketchfab(m, entry) })).filter((x) => x.s > -Infinity).sort((a, b) => b.s - a.s).slice(0, 16)
  .map(({ m, s }) => ({ source: 'sketchfab', uid: m.uid, name: m.name, author: m.user?.displayName, license: m.license?.label, likes: m.likeCount, views: m.viewCount, staff: !!m.staffpickedAt, faces: m.archives.glb.faceCount, mb: +(m.archives.glb.size / 1e6).toFixed(1), tex: m.archives.glb.textureMaxResolution, anims: m.animationCount, thumb: pickThumb(m), url: m.viewerUrl, score: +s.toFixed(2) }));
fs.mkdirSync(path.join(CACHE_DIR, 'candidates'), { recursive: true });
fs.writeFileSync(path.join(CACHE_DIR, 'candidates', `${id}__${tag}.json`), JSON.stringify(cands, null, 1));
console.log(cands.length, 'candidates');
const half = [cands.slice(0, 8), cands.slice(8, 16)].filter((x) => x.length);
console.log('sheet:', await buildSheet(half.map((c) => ({ entry, cands: c })), 0, { per: 8, sheetTag: `${id}_${tag}` }));
