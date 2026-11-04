// Downloads PBR textures (2K JPG) per tools/media/catalog.json ids.
// Output: assets/textures/<id>/{albedo,normal,roughness,ao,metallic,height}.jpg + manifest.json
// Usage: node textures.mjs [id ...]   (no args = all)
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import sharp from 'sharp';
import { ASSETS, RAW, ensureDir, download, getJSON, readJSON, writeJSON } from './lib.mjs';

// Curated picks (chosen by comparing thumbnails; see README).
const PICKS = {
  concrete_wall:  { src: 'polyhaven', asset: 'concrete_layers_02' },
  concrete_floor: { src: 'polyhaven', asset: 'concrete_floor_02' },
  painted_metal:  { src: 'polyhaven', asset: 'green_metal_rust' },
  rusty_metal:    { src: 'polyhaven', asset: 'rusty_metal_04' },
  metal_plate:    { src: 'polyhaven', asset: 'metal_plate' },
  tiles_wall:     { src: 'polyhaven', asset: 'long_white_tiles' },
  brick_wall:     { src: 'polyhaven', asset: 'red_brick_03' },
  asphalt:        { src: 'polyhaven', asset: 'asphalt_02' },
  grass:          { src: 'ambientcg', asset: 'Grass004' },
  ground_dirt:    { src: 'polyhaven', asset: 'brown_mud_dry' },
  ground_ash:     { src: 'polyhaven', asset: 'burned_ground_01' },
  soil:           { src: 'polyhaven', asset: 'farm_soil' },
  wood_planks:    { src: 'polyhaven', asset: 'old_planks_02' },
  gravel:         { src: 'polyhaven', asset: 'rubble' },
  pavement:       { src: 'polyhaven', asset: 'concrete_pavement' },
  // interiors (v0.6): wallpaper, peeling paint, floors, tiles, ceiling, carpet, upholstery, furniture wood
  // (1K: a dozen extra 2K sets is too much VRAM on the integrated GPUs the game targets)
  wallpaper:      { src: 'polyhaven', asset: 'decrepit_wallpaper' },
  paint_peeling:  { src: 'polyhaven', asset: 'peeling_painted_wall' },
  plaster_int:    { src: 'polyhaven', asset: 'painted_plaster_wall' },
  floor_wood_old: { src: 'polyhaven', asset: 'wood_floor_worn' },
  parquet:        { src: 'polyhaven', asset: 'herringbone_parquet' },
  linoleum:       { src: 'polyhaven', asset: 'old_linoleum_flooring_01' },
  tiles_bath:     { src: 'polyhaven', asset: 'dirty_tiles' },
  tiles_floor:    { src: 'polyhaven', asset: 'interior_tiles' },
  ceiling:        { src: 'polyhaven', asset: 'ceiling_interior' },
  carpet:         { src: 'polyhaven', asset: 'dirty_carpet' },
  upholstery:     { src: 'polyhaven', asset: 'rough_linen' },
  kitchen_wood:   { src: 'polyhaven', asset: 'kitchen_wood' },
  // v0.7 realism pass (2K): real facade plasters, panel blocks, corrugated tin, tiles, painted wood,
  // bunker concrete, worn interior plaster, ground covers
  plaster_white:  { src: 'polyhaven', asset: 'white_plaster_rough_01' },
  plaster_yellow: { src: 'polyhaven', asset: 'yellow_plaster' },
  plaster_worn:   { src: 'polyhaven', asset: 'worn_plaster_wall' },
  plaster_blue:   { src: 'polyhaven', asset: 'blue_plaster_weathered' },
  plaster_cracked:{ src: 'polyhaven', asset: 'worn_cracked_plaster' },
  panel_concrete: { src: 'polyhaven', asset: 'concrete_panels' },
  roof_tin:       { src: 'polyhaven', asset: 'rusty_corrugated_iron' },
  roof_tin_grey:  { src: 'polyhaven', asset: 'corrugated_iron_02' },
  roof_tiles:     { src: 'polyhaven', asset: 'clay_roof_tiles_02' },
  wood_painted:   { src: 'polyhaven', asset: 'wood_peeling_paint_weathered' },
  bunker_wall:    { src: 'polyhaven', asset: 'concrete_wall_008' },
  bunker_floor:   { src: 'polyhaven', asset: 'concrete_floor_worn_001' },
  bunker_ceiling: { src: 'polyhaven', asset: 'rough_concrete' },
  portal_concrete:{ src: 'polyhaven', asset: 'concrete_wall_004' },
  old_floor:      { src: 'polyhaven', asset: 'old_wooden_floor_01' },
  withered_grass: { src: 'polyhaven', asset: 'withered_grass' },
  dry_leaves:     { src: 'polyhaven', asset: 'dry_decay_leaves' },
  lawn:           { src: 'polyhaven', asset: 'leafy_grass' },
};
let OUT_SIZE = 2048;
const METALLIC_IDS = new Set(['painted_metal', 'rusty_metal', 'metal_plate']);

