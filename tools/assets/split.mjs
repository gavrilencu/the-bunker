// Split an already-normalized model into two GLBs by triangle centroid (same coordinate frame, so they line up).
// Usage: node split.mjs <id> <partA> <partB> <axis x|y|z> <lt|gt> <value> [--hinge]
//   -> assets/models/<id>/<id>_<partA>.glb  (triangles whose centroid <axis> <lt|gt> value)
//      assets/models/<id>/<id>_<partB>.glb  (the rest)
// With --hinge, writes a vertical hinge hint for part A (corner of A's bbox closest to B's bbox center) into the manifest.
import path from 'node:path';
import { compactPrimitive, prune } from '@gltf-transform/functions';
import { getIO, computeBounds, OUT_DIR, readManifest, writeManifest } from './lib.mjs';

const [id, partA, partB, axisName, op, valueStr, ...rest] = process.argv.slice(2);
const axis = { x: 0, y: 1, z: 2 }[axisName];
const value = +valueStr;
const io = await getIO();
const src = path.join(OUT_DIR, id, `${id}.glb`);

function mulv(w, v) { return [w[0]*v[0]+w[4]*v[1]+w[8]*v[2]+w[12], w[1]*v[0]+w[5]*v[1]+w[9]*v[2]+w[13], w[2]*v[0]+w[6]*v[1]+w[10]*v[2]+w[14]]; }

async function makePart(keepA) {
  const doc = await io.read(src);
  const scene = doc.getRoot().getDefaultScene();
  scene.traverse((node) => {
    const mesh = node.getMesh();
    if (!mesh) return;
    const w = node.getWorldMatrix();
    for (const prim of mesh.listPrimitives()) {
      if (prim.getMode() !== 4) continue;
      const pos = prim.getAttribute('POSITION');
      let idx = prim.getIndices();
      const n = idx ? idx.getCount() : pos.getCount();
      const get = idx ? (i) => idx.getScalar(i) : (i) => i;
      const out = [];
      const v = [0, 0, 0];
      for (let t = 0; t < n; t += 3) {
        let c = 0;
        for (let k = 0; k < 3; k++) { pos.getElement(get(t + k), v); c += mulv(w, v)[axis]; }
        c /= 3;
        const inA = op === 'lt' ? c < value : c > value;
        if (inA === keepA) out.push(get(t), get(t + 1), get(t + 2));
      }
      if (!out.length) { prim.dispose(); continue; }
      const arr = pos.getCount() > 65535 ? new Uint32Array(out) : new Uint16Array(out);
      const acc = doc.createAccessor().setType('SCALAR').setArray(arr).setBuffer(doc.getRoot().listBuffers()[0]);
      prim.setIndices(acc);
      compactPrimitive(prim);
    }
    if (!mesh.listPrimitives().length) node.setMesh(null);
  });
  await doc.transform(prune());
  const file = path.join(OUT_DIR, id, `${id}_${keepA ? partA : partB}.glb`);
  await io.write(file, doc);
  const b = computeBounds((await io.read(file)).getRoot().getDefaultScene());
  return { file, b };
}

const A = await makePart(true);
const B = await makePart(false);
console.log(partA, A.b.min.map((x) => x.toFixed(2)), A.b.max.map((x) => x.toFixed(2)));
console.log(partB, B.b.min.map((x) => x.toFixed(2)), B.b.max.map((x) => x.toFixed(2)));
const man = readManifest();
if (man[id]) {
  man[id].parts = {
    [partA]: `res://assets/models/${id}/${id}_${partA}.glb`,
    [partB]: `res://assets/models/${id}/${id}_${partB}.glb`,
  };
  if (rest.includes('--hinge')) {
    const bc = [(B.b.min[0] + B.b.max[0]) / 2, (B.b.min[2] + B.b.max[2]) / 2];
    const cx = Math.abs(A.b.min[0] - bc[0]) < Math.abs(A.b.max[0] - bc[0]) ? A.b.min[0] : A.b.max[0];
    const cz = Math.abs(A.b.min[2] - bc[1]) < Math.abs(A.b.max[2] - bc[1]) ? A.b.min[2] : A.b.max[2];
    man[id].hinge_hint = { part: partA, axis: 'Y', point: [+cx.toFixed(3), 0, +cz.toFixed(3)], note: 'approximate vertical hinge axis (from bbox); leaf is modeled OPEN, rotate about this axis ~90 deg to close, tune visually' };
  }
  writeManifest(man);
}
