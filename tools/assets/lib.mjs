// Shared helpers for the Bunker model pipeline.
// Sources: Sketchfab Data API v3 (token from ../../.env) and Poly Haven (CC0).
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { pipeline as streamPipeline } from 'node:stream/promises';
import sharp from 'sharp';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, prune, weld, unpartition, metalRough, simplify, resample } from '@gltf-transform/functions';
import draco3d from 'draco3dgltf';
import { MeshoptDecoder, MeshoptSimplifier } from 'meshoptimizer';

export const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
export const PROJECT_DIR = path.resolve(TOOL_DIR, '..', '..');
export const CACHE_DIR = path.join(TOOL_DIR, '.cache');
export const RAW_DIR = path.join(CACHE_DIR, 'raw');
export const OUT_DIR = path.join(PROJECT_DIR, 'assets', 'models');
export const MANIFEST_PATH = path.join(OUT_DIR, 'manifest.json');
export const CREDITS_PATH = path.join(OUT_DIR, 'CREDITS.md');
export const PICKS_PATH = path.join(TOOL_DIR, 'picks.json');
export const UA = 'BunkerGame-AssetPipeline/1.0';

export const catalog = JSON.parse(fs.readFileSync(path.join(TOOL_DIR, 'catalog.json'), 'utf8'));
export const entryById = Object.fromEntries(catalog.models.map((m) => [m.id, m]));

export function loadEnv() {
  const envPath = path.join(PROJECT_DIR, '.env');
  const env = {};
  if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m) env[m[1]] = m[2];
    }
  }
  return { ...env, ...process.env };
}
const ENV = loadEnv();
export const SKETCHFAB_TOKEN = ENV.SKETCHFAB_API_TOKEN;

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function fetchRetry(url, opts = {}, tries = 4) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url, { ...opts, headers: { 'User-Agent': UA, ...(opts.headers || {}) } });
      if (res.status === 429) { lastErr = new Error(`HTTP 429 rate limited: ${url.split('?')[0]}`); await sleep(8000 * (i + 1)); continue; }
      if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText} for ${url.split('?')[0]}`);
      return res;
    } catch (e) {
      lastErr = e;
      await sleep(1500 * (i + 1));
    }
  }
  throw lastErr || new Error(`fetch failed: ${url}`);
}
export async function fetchJson(url, opts) { return (await fetchRetry(url, opts)).json(); }

export async function downloadTo(url, dest, opts = {}) {
  await fsp.mkdir(path.dirname(dest), { recursive: true });
  const res = await fetchRetry(url, opts);
  const tmp = dest + '.part';
  await streamPipeline(Readable.fromWeb(res.body), fs.createWriteStream(tmp));
  await fsp.rename(tmp, dest);
  return dest;
}

// ---------------------------------------------------------------- Sketchfab
const LICENSE_LABEL_OK = new Set(['CC Attribution', 'CC0 Public Domain', 'CC Attribution-ShareAlike']);
export const licenseOk = (label) => LICENSE_LABEL_OK.has(label);

export async function sketchfabSearch(q, { license, sort, count = 24, maxFaces, rigged } = {}) {
  const p = new URLSearchParams({ type: 'models', downloadable: 'true', q, count: String(count) });
  if (license) p.set('license', license);
  if (sort) p.set('sort_by', sort);
  if (maxFaces) p.set('max_face_count', String(maxFaces));
  if (rigged) { p.set('animated', 'true'); p.set('rigged', 'true'); }
  const j = await fetchJson(`https://api.sketchfab.com/v3/search?${p}`);
  return j.results || [];
}

export function pickThumb(m, want = 480) {
  const imgs = (m.thumbnails?.images || []).slice().sort((a, b) => a.width - b.width);
  return (imgs.find((i) => i.width >= want) || imgs[imgs.length - 1])?.url;
}

