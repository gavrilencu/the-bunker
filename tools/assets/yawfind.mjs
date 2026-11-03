// Usage: node yawfind.mjs <glb>  -> yaw (deg) that best aligns dominant planar faces with the X or Z axis
import { getIO } from './lib.mjs';
const io = await getIO();
const doc = await io.read(process.argv[2]);
const pts = [];
doc.getRoot().getDefaultScene().traverse((n) => { const m = n.getMesh(); if (!m) return; const w = n.getWorldMatrix();
  for (const p of m.listPrimitives()) { const a = p.getAttribute('POSITION'); const v = [0, 0, 0];
    for (let i = 0; i < a.getCount(); i++) { a.getElement(i, v); pts.push([w[0]*v[0]+w[4]*v[1]+w[8]*v[2]+w[12], w[2]*v[0]+w[6]*v[1]+w[10]*v[2]+w[14]]); } } });
let best = { s: -1 };
for (let d = -45; d <= 45; d += 0.25) {
  const r = d * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
  let score = 0;
  for (const ax of [0, 1]) {
    const h = new Map();
    for (const [x, z] of pts) { const u = ax ? (-s * x + c * z) : (c * x + s * z); const k = Math.round(u / 0.01); h.set(k, (h.get(k) || 0) + 1); }
    const top = [...h.values()].sort((a, b) => b - a).slice(0, 5).reduce((a, b) => a + b, 0);
    score += top;
  }
  if (score > best.s) best = { s: score, d };
}
console.log('best yaw (deg) to apply:', -best.d, ' score', best.s, ' points', pts.length);
