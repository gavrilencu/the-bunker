// Usage: node validate.mjs  -> re-reads every model in the manifest, checks fit/pivot, glTF extensions and sizes
import fs from 'node:fs';
import path from 'node:path';
import { catalog, entryById, readManifest, getIO, computeBounds, PROJECT_DIR, OUT_DIR } from './lib.mjs';
const io = await getIO();
const man = readManifest();
let total = 0, bad = 0;
const exts = new Map();
for (const [id, m] of Object.entries(man)) {
  const e = entryById[id];
  const files = [m.file, ...Object.values(m.parts || {})].map((f) => path.join(PROJECT_DIR, f.replace('res://', '')));
  for (const f of files) {
    if (!fs.existsSync(f)) { console.log('MISSING', id, f); bad++; continue; }
    total += fs.statSync(f).size;
    const doc = await io.read(f);
    for (const x of doc.getRoot().listExtensionsUsed()) { exts.set(x.extensionName, (exts.get(x.extensionName) || 0) + 1); if (['KHR_draco_mesh_compression', 'EXT_meshopt_compression'].includes(x.extensionName)) { console.log('COMPRESSED', id); bad++; } }
    if (f !== files[0]) continue;
    const b = computeBounds(doc.getRoot().getDefaultScene());
    const [mode, t] = e.fit;
    const dim = mode === 'h' ? b.size[1] : mode === 'l' ? Math.max(b.size[0], b.size[2]) : Math.max(...b.size);
    const cx = (b.min[0] + b.max[0]) / 2, cz = (b.min[2] + b.max[2]) / 2;
    const ok = Math.abs(dim - t) / t < 0.01 && Math.abs(b.min[1]) < 0.01 * t + 1e-4 && Math.abs(cx) < 0.01 * t + 1e-3 && Math.abs(cz) < 0.01 * t + 1e-3;
    if (!ok) { console.log('BAD FIT', id, dim, t, b.min, b.max); bad++; }
  }
}
const missing = catalog.models.filter((m) => !man[m.id]).map((m) => `${m.id}(p${m.prio})`);
console.log(`models: ${Object.keys(man).length}, total ${(total / 1e6).toFixed(1)} MB, problems: ${bad}`);
console.log('extensions used:', [...exts].map(([k, v]) => `${k}×${v}`).join(', ') || 'none');
console.log('missing:', missing.join(' ') || 'none');