export function scoreSketchfab(m, entry) {
  const glb = m.archives?.glb;
  if (!glb || !licenseOk(m.license?.label)) return -Infinity;
  const faces = glb.faceCount ?? m.faceCount ?? 0;
  if (faces > entry.faces) return -Infinity;
  if (entry.rigged && !(m.animationCount > 0)) return -Infinity;
  let s = 2 * Math.log10(1 + (m.likeCount || 0)) + 0.6 * Math.log10(1 + (m.viewCount || 0));
  if (m.staffpickedAt) s += 1;
  const name = (m.name || '').toLowerCase();
  const words = new Set(entry.q.flatMap((q) => q.toLowerCase().split(/\s+/)).filter((w) => w.length > 3));
  if ([...words].some((w) => name.includes(w))) s += 1;
  const mb = (glb.size || 0) / 1e6;
  if (mb > 80) s -= 1.5;
  if (mb > 150) s -= 3;
  if ((glb.textureMaxResolution || 0) < 512) s -= 1;
  if (faces < 300) s -= 1.5;
  if (/low.?poly|lowpoly|cartoon|stylized|stylised|toon|voxel|minecraft|roblox/i.test(name)) s -= 2;
  return s;
}

export async function sketchfabModelInfo(uid) {
  return fetchJson(`https://api.sketchfab.com/v3/models/${uid}`);
}

export async function sketchfabDownloadGlb(uid) {
  if (!SKETCHFAB_TOKEN) throw new Error('SKETCHFAB_API_TOKEN missing in .env');
  const dir = path.join(RAW_DIR, uid);
  const dest = path.join(dir, 'model.glb');
  if (fs.existsSync(dest)) return dest;
  await fsp.mkdir(dir, { recursive: true });
  const j = await fetchJson(`https://api.sketchfab.com/v3/models/${uid}/download`, {
    headers: { Authorization: `Token ${SKETCHFAB_TOKEN}` },
  });
  if (!j.glb?.url) throw new Error(`No glb archive for ${uid}`);
  await downloadTo(j.glb.url, dest);
  return dest;
}

// ---------------------------------------------------------------- Poly Haven
let _phList;
export async function polyhavenModels() {
  if (_phList) return _phList;
  const p = path.join(CACHE_DIR, 'polyhaven_models.json');
  if (!fs.existsSync(p)) {
    await fsp.mkdir(CACHE_DIR, { recursive: true });
    await downloadTo('https://api.polyhaven.com/assets?t=models', p);
  }
  _phList = JSON.parse(fs.readFileSync(p, 'utf8'));
  return _phList;
}
export const phThumb = (id) => `https://cdn.polyhaven.com/asset_img/thumbs/${id}.png?width=480&height=270`;

export async function polyhavenDownloadGltf(id, res = '2k') {
  const dir = path.join(RAW_DIR, `ph_${id}_${res}`);
  const files = await fetchJson(`https://api.polyhaven.com/files/${id}`);
  const g = files.gltf?.[res]?.gltf || files.gltf?.['1k']?.gltf;
  if (!g) throw new Error(`No gltf for polyhaven ${id}`);
  const main = path.join(dir, path.basename(new URL(g.url).pathname));
  if (!fs.existsSync(main)) {
    for (const [rel, f] of Object.entries(g.include || {})) {
      const safe = path.normalize(rel).replace(/^(\.\.[/\\])+/, '');
      await downloadTo(f.url, path.join(dir, safe));
    }
    await downloadTo(g.url, main);
  }
  return main;
}

// ---------------------------------------------------------------- glTF processing
let _io;
export async function getIO() {
  if (_io) return _io;
  await MeshoptDecoder.ready;
  _io = new NodeIO()
    .registerExtensions(ALL_EXTENSIONS)
    .registerDependencies({
      'draco3d.decoder': await draco3d.createDecoderModule(),
      'meshopt.decoder': MeshoptDecoder,
    });
  return _io;
}