const OUT = ensureDir(path.join(ASSETS, 'textures'));
const manifestPath = path.join(OUT, 'manifest.json');
const manifest = readJSON(manifestPath);

async function copyAsJpg(src, dst) {
  // Re-encode to baseline JPG 2048 (keeps size predictable, strips metadata).
  await sharp(src).resize(OUT_SIZE, OUT_SIZE, { fit: 'fill' }).jpeg({ quality: 90, mozjpeg: true }).toFile(dst);
}

async function channelToJpg(src, channel, dst) {
  const { data, info } = await sharp(src).resize(OUT_SIZE, OUT_SIZE, { fit: 'fill' }).extractChannel(channel).raw().toBuffer({ resolveWithObject: true });
  let sum = 0; for (let i = 0; i < data.length; i += 97) sum += data[i];
  const mean = sum / Math.ceil(data.length / 97) / 255;
  await sharp(data, { raw: { width: info.width, height: info.height, channels: 1 } }).jpeg({ quality: 92 }).toFile(dst);
  return mean;
}

async function polyhaven(id, asset) {
  const info = await getJSON(`https://api.polyhaven.com/info/${asset}`);
  const files = await getJSON(`https://api.polyhaven.com/files/${asset}`);
  const pick = (key) => files[key]?.['2k']?.jpg?.url;
  const dir = ensureDir(path.join(OUT, id));
  const rawName = `ph_tex_${asset}`;
  const maps = { albedo: pick('Diffuse'), normal: pick('nor_gl'), roughness: pick('Rough'), ao: pick('AO'), height: pick('Displacement') };
  for (const [k, url] of Object.entries(maps)) {
    if (!url) { console.warn(`  ${id}: missing ${k}`); continue; }
    const f = await download(url, rawName);
    await copyAsJpg(f, path.join(dir, `${k}.jpg`));
  }
  if (METALLIC_IDS.has(id)) {
    if (pick('Metal')) {
      const f = await download(pick('Metal'), rawName);
      await copyAsJpg(f, path.join(dir, 'metallic.jpg'));
    } else if (pick('arm')) {
      const f = await download(pick('arm'), rawName);
      const mean = await channelToJpg(f, 2, path.join(dir, 'metallic.jpg'));
      if (mean < 0.02) fs.rmSync(path.join(dir, 'metallic.jpg')); // non-metal (painted) surface
    }
  }
  return {
    title: info.name,
    author: Object.keys(info.authors || {}).join(', '),
    source_url: `https://polyhaven.com/a/${asset}`,
    license: 'CC0 1.0',
    notes: `Poly Haven texture '${asset}', 2K. Real-world size ~${(info.dimensions?.[0] / 1000).toFixed(1)}m.`,
    real_size_m: info.dimensions ? +(info.dimensions[0] / 1000).toFixed(2) : null,
  };
}

async function ambientcg(id, asset) {
  const zipUrl = `https://ambientcg.com/get?file=${asset}_2K-JPG.zip`;
  const zip = await download(zipUrl, `acg_${asset}`, `${asset}_2K-JPG.zip`);
  const exdir = ensureDir(path.join(path.dirname(zip), 'x'));
  const r = spawnSync('unzip', ['-o', '-q', zip, '-d', exdir]);
  if (r.status !== 0) throw new Error('unzip failed ' + r.stderr);
  const f = (suffix) => { const n = fs.readdirSync(exdir).find(x => x.endsWith(`_${suffix}.jpg`)); return n && path.join(exdir, n); };
  const dir = ensureDir(path.join(OUT, id));
  const maps = { albedo: f('Color'), normal: f('NormalGL'), roughness: f('Roughness'), ao: f('AmbientOcclusion'), height: f('Displacement'), metallic: f('Metalness') };
  for (const [k, file] of Object.entries(maps)) if (file) await copyAsJpg(file, path.join(dir, `${k}.jpg`));
  return { title: asset, author: 'Lennart Demes (ambientCG)', source_url: `https://ambientcg.com/view?id=${asset}`, license: 'CC0 1.0', notes: `ambientCG material '${asset}', 2K.`, real_size_m: null };
}

const only = process.argv.slice(2);
for (const [id, p] of Object.entries(PICKS)) {
  if (only.length && !only.includes(id)) continue;
  try {
    console.log(`texture ${id} <- ${p.src}:${p.asset}`);
    OUT_SIZE = p.size || 2048;
    const meta = p.src === 'polyhaven' ? await polyhaven(id, p.asset) : await ambientcg(id, p.asset);
    const dir = path.join(OUT, id);
    const maps = fs.readdirSync(dir).filter(x => x.endsWith('.jpg')).map(x => x.replace('.jpg', ''));
    manifest[id] = { file: `res://assets/textures/${id}/`, maps, ...meta };
  } catch (e) {
    console.error(`  FAILED ${id}: ${e.message}`);
  }
}
writeJSON(manifestPath, manifest);
console.log('done');
