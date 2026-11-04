// Usage: node texfix.mjs            -> every model folder + every texture set
//   Godot only switches textures to VRAM compression ("Detect 3D") when the editor sees them
//   used by a 3D material. Textures loaded from code, and many extracted from GLBs, stay
//   lossless: slow to load, heavy in VRAM. This writes the final import settings directly:
//   VRAM compressed (BC7 for colour, BC5 for normal maps), mipmaps, no further detection.
import fs from 'node:fs';
import path from 'node:path';
import { getIO, OUT_DIR, PROJECT_DIR } from './lib.mjs';

const io = await getIO();
let changed = 0;

function patch(imp, role) {
  let s = fs.readFileSync(imp, 'utf8');
  const before = s;
  const setv = (k, v) => {
    const re = new RegExp(`^${k.replace('/', '\\/')}=.*$`, 'm');
    s = re.test(s) ? s.replace(re, `${k}=${v}`) : s.replace('[params]', `[params]\n${k}=${v}`);
  };
  setv('compress/mode', 2);
  setv('compress/high_quality', role === 'normal' ? 'false' : 'true');
  setv('compress/normal_map', role === 'normal' ? 1 : 2);
  setv('mipmaps/generate', 'true');
  setv('detect_3d/compress_to', 0);
  if (s !== before) { fs.writeFileSync(imp, s); changed++; }
}

// model folders: roles from the GLB materials
for (const id of fs.readdirSync(OUT_DIR)) {
  const dir = path.join(OUT_DIR, id);
  if (!fs.statSync(dir).isDirectory()) continue;
  const imps = fs.readdirSync(dir).filter((f) => /\.(jpg|jpeg|png|webp)\.import$/i.test(f));
  if (!imps.length) continue;
  const roles = new Map(); // key (index or image name) -> role
  const glb = path.join(dir, `${id}.glb`);
  if (fs.existsSync(glb)) {
    try {
      const doc = await io.read(glb);
      const texs = doc.getRoot().listTextures();
      const role = new Map();
      for (const m of doc.getRoot().listMaterials()) {
        if (m.getNormalTexture()) role.set(m.getNormalTexture(), 'normal');
        for (const t of [m.getBaseColorTexture(), m.getEmissiveTexture()]) if (t && !role.has(t)) role.set(t, 'color');
        for (const t of [m.getMetallicRoughnessTexture(), m.getOcclusionTexture()]) if (t && !role.has(t)) role.set(t, 'data');
      }
      texs.forEach((t, i) => {
        const r = role.get(t) || 'color';
        roles.set(String(i), r);
        if (t.getName()) roles.set(t.getName().toLowerCase(), r);
      });
    } catch (e) { console.warn(`  ${id}: ${e.message}`); }
  }
  for (const f of imps) {
    const base = f.replace(/\.import$/i, '').replace(/\.(jpg|jpeg|png|webp)$/i, '');
    let role = null;
    const m = base.match(new RegExp(`^${id}_(\\d+)$`));
    if (m && roles.has(m[1])) role = roles.get(m[1]);
    const nameKey = base.startsWith(id + '_') ? base.slice(id.length + 1).toLowerCase() : base.toLowerCase();
    if (!role && roles.has(nameKey)) role = roles.get(nameKey);
    if (!role) role = /(^|_)(nor|normal|nrm)(_|$)|nor_gl|normal/i.test(base) ? 'normal' : 'color';
    patch(path.join(dir, f), role);
  }
}

// texture sets
const TEX = path.join(PROJECT_DIR, 'assets', 'textures');
for (const id of fs.readdirSync(TEX)) {
  const dir = path.join(TEX, id);
  if (!fs.statSync(dir).isDirectory()) continue;
  for (const f of fs.readdirSync(dir).filter((x) => /\.(jpg|png)\.import$/i.test(x))) {
    patch(path.join(dir, f), /^normal\./i.test(f) ? 'normal' : 'color');
  }
}
console.log('import files updated:', changed);
