// Wikimedia Commons audio search: node wmsearch.mjs "query" [limit]
// Prints title | duration | license | artist | url, filtering to free licenses.
import { getJSON } from './lib.mjs';

export const FREE = /^(public domain|pd|cc0|cc[ -]by(-sa)?( \d\.\d)?|cc[ -]by(-sa)?[ -]?\d\.\d|attribution|gfdl)/i;

export async function wmSearch(q, limit = 25) {
  const u = new URL('https://commons.wikimedia.org/w/api.php');
  Object.entries({
    action: 'query', format: 'json', generator: 'search', gsrnamespace: '6',
    gsrsearch: `${q} filetype:audio`, gsrlimit: String(limit), prop: 'imageinfo',
    iiprop: 'url|size|mime|extmetadata|metadata', iiextmetadatafilter: 'LicenseShortName|Artist|UsageTerms|ImageDescription|Credit',
  }).forEach(([k, v]) => u.searchParams.set(k, v));
  const j = await getJSON(u.toString());
  const pages = Object.values(j.query?.pages || {});
  return pages.map(p => {
    const ii = p.imageinfo?.[0] || {};
    const em = ii.extmetadata || {};
    const md = ii.metadata || [];
    const len = md.find(m => m.name === 'length' || m.name === 'playtime_seconds')?.value;
    const strip = s => (s || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
    return {
      title: p.title, url: ii.url, size: ii.size, mime: ii.mime, duration: len ? +(+len).toFixed(1) : null,
      license: strip(em.LicenseShortName?.value), artist: strip(em.Artist?.value).slice(0, 80),
      desc: strip(em.ImageDescription?.value).slice(0, 120), page: ii.descriptionurl,
    };
  }).filter(r => FREE.test(r.license));
}

if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, '/')}` || process.argv[1].endsWith('wmsearch.mjs')) {
  const [q, limit] = process.argv.slice(2);
  if (q) {
    const rs = await wmSearch(q, +(limit || 25));
    for (const r of rs) console.log(`${r.title} | ${r.duration}s | ${r.license} | ${r.artist} | ${(r.size / 1e6).toFixed(1)}MB | ${r.desc}`);
  }
}
