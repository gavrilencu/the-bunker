// Usage: node joinmesh.mjs <id...>
//   Static models made of many small mesh nodes (cars: bolts, trims, lamps...) cost one draw
//   call per node. Flattens the hierarchy and joins primitives that share a material, in place.
import path from 'node:path';
import { flatten, join, prune, dedup } from '@gltf-transform/functions';
import { getIO, OUT_DIR } from './lib.mjs';

const io = await getIO();
for (const id of process.argv.slice(2)) {
  const file = path.join(OUT_DIR, id, `${id}.glb`);
  const doc = await io.read(file);
  if (doc.getRoot().listSkins().length) { console.log(`${id}: skinned, skipped`); continue; }
  const before = doc.getRoot().listNodes().filter((n) => n.getMesh()).length;
  await doc.transform(dedup(), flatten(), join({ keepNamed: false }), prune());
  const after = doc.getRoot().listNodes().filter((n) => n.getMesh()).length;
  const prims = doc.getRoot().listMeshes().reduce((a, m) => a + m.listPrimitives().length, 0);
  await io.write(file, doc);
  console.log(`${id}: mesh nodes ${before} -> ${after}, primitives ${prims}`);
}