/** Quaternion [x,y,z,w] for rotations applied X, then Y, then Z (degrees). */
export function eulerQuat(rx = 0, ry = 0, rz = 0) {
  const q = (ax, deg) => { const h = (deg * Math.PI) / 360, s = Math.sin(h); return [ax === 0 ? s : 0, ax === 1 ? s : 0, ax === 2 ? s : 0, Math.cos(h)]; };
  const m = (a, b) => [a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1], a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0], a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3], a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]];
  return m(q(2, rz), m(q(1, ry), q(0, rx)));
}

// column-major 4x4 helpers
function mul(a, b) {
  const o = new Array(16);
  for (let c = 0; c < 4; c++)
    for (let r = 0; r < 4; r++) {
      let s = 0;
      for (let k = 0; k < 4; k++) s += a[k * 4 + r] * b[c * 4 + k];
      o[c * 4 + r] = s;
    }
  return o;
}
function xform(m, x, y, z) {
  return [m[0] * x + m[4] * y + m[8] * z + m[12], m[1] * x + m[5] * y + m[9] * z + m[13], m[2] * x + m[6] * y + m[10] * z + m[14]];
}

/** World-space bounds of a scene (rest pose for skinned meshes, glTF semantics). */
export function computeBounds(scene) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  const add = (p) => { for (let i = 0; i < 3; i++) { if (p[i] < min[i]) min[i] = p[i]; if (p[i] > max[i]) max[i] = p[i]; } };
  scene.traverse((node) => {
    const mesh = node.getMesh();
    if (!mesh) return;
    const skin = node.getSkin();
    let jointMats = null;
    if (skin) {
      const ibm = skin.getInverseBindMatrices();
      jointMats = skin.listJoints().map((j, i) => {
        const b = ibm ? Array.from(ibm.getElement(i, new Array(16))) : [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
        return mul(j.getWorldMatrix(), b);
      });
    }
    const world = node.getWorldMatrix();
    for (const prim of mesh.listPrimitives()) {
      const pos = prim.getAttribute('POSITION');
      if (!pos) continue;
      const n = pos.getCount();
      const v = [0, 0, 0];
      const J = skin ? prim.getAttribute('JOINTS_0') : null;
      const W = skin ? prim.getAttribute('WEIGHTS_0') : null;
      const jv = [0, 0, 0, 0], wv = [0, 0, 0, 0];
      for (let i = 0; i < n; i++) {
        pos.getElement(i, v);
        if (J && W) {
          J.getElement(i, jv); W.getElement(i, wv);
          const acc = [0, 0, 0];
          let wsum = 0;
          for (let k = 0; k < 4; k++) {
            if (!wv[k]) continue;
            const p = xform(jointMats[jv[k]], v[0], v[1], v[2]);
            acc[0] += p[0] * wv[k]; acc[1] += p[1] * wv[k]; acc[2] += p[2] * wv[k];
            wsum += wv[k];
          }
          add(wsum > 0 ? [acc[0] / wsum, acc[1] / wsum, acc[2] / wsum] : xform(world, v[0], v[1], v[2]));
        } else {
          add(xform(world, v[0], v[1], v[2]));
        }
      }
    }
  });
  return { min, max, size: [max[0] - min[0], max[1] - min[1], max[2] - min[2]] };
}

export function countFaces(doc) {
  let f = 0;
  const scene = doc.getRoot().getDefaultScene() || doc.getRoot().listScenes()[0];
  scene.traverse((node) => {
    const mesh = node.getMesh();
    if (!mesh) return;
    for (const p of mesh.listPrimitives()) {
      if (p.getMode() !== 4) continue;
      const idx = p.getIndices();
      f += (idx ? idx.getCount() : p.getAttribute('POSITION')?.getCount() || 0) / 3;
    }
  });
  return Math.round(f);
}

