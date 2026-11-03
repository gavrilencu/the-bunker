// Shared helpers for the media pipeline.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import ffmpegPath from 'ffmpeg-static';

export const UA = 'BunkerGame-AssetPipeline/1.0';
export const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(TOOL_DIR, '..', '..');
export const CACHE = path.join(TOOL_DIR, '.cache');
export const RAW = path.join(CACHE, 'raw');
export const ASSETS = path.join(ROOT, 'assets');
export const FFMPEG = ffmpegPath;

export function ensureDir(d) { fs.mkdirSync(d, { recursive: true }); return d; }

export async function fetchRetry(url, opts = {}, tries = 4) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url, { ...opts, headers: { 'User-Agent': UA, ...(opts.headers || {}) } });
      if (res.status === 429 || res.status >= 500) throw new Error(`HTTP ${res.status} ${url}`);
      return res;
    } catch (e) {
      lastErr = e;
      await new Promise(r => setTimeout(r, 1500 * (i + 1)));
    }
  }
  throw lastErr;
}

export async function getJSON(url, opts) {
  const res = await fetchRetry(url, opts);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.json();
}

/** Download url into its own raw dir: .cache/raw/<name>/<file>. Skips if exists. */
export async function download(url, name, fileName) {
  const dir = ensureDir(path.join(RAW, name));
  const out = path.join(dir, fileName || decodeURIComponent(path.basename(new URL(url).pathname)));
  if (fs.existsSync(out) && fs.statSync(out).size > 0) return out;
  const res = await fetchRetry(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  const buf = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(out, buf);
  return out;
}

export function ffmpeg(args, { quiet = true } = {}) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-y', ...(quiet ? ['-loglevel', 'error'] : []), ...args], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(`ffmpeg failed: ${args.join(' ')}\n${r.stderr}`);
  return r.stderr;
}

/** Returns duration in seconds via ffmpeg probe output. */
export function duration(file) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-i', file], { encoding: 'utf8' });
  const m = /Duration: (\d+):(\d+):([\d.]+)/.exec(r.stderr || '');
  if (!m) return null;
  return (+m[1]) * 3600 + (+m[2]) * 60 + parseFloat(m[3]);
}

export function readJSON(p, fallback = {}) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}
export function writeJSON(p, obj) {
  ensureDir(path.dirname(p));
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
}
