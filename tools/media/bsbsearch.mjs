// BigSoundBank (CC0, Joseph Sardin) search: node bsbsearch.mjs "query" [maxResults]
import { fetchRetry } from './lib.mjs';

export async function bsbSearch(q) {
  const res = await fetchRetry(`https://bigsoundbank.com/search?q=${encodeURIComponent(q)}`, { headers: { 'User-Agent': 'Mozilla/5.0 BunkerGame-AssetPipeline/1.0' } });
  const html = await res.text();
  const out = [];
  const re = /<h2[^>]*><a href='(\/[^']+-s(\d{4})\.html)'>([^<]+)<\/a>[\s\S]*?<\/div><\/div><div>([\s\S]*?)<\/div>/g;
  let m;
  while ((m = re.exec(html))) {
    const desc = m[4].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
    const len = /Length: (\d+):(\d+)/.exec(desc);
    out.push({ id: m[2], title: m[3].replace(/&quot;/g, '"').replace(/&amp;/g, '&'), page: 'https://bigsoundbank.com' + m[1], duration: len ? (+len[1]) * 60 + (+len[2]) : null, desc: desc.slice(0, 160) });
  }
  return out;
}

if (process.argv[1]?.endsWith('bsbsearch.mjs')) {
  const [q, n] = process.argv.slice(2);
  for (const r of (await bsbSearch(q)).slice(0, +(n || 20))) console.log(`${r.id} | ${r.duration}s | ${r.title} | ${r.desc}`);
}
