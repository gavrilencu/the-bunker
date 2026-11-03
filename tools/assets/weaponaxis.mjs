// Usage: node weaponaxis.mjs <id...>  — estimates which local axis a weapon's barrel / axe head points along.
// Heuristic: along the longest horizontal axis, compare cross-section height (Y extent) of the two end slices:
// the thin end is the muzzle (guns); for an axe the thick/heavy end is the head. Grip = end with the lowest min-Y.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
const xf = (m, v) => [m[0]*v[0]+m[4]*v[1]+m[8]*v[2]+m[12], m[1]*v[0]+m[5]*v[1]+m[9]*v[2]+m[13], m[2]*v[0]+m[6]*v[1]+m[10]*v[2]+m[14]];
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
for (const id of process.argv.slice(2)) {
  const doc = await io.read(`../../assets/models/${id}/${id}.glb`);
  const pts = [];
  for (const node of doc.getRoot().listNodes()) {
    const mesh = node.getMesh(); if (!mesh) continue;
    const m = node.getWorldMatrix();
    for (const prim of mesh.listPrimitives()) {
      const pos = prim.getAttribute('POSITION'); const v = [0, 0, 0];
      for (let i = 0; i < pos.getCount(); i++) { pos.getElement(i, v); pts.push(xf(m, v)); }
    }
  }
  const mn = [0, 1, 2].map((a) => Math.min(...pts.map((p) => p[a]))), mx = [0, 1, 2].map((a) => Math.max(...pts.map((p) => p[a])));
  const ax = (mx[0] - mn[0]) >= (mx[2] - mn[2]) ? 0 : 2; const L = mx[ax] - mn[ax];
  const slice = (lo, hi) => pts.filter((p) => p[ax] >= mn[ax] + lo * L && p[ax] <= mn[ax] + hi * L);
  const stat = (s) => s.length ? { h: Math.max(...s.map((p) => p[1])) - Math.min(...s.map((p) => p[1])), minY: Math.min(...s.map((p) => p[1])), n: s.length } : { h: 0, minY: 9, n: 0 };
  const a = stat(slice(0, 0.15)), b = stat(slice(0.85, 1.0));
  const name = ax === 0 ? 'X' : 'Z';
  const thinEnd = a.h < b.h ? '-' : '+';
  const lowEnd = a.minY < b.minY ? '-' : '+';
  // grip for pistols: lowest vertices overall -> position along axis
  const low = pts.reduce((q, p) => (p[1] < q[1] ? p : q));
  const gripPos = ((low[ax] - mn[ax]) / L).toFixed(2);
  console.log(JSON.stringify({ id, size: [0, 1, 2].map((i) => +(mx[i] - mn[i]).toFixed(3)), longAxis: name,
    end_minus: { height: +a.h.toFixed(3), minY: +a.minY.toFixed(3) }, end_plus: { height: +b.h.toFixed(3), minY: +b.minY.toFixed(3) },
    thinEnd: thinEnd + name, lowestEnd: lowEnd + name, lowestPointAlong: gripPos }));
}