async function shrinkTextures(doc, maxRes) {
  let maxOut = 0;
  for (const tex of doc.getRoot().listTextures()) {
    const img = tex.getImage();
    const mime = tex.getMimeType();
    if (!img || !['image/png', 'image/jpeg', 'image/webp'].includes(mime)) continue;
    const buf = Buffer.from(img);
    let meta;
    try { meta = await sharp(buf).metadata(); } catch { continue; }
    const needResize = Math.max(meta.width, meta.height) > maxRes;
    let pipe = sharp(buf);
    if (needResize) pipe = pipe.resize(maxRes, maxRes, { fit: 'inside', withoutEnlargement: true });
    const resized = await pipe.toBuffer();
    let toJpeg = mime === 'image/jpeg';
    if (!toJpeg) {
      const st = await sharp(resized).stats();
      toJpeg = st.isOpaque;
    }
    const m2 = await sharp(resized).metadata();
    maxOut = Math.max(maxOut, m2.width, m2.height);
    if (mime === 'image/jpeg' && !needResize) continue;
    const out = toJpeg
      ? await sharp(resized).jpeg({ quality: 88, mozjpeg: true }).toBuffer()
      : await sharp(resized).png({ compressionLevel: 9 }).toBuffer();
    const outMime = toJpeg ? 'image/jpeg' : 'image/png';
    tex.setImage(new Uint8Array(out)).setMimeType(outMime);
    const uri = tex.getURI();
    if (uri) tex.setURI(uri.replace(/\.(png|jpe?g|webp)$/i, '') + (toJpeg ? '.jpg' : '.png'));
  }
  // also account for untouched jpgs
  for (const tex of doc.getRoot().listTextures()) {
    const s = tex.getSize();
    if (s) maxOut = Math.max(maxOut, s[0], s[1]);
  }
  return maxOut;
}

/** Sketchfab exports often flag fully opaque materials as BLEND/MASK, which Godot then depth-sorts as transparent. */
async function fixFakeAlpha(doc) {
  for (const mat of doc.getRoot().listMaterials()) {
    if (mat.getAlphaMode() === 'OPAQUE') continue;
    if (/glass|window|wind_|transp|leaf|leaves|foliage|grass|hair|decal|light/i.test(mat.getName())) continue;
    if (mat.listExtensions().some((e) => e.extensionName === 'KHR_materials_transmission')) continue;
    if (mat.getBaseColorFactor()[3] < 0.999) continue;
    const t = mat.getBaseColorTexture();
    if (!t || t.getMimeType() === 'image/jpeg') { mat.setAlphaMode('OPAQUE'); continue; }
    let data, info;
    try { ({ data, info } = await sharp(Buffer.from(t.getImage())).ensureAlpha().raw().toBuffer({ resolveWithObject: true })); } catch { continue; }
    let lo = 0, zero = 0;
    for (let i = 3; i < data.length; i += 4) { if (data[i] < 250) { lo++; if (data[i] < 10) zero++; } }
    const frac = lo / (info.width * info.height);
    if (frac < 0.01) mat.setAlphaMode('OPAQUE'); // junk alpha (UV padding etc.)
    else if (zero / lo > 0.9) { mat.setAlphaMode('MASK'); mat.setAlphaCutoff(0.5); } // binary cut-out (grilles, padding)
    // otherwise: genuinely semi-transparent, keep BLEND
  }
}

/**
 * Optimize + normalize a glTF/GLB into assets/models/<id>/<id>.glb.
 * Returns stats for the manifest.
 */
