// Contact-sheet builder shared by search.mjs and adhoc.mjs
import fs from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { CACHE_DIR, fetchRetry } from './lib.mjs';
const sheetDir = path.join(CACHE_DIR, 'sheets');
const thumbDir = path.join(CACHE_DIR, 'thumbs');
for (const d of [sheetDir, thumbDir]) fs.mkdirSync(d, { recursive: true });
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]));
const W = 240, H = 135, LH = 34, RH = 22;

async function thumbBuf(c) {
  const key = (c.uid || 'ph_' + c.id) + '.jpg';
  const p = path.join(thumbDir, key);
  if (!fs.existsSync(p)) {
    try {
      const r = await fetchRetry(c.thumb);
      const b = Buffer.from(await r.arrayBuffer());
      await sharp(b).resize(W, H, { fit: 'contain', background: '#222' }).flatten({ background: '#222' }).jpeg({ quality: 85 }).toFile(p);
    } catch { return sharp({ create: { width: W, height: H, channels: 3, background: '#400' } }).jpeg().toBuffer(); }
  }
  return fs.readFileSync(p);
}

export async function buildSheet(rows, n, { per = 8, sheetTag = 'x' } = {}) {
  const width = W * per;
  const height = rows.length * (RH + H + LH);
  const comps = [];
  const index = {};
  for (let r = 0; r < rows.length; r++) {
    const { entry, cands } = rows[r];
    const y0 = r * (RH + H + LH);
    const hdr = `<svg width="${width}" height="${RH}"><rect width="100%" height="100%" fill="#0b3d6b"/><text x="6" y="16" font-family="Arial" font-size="15" fill="#fff" font-weight="bold">${r}: ${esc(entry.id)}  (fit ${entry.fit[0]} ${entry.fit[1]}m, ≤${entry.faces} faces) ${esc(entry.note || '')}</text></svg>`;
    comps.push({ input: Buffer.from(hdr), left: 0, top: y0 });
    for (let i = 0; i < Math.min(per, cands.length); i++) {
      const c = cands[i];
      const code = `${r}${String.fromCharCode(97 + i)}`;
      index[code] = { entryId: entry.id, ...c };
      comps.push({ input: await thumbBuf(c), left: i * W, top: y0 + RH });
      const l1 = `${code} ${c.name}`.slice(0, 34);
      const l2 = c.source === 'polyhaven'
        ? `PH CC0 ${Math.round((c.faces || 0) / 1000)}k tex${c.tex}`
        : `${Math.round(c.faces / 1000)}k ${c.mb}MB ${c.license === 'CC0 Public Domain' ? 'cc0' : c.license === 'CC Attribution' ? 'by' : 'sa'} L${c.likes}${c.staff ? ' ★' : ''}${c.anims ? ' A' + c.anims : ''} t${c.tex}`;
      const svg = `<svg width="${W}" height="${LH}"><rect width="100%" height="100%" fill="${c.source === 'polyhaven' ? '#1d4d1d' : '#1a1a1a'}"/><text x="3" y="14" font-family="Arial" font-size="13" fill="#ffd54a">${esc(l1)}</text><text x="3" y="29" font-family="Arial" font-size="12" fill="#ddd">${esc(l2)}</text></svg>`;
      comps.push({ input: Buffer.from(svg), left: i * W, top: y0 + RH + H });
    }
  }
  const file = path.join(sheetDir, `sheet_${sheetTag}_${n}.png`);
  await sharp({ create: { width, height, channels: 3, background: '#000' } }).composite(comps).png().toFile(file);
  fs.writeFileSync(file.replace(/\.png$/, '.json'), JSON.stringify(index, null, 1));
  return file;
}

