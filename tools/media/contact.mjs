// Contact sheet builder: node contact.mjs out.png "label|imageUrl" "label|imageUrl" ...
// or: node contact.mjs out.png --ph id1 id2 ... (Poly Haven thumbnails)
import sharp from 'sharp';
import { fetchRetry } from './lib.mjs';

const [out, ...rest] = process.argv.slice(2);
let items = [];
if (rest[0] === '--ph') {
  items = rest.slice(1).map(id => ({ label: id, url: `https://cdn.polyhaven.com/asset_img/thumbs/${id}.png?width=256&height=256` }));
} else {
  items = rest.map(s => { const i = s.indexOf('|'); return { label: s.slice(0, i), url: s.slice(i + 1) }; });
}
const W = 256, H = 256, LH = 22, cols = Math.min(6, items.length);
const rows = Math.ceil(items.length / cols);
const comps = [];
await Promise.all(items.map(async (it, i) => {
  try {
    const res = await fetchRetry(it.url);
    const buf = Buffer.from(await res.arrayBuffer());
    const img = await sharp(buf).resize(W, H, { fit: 'cover' }).png().toBuffer();
    const x = (i % cols) * W, y = Math.floor(i / cols) * (H + LH);
    comps.push({ input: img, left: x, top: y });
    const svg = `<svg width="${W}" height="${LH}"><rect width="100%" height="100%" fill="#111"/><text x="4" y="16" font-family="Arial" font-size="13" fill="#fff">${it.label.replace(/&/g, '&amp;').replace(/</g, '&lt;').slice(0, 38)}</text></svg>`;
    comps.push({ input: Buffer.from(svg), left: x, top: y + H });
  } catch (e) { console.error('fail', it.label, e.message); }
}));
await sharp({ create: { width: cols * W, height: rows * (H + LH), channels: 3, background: '#222' } })
  .composite(comps).png().toFile(out);
console.log('wrote', out);
