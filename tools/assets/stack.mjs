// Usage: node stack.mjs out.png in1.png in2.png ...  (vertical stack of contact sheets)
import sharp from 'sharp';
const [out, ...ins] = process.argv.slice(2);
const metas = await Promise.all(ins.map((f) => sharp(f).metadata()));
const width = Math.max(...metas.map((m) => m.width));
let top = 0; const comps = [];
ins.forEach((f, i) => { comps.push({ input: f, left: 0, top }); top += metas[i].height; });
await sharp({ create: { width, height: top, channels: 3, background: '#000' } }).composite(comps).png().toFile(out);
console.log(out, width, top);
