// Downloads sky HDRIs from Poly Haven. Output: assets/hdri/<id>.hdr + manifest.json
import fs from 'node:fs';
import path from 'node:path';
import { ASSETS, ensureDir, download, getJSON, readJSON, writeJSON } from './lib.mjs';

// "Pure sky" HDRIs: no ground clutter, the game supplies its own terrain.
const PICKS = {
  sky_morning:  { asset: 'kloofendal_48d_partly_cloudy_puresky', res: '4k' },
  sky_overcast: { asset: 'overcast_soil_puresky', res: '4k' },
  sky_sunset:   { asset: 'belfast_sunset_puresky', res: '2k' },
};

const OUT = ensureDir(path.join(ASSETS, 'hdri'));
const manifestPath = path.join(OUT, 'manifest.json');
const manifest = readJSON(manifestPath);

for (const [id, p] of Object.entries(PICKS)) {
  try {
    console.log(`hdri ${id} <- ${p.asset} ${p.res}`);
    const info = await getJSON(`https://api.polyhaven.com/info/${p.asset}`);
    const files = await getJSON(`https://api.polyhaven.com/files/${p.asset}`);
    const url = files.hdri?.[p.res]?.hdr?.url;
    if (!url) throw new Error('no hdr url');
    const f = await download(url, `ph_hdri_${p.asset}`);
    fs.copyFileSync(f, path.join(OUT, `${id}.hdr`));
    manifest[id] = {
      file: `res://assets/hdri/${id}.hdr`,
      title: info.name,
      author: Object.keys(info.authors || {}).join(', '),
      source_url: `https://polyhaven.com/a/${p.asset}`,
      license: 'CC0 1.0',
      notes: `Poly Haven HDRI '${p.asset}', ${p.res.toUpperCase()} .hdr (pure sky, below-horizon is synthetic).`,
    };
  } catch (e) { console.error(`  FAILED ${id}: ${e.message}`); }
}
writeJSON(manifestPath, manifest);
console.log('done');
