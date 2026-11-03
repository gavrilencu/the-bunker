// Usage: node inspect.mjs <glb/gltf path | catalog id>  -> node tree with mesh bounds (helps choose --keep)
import fs from 'node:fs';
import path from 'node:path';
import { getIO, computeBounds, OUT_DIR, readPicks, RAW_DIR } from './lib.mjs';
let p = process.argv[2];
if (!fs.existsSync(p)) {
  const pk = readPicks()[p];
  p = pk && !pk.ref.startsWith('ph:') ? path.join(RAW_DIR, pk.ref, 'model.glb') : path.join(OUT_DIR, p, `${p}.glb`);
}
const io = await getIO();
const doc = await io.read(p);
const scene = doc.getRoot().getDefaultScene() || doc.getRoot().listScenes()[0];
const walk = (n, d) => {
  const m = n.getMesh();
  let extra = '';
  if (m) {
    const tmp = doc.getRoot().listScenes()[0];
    let f = 0; for (const pr of m.listPrimitives()) f += (pr.getIndices()?.getCount() ?? pr.getAttribute('POSITION').getCount()) / 3;
    const bb = computeBounds(n); extra = ` [mesh ${Math.round(f)}f size ${bb.size.map((v) => v.toFixed(2)).join('x')} minY ${bb.min[1].toFixed(2)}]`;
  }
  console.log('  '.repeat(d) + (n.getName() || '(node)') + extra);
  for (const c of n.listChildren()) walk(c, d + 1);
};
for (const n of scene.listChildren()) walk(n, 0);
const b = computeBounds(scene);
console.log('bounds size', b.size.map((v) => v.toFixed(3)).join(' x '));
console.log('anims', doc.getRoot().listAnimations().map((a) => a.getName()).join(', '));
