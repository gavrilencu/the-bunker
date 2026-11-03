// Usage: node montage.mjs <out.jpg> <cols> <w> <img...>   -> grid of images (dev helper for screenshot review)
import sharp from 'sharp';
const [out, colsS, wS, ...files] = process.argv.slice(2);
const cols = +colsS, w = +wS;
const metas = await Promise.all(files.map((f) => sharp(f).metadata()));
const h = Math.round(w * metas[0].height / metas[0].width);
const rows = Math.ceil(files.length / cols);
const tiles = await Promise.all(files.map((f) => sharp(f).resize(w, h).toBuffer()));
await sharp({ create: { width: cols * w, height: rows * h, channels: 3, background: '#000' } })
  .composite(tiles.map((input, i) => ({ input, left: (i % cols) * w, top: Math.floor(i / cols) * h })))
  .jpeg({ quality: 82 }).toFile(out);
console.log(out, files.length);
