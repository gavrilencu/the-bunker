// Usage: node fpsfix.mjs <id...>
//   Post-process for first-person rigs:
//   - optional recolor of reddish "plum" polymer to black polymer (picks.json: "recolor": [imageIndex...])
//   - writes Godot .import settings for the extracted textures: VRAM (BC7 / BC5 normal), mipmaps
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { getIO, OUT_DIR, readPicks } from './lib.mjs';

const picks = readPicks();
const io = await getIO();
for (const id of process.argv.slice(2)) {
  const file = path.join(OUT_DIR, id, `${id}.glb`);
  const doc = await io.read(file);
  const root = doc.getRoot();
  const images = root.listTextures();
  const roles = new Map();
  for (const m of root.listMaterials()) {
    const set = (t, r) => { if (t) roles.set(t, r); };
    set(m.getBaseColorTexture(), 'albedo');
    set(m.getMetallicRoughnessTexture(), 'orm');
    set(m.getNormalTexture(), 'normal');
    set(m.getOcclusionTexture(), 'ao');
    set(m.getEmissiveTexture(), 'emission');
  }
  let changed = false;
  for (const idx of picks[id]?.recolor || []) {
    const tex = images[idx];
    const { data, info } = await sharp(Buffer.from(tex.getImage())).raw().toBuffer({ resolveWithObject: true });
    let n = 0;
    for (let i = 0; i < data.length; i += info.channels) {
      const r = data[i], g = data[i + 1], b = data[i + 2];
      if (r > 30 && r > g * 1.22 && r > b * 1.18) {
        const l = Math.round((r * 0.3 + g * 0.59 + b * 0.11) * 0.75);
        data[i] = l; data[i + 1] = l; data[i + 2] = Math.min(255, l + 2); n++;
      }
    }
    const out = await sharp(data, { raw: info }).jpeg({ quality: 90 }).toBuffer();
    tex.setImage(new Uint8Array(out)).setMimeType('image/jpeg');
    changed = true;
    console.log(`${id}: recolored image ${idx} (${n} px)`);
  }
  if (changed) await io.write(file, doc);
  // import settings for the textures Godot extracts as <id>_<index>.<ext>
  images.forEach((t, i) => {
    const ext = t.getMimeType() === 'image/png' ? 'png' : 'jpg';
    const imp = path.join(OUT_DIR, id, `${id}_${i}.${ext}.import`);
    if (!fs.existsSync(imp)) return;
    let s = fs.readFileSync(imp, 'utf8');
    const role = roles.get(t) || 'albedo';
    const setv = (k, v) => { const re = new RegExp(`^${k.replace('/', '\\/')}=.*$`, 'm'); s = re.test(s) ? s.replace(re, `${k}=${v}`) : s.replace('[params]', `[params]\n${k}=${v}`); };
    setv('compress/mode', 2);
    setv('compress/high_quality', role === 'normal' ? 'false' : 'true');
    setv('compress/normal_map', role === 'normal' ? 1 : 2);
    setv('mipmaps/generate', 'true');
    setv('detect_3d/compress_to', 0);
    fs.writeFileSync(imp, s);
    console.log(`${id}_${i}.${ext}: ${role}`);
  });
}
