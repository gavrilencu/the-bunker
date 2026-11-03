// OpenGameArt helpers: node oga.mjs search "keys"   |   node oga.mjs page <slug> [slug...]
import { fetchRetry } from './lib.mjs';

const UA = { headers: { 'User-Agent': 'Mozilla/5.0 BunkerGame-AssetPipeline/1.0' } };

export async function ogaSearch(keys) {
  const html = await (await fetchRetry(`https://opengameart.org/art-search-advanced?keys=${encodeURIComponent(keys)}&field_art_type_tid%5B%5D=13&sort_by=count&sort_order=DESC`, UA)).text();
  const set = new Map();
  for (const m of html.matchAll(/href="\/content\/([^"]+)"[^>]*>([^<]+)/g)) if (!/^(faq|.*art-challenge.*)$/.test(m[1])) set.set(m[1], m[2]);
  return [...set].map(([slug, title]) => ({ slug, title }));
}

export async function ogaPage(slug) {
  const html = await (await fetchRetry(`https://opengameart.org/content/${slug}`, UA)).text();
  const lic = [...html.matchAll(/class="license-name"[^>]*>([^<]+)</g)].map(m => m[1].trim());
  const lic2 = [...html.matchAll(/(CC0|CC-BY(?:-SA)? \d\.\d|GPL \d\.\d|OGA-BY \d\.\d|CC-BY \d\.\d)/g)].map(m => m[1]);
  const files = [...new Set([...html.matchAll(/href="(https:\/\/opengameart\.org\/sites\/default\/files\/[^"]+)"/g)].map(m => m[1]))].filter(u => !/\.(png|jpg|gif)$/i.test(u));
  const author = /<a href="\/users\/[^"]+"[^>]*>([^<]+)<\/a>/.exec(html.split('field-name-author-submitter')[1] || html)?.[1];
  const title = /<h2[^>]*>([^<]+)<\/h2>/.exec(html)?.[1] || /<title>([^|<]+)/.exec(html)?.[1];
  return { slug, title: title?.trim(), author, licenses: [...new Set([...lic, ...lic2])], files, url: `https://opengameart.org/content/${slug}` };
}

if (process.argv[1]?.endsWith('oga.mjs')) {
  const [cmd, ...args] = process.argv.slice(2);
  if (cmd === 'search') for (const r of await ogaSearch(args.join(' '))) console.log(r.slug, '|', r.title);
  if (cmd === 'page') for (const s of args) { const p = await ogaPage(s); console.log(JSON.stringify(p)); }
}