export async function processModel(inPath, entry, { simplifyRatio, keep, yaw, rot } = {}) {
  const io = await getIO();
  const doc = await io.read(inPath);
  const root = doc.getRoot();

  // Optionally keep only mesh nodes whose own name or an ancestor's name matches `keep` (regex).
  if (keep) {
    const re = new RegExp(keep, 'i');
    const matches = (n) => { for (let p = n; p && p.propertyType === 'Node'; p = p.getParentNode()) if (re.test(p.getName())) return true; return false; };
    let kept = 0;
    for (const node of root.listNodes()) {
      if (!node.getMesh()) continue;
      if (matches(node)) kept++; else node.setMesh(null);
    }
    if (!kept) throw new Error(`--keep ${keep} matched no mesh nodes`);
  }

  // Strip things the game doesn't want / Godot can't read.
  for (const ext of root.listExtensionsUsed()) {
    const n = ext.extensionName;
    if (['KHR_lights_punctual', 'KHR_draco_mesh_compression', 'EXT_meshopt_compression', 'KHR_materials_variants'].includes(n)) ext.dispose();
  }
  // raw entries (first-person rigs) keep their authored transforms; remember where the
  // authoring cameras were so the game can line the rig up with its own camera.
  const cameras = [];
  for (const node of root.listNodes()) if (node.getCamera()) {
    const c = node.getCamera();
    cameras.push({ name: node.getName(), matrix: Array.from(node.getWorldMatrix()).map((v) => +v.toFixed(5)), yfov: c.getYFov ? c.getYFov() : null });
  }
  for (const node of root.listNodes()) if (node.getCamera()) node.setCamera(null);
  for (const cam of root.listCameras()) cam.dispose();
  if (root.listExtensionsUsed().some((e) => e.extensionName === 'KHR_materials_pbrSpecularGlossiness')) {
    await doc.transform(metalRough());
  }

  // Keep only the default scene.
  const scene = root.getDefaultScene() || root.listScenes()[0];
  root.setDefaultScene(scene);
  for (const s of root.listScenes()) if (s !== scene) s.dispose();

  const skinned = root.listSkins().length > 0;
  const transforms = [dedup(), prune({ keepAttributes: false })];
  if (!skinned) transforms.push(weld());
  if (root.listAnimations().length) transforms.push(resample({ tolerance: 1e-4 }));
  await doc.transform(...transforms);

  if (!simplifyRatio && !skinned) {
    const f0 = countFaces(doc);
    if (f0 > entry.faces * 1.15) simplifyRatio = entry.faces / f0;
  }
  if (simplifyRatio && !skinned) {
    await MeshoptSimplifier.ready;
    await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio: simplifyRatio, error: 0.01 }));
  }

  const tex = await shrinkTextures(doc, entry.tex);
  await fixFakeAlpha(doc);

  // Optional yaw fix (degrees about +Y) so the model's main faces line up with the X/Z axes.
  if (yaw || rot) {
    const [rx, ry, rz] = rot || [0, yaw, 0];
    const yawNode = doc.createNode('orient_fix').setRotation(eulerQuat(rx, ry, rz));
    for (const child of scene.listChildren()) { scene.removeChild(child); yawNode.addChild(child); }
    scene.addChild(yawNode);
  }

  if (entry.raw) {
    await doc.transform(prune(), unpartition());
    const outDir = path.join(OUT_DIR, entry.id);
    await fsp.mkdir(outDir, { recursive: true });
    const outPath = path.join(outDir, `${entry.id}.glb`);
    await io.write(outPath, doc);
    const doc2 = await io.read(outPath);
    const b2 = computeBounds(doc2.getRoot().getDefaultScene() || doc2.getRoot().listScenes()[0]);
    return {
      faces: countFaces(doc2), size_m: b2.size.map((v) => +v.toFixed(3)), tex,
      animations: doc2.getRoot().listAnimations().map((a) => a.getName()), skinned,
      alpha: doc2.getRoot().listMaterials().filter((m) => m.getAlphaMode() !== 'OPAQUE').map((m) => `${m.getName()}:${m.getAlphaMode()}`),
      bytes: fs.statSync(outPath).size, outPath, cameras,
      anim_ranges: doc2.getRoot().listAnimations().map((a) => { let t0 = Infinity, t1 = -Infinity; for (const sm of a.listSamplers()) { const arr = sm.getInput()?.getArray(); if (arr && arr.length) { t0 = Math.min(t0, arr[0]); t1 = Math.max(t1, arr[arr.length - 1]); } } return [a.getName(), +t0.toFixed(3), +t1.toFixed(3)]; }),
    };
  }

  // Normalize scale + pivot.
  const b = computeBounds(scene);
  const [mode, target] = entry.fit;
  const dim = mode === 'h' ? b.size[1] : mode === 'l' ? Math.max(b.size[0], b.size[2]) : Math.max(...b.size);
  if (!(dim > 0)) throw new Error('Degenerate bounds');
  const s = target / dim;
  const cx = (b.min[0] + b.max[0]) / 2, cz = (b.min[2] + b.max[2]) / 2;
  const wrapper = doc.createNode(entry.id).setScale([s, s, s]).setTranslation([-s * cx, -s * b.min[1], -s * cz]);
  for (const child of scene.listChildren()) { scene.removeChild(child); wrapper.addChild(child); }
  scene.addChild(wrapper);

  await doc.transform(prune(), unpartition());

  const outDir = path.join(OUT_DIR, entry.id);
  await fsp.mkdir(outDir, { recursive: true });
  const outPath = path.join(outDir, `${entry.id}.glb`);
  await io.write(outPath, doc);

  // Validate by re-reading.
  const doc2 = await io.read(outPath);
  const sc2 = doc2.getRoot().getDefaultScene() || doc2.getRoot().listScenes()[0];
  const b2 = computeBounds(sc2);
  const dim2 = mode === 'h' ? b2.size[1] : mode === 'l' ? Math.max(b2.size[0], b2.size[2]) : Math.max(...b2.size);
  const ok = Math.abs(dim2 - target) / target < 0.01 && Math.abs(b2.min[1]) < 0.01 * target + 1e-4;
  if (!ok) throw new Error(`Validation failed: dim=${dim2} target=${target} minY=${b2.min[1]}`);

  const mats = doc2.getRoot().listMaterials();
  return {
    faces: countFaces(doc2),
    size_m: b2.size.map((v) => +v.toFixed(3)),
    tex,
    animations: doc2.getRoot().listAnimations().map((a) => a.getName()),
    skinned,
    alpha: mats.filter((m) => m.getAlphaMode() !== 'OPAQUE').map((m) => `${m.getName()}:${m.getAlphaMode()}`),
    bytes: fs.statSync(outPath).size,
    outPath,
  };
}

