// Usage:
//   node fetch.mjs <id> <sketchfabUid | ph:<polyhavenId>> [--simplify <ratio>] [--keep <nodeNameRegex>] [--yaw <deg>] [--rot x,y,z]   pick + download + process one model
//   node fetch.mjs --all [--force] [--jobs 3]                                    process every entry of picks.json
// Writes assets/models/<id>/<id>.glb, updates assets/models/manifest.json + CREDITS.md and tools/assets/picks.json
import {
  entryById, readPicks, writePicks, readManifest, writeManifest, sketchfabModelInfo, sketchfabDownloadGlb,
  polyhavenModels, polyhavenDownloadGltf, processModel,
} from './lib.mjs';

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); if (i < 0) return false; args.splice(i, 1); return true; };
const opt = (n, d) => { const i = args.indexOf(n); if (i < 0) return d; const v = args[i + 1]; args.splice(i, 2); return v; };
const force = flag('--force');
const all = flag('--all');
const jobs = +opt('--jobs', 3);
const simplifyArg = opt('--simplify');
const keepArg = opt('--keep');
const yawArg = opt('--yaw');
const rotArg = opt('--rot');

const picks = readPicks();
if (!all) {
  const [id, ref] = args;
  if (!entryById[id] || !ref) { console.error('usage: node fetch.mjs <id> <uid|ph:id> [--simplify r]'); process.exit(1); }
  picks[id] = { ref, ...(simplifyArg ? { simplify: +simplifyArg } : {}), ...(keepArg ? { keep: keepArg } : {}), ...(yawArg ? { yaw: +yawArg } : {}), ...(rotArg ? { rot: rotArg.split(',').map(Number) } : {}) };
  writePicks(picks);
}
const todo = all ? Object.keys(picks) : [args[0]];

let manifest = readManifest();
async function handle(id) {
  const entry = entryById[id];
  const { ref, simplify, keep, yaw, rot } = picks[id];
  if (!force && all && manifest[id] && manifest[id].ref === ref && (manifest[id].keep || null) === (keep || null) && (manifest[id].yaw || null) === (yaw || null) && JSON.stringify(manifest[id].rot || null) === JSON.stringify(rot || null)) { console.log(`= ${id} up to date`); return; }
  const t0 = Date.now();
  let meta, inPath;
  if (ref.startsWith('ph:')) {
    const pid = ref.slice(3);
    const a = (await polyhavenModels())[pid];
    if (!a) throw new Error(`unknown polyhaven id ${pid}`);
    inPath = await polyhavenDownloadGltf(pid, entry.tex >= 2048 ? '2k' : '1k');
    const authors = Object.keys(a.authors || {});
    meta = {
      title: a.name, author: authors.join(', '), author_url: '', source_url: `https://polyhaven.com/a/${pid}`,
      source: 'polyhaven', license: 'CC0',
    };
  } else {
    const info = await sketchfabModelInfo(ref);
    const lic = info.license?.label || info.license?.fullName || '';
    if (!['CC Attribution', 'CC0 Public Domain', 'CC Attribution-ShareAlike'].includes(lic)) throw new Error(`license not allowed: ${lic}`);
    inPath = await sketchfabDownloadGlb(ref);
    meta = {
      title: info.name, author: info.user?.displayName || info.user?.username, author_url: info.user?.profileUrl,
      source_url: info.viewerUrl, source: 'sketchfab',
      license: lic === 'CC Attribution' ? 'CC BY 4.0' : lic === 'CC0 Public Domain' ? 'CC0' : 'CC BY-SA 4.0',
    };
  }
  const st = await processModel(inPath, entry, { simplifyRatio: simplify, keep, yaw, rot });
  const sx = st.size_m;
  const facing = Math.abs(sx[0] - sx[2]) / Math.max(sx[0], sx[2]) > 0.15 ? (sx[0] > sx[2] ? 'long axis X' : 'long axis Z') : 'roughly square footprint';
  manifest = readManifest(); // re-read: other jobs may have written
  const prev = manifest[id] && manifest[id].ref === ref && (manifest[id].yaw || null) === (yaw || null) ? manifest[id] : {};
  manifest[id] = {
    file: `res://assets/models/${id}/${id}.glb`,
    ...meta,
    ref,
    ...(keep ? { keep } : {}),
    ...(yaw ? { yaw } : {}),
    ...(rot ? { rot } : {}),
    faces: st.faces,
    size_m: st.size_m,
    tex: st.tex,
    ...(st.animations.length ? { animations: st.animations } : {}),
    ...(st.cameras && st.cameras.length ? { cameras: st.cameras } : {}),
    ...(st.anim_ranges ? { anim_ranges: st.anim_ranges } : {}),
    notes: [facing, st.skinned ? 'skinned' : null, st.alpha.length ? `alpha: ${st.alpha.join(', ')}` : null, simplify ? `simplified x${simplify}` : null]
      .filter(Boolean).join('; '),
    // split parts (see split.mjs) stay valid while ref/yaw are unchanged
    ...(prev.parts ? { parts: prev.parts } : {}),
    ...(prev.hinge_hint ? { hinge_hint: prev.hinge_hint } : {}),
    ...(prev.notes_extra ? { notes_extra: prev.notes_extra } : {}),
  };
  writeManifest(manifest);
  console.log(`+ ${id}: ${meta.title} | ${st.faces} faces | ${(st.bytes / 1e6).toFixed(1)} MB | size ${st.size_m.join('x')} | ${((Date.now() - t0) / 1000).toFixed(0)}s${st.animations.length ? ' | anims: ' + st.animations.join(',') : ''}`);
}

const queue = [...todo];
const failures = [];
await Promise.all(Array.from({ length: Math.min(jobs, queue.length) }, async () => {
  while (queue.length) {
    const id = queue.shift();
    try { await handle(id); } catch (e) { failures.push(id); console.error(`! ${id}: ${e?.stack || e}`); }
  }
}));
if (failures.length) { console.error('FAILED:', failures.join(' ')); process.exitCode = 1; }