// ---------------------------------------------------------------- manifest / credits
export function readManifest() {
  return fs.existsSync(MANIFEST_PATH) ? JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8')) : {};
}
export function writeManifest(man) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const sorted = Object.fromEntries(Object.keys(man).sort().map((k) => [k, man[k]]));
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(sorted, null, 2) + '\n');
  const lines = [
    '# 3D model credits',
    '',
    'Models used in BUNKER. Sketchfab models are used under their Creative Commons licenses (attribution below); Poly Haven models are CC0.',
    'Models were optimized (texture resize, mesh dedup/weld) and rescaled/re-pivoted for the game.',
    '',
    '| Asset id | Title | Author | License | Source |',
    '|---|---|---|---|---|',
  ];
  for (const [id, m] of Object.entries(sorted)) {
    const author = m.author_url ? `[${m.author}](${m.author_url})` : m.author;
    lines.push(`| ${id} | ${m.title.replace(/\|/g, '/')} | ${author} | ${m.license} | [link](${m.source_url}) |`);
  }
  fs.writeFileSync(CREDITS_PATH, lines.join('\n') + '\n');
}
export function readPicks() {
  return fs.existsSync(PICKS_PATH) ? JSON.parse(fs.readFileSync(PICKS_PATH, 'utf8')) : {};
}
export function writePicks(p) {
  fs.writeFileSync(PICKS_PATH, JSON.stringify(p, null, 2) + '\n');
}
