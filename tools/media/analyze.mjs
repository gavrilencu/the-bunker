// Audio analysis helpers: decode to PCM, envelope, onsets.
// CLI: node analyze.mjs <file> [binSeconds]  -> prints info, envelope sparkline and onsets.
import { spawnSync } from 'node:child_process';
import { FFMPEG } from './lib.mjs';

export function decode(file, sr = 22050) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-i', file, '-ac', '1', '-ar', String(sr), '-f', 'f32le', '-'], { maxBuffer: 1024 * 1024 * 1024 });
  if (r.status !== 0) throw new Error('decode failed ' + file + r.stderr);
  const b = r.stdout;
  return { data: new Float32Array(b.buffer, b.byteOffset, Math.floor(b.length / 4)), sr };
}

export function envelope({ data, sr }, win = 0.01) {
  const n = Math.max(1, Math.round(win * sr));
  const out = new Float32Array(Math.ceil(data.length / n));
  for (let i = 0; i < out.length; i++) {
    let s = 0; const a = i * n, e = Math.min(data.length, a + n);
    for (let j = a; j < e; j++) s += data[j] * data[j];
    out[i] = Math.sqrt(s / Math.max(1, e - a));
  }
  return out;
}

/** Onsets: rising edges of the 10ms RMS envelope above `thr`*max, min gap seconds. */
export function onsets(pcm, { thr = 0.25, gap = 0.25, win = 0.01 } = {}) {
  const env = envelope(pcm, win);
  let max = 0; for (const v of env) max = Math.max(max, v);
  const res = []; let last = -1e9;
  // local background: mean of the previous 100ms
  for (let i = 1; i < env.length; i++) {
    const t = i * win;
    const bgStart = Math.max(0, i - 10);
    let bg = 0; for (let j = bgStart; j < i; j++) bg += env[j]; bg /= Math.max(1, i - bgStart);
    if (env[i] > thr * max && env[i] > bg * 2.2 && t - last > gap) {
      // peak within next 80ms
      let pk = env[i]; for (let j = i; j < Math.min(env.length, i + 8); j++) pk = Math.max(pk, env[j]);
      res.push({ t: +t.toFixed(3), peak: +(pk / max).toFixed(3) });
      last = t;
    }
  }
  return res;
}

const db = v => (v > 0 ? 20 * Math.log10(v) : -120).toFixed(1);

if (process.argv[1]?.endsWith('analyze.mjs')) {
  const [file, binArg, thrArg] = process.argv.slice(2);
  const pcm = decode(file);
  const dur = pcm.data.length / pcm.sr;
  let peak = 0, ss = 0; for (const v of pcm.data) { peak = Math.max(peak, Math.abs(v)); ss += v * v; }
  console.log(`${file.split(/[\\/]/).pop()} | ${dur.toFixed(2)}s | peak ${db(peak)} dB | rms ${db(Math.sqrt(ss / pcm.data.length))} dB`);
  const bin = +(binArg || Math.max(0.05, dur / 120));
  const env = envelope(pcm, bin);
  let m = 0; for (const v of env) m = Math.max(m, v);
  const chars = ' ▁▂▃▄▅▆▇█';
  let line = '';
  for (const v of env) { const d = v > 0 ? Math.max(0, 1 + Math.log10(v / m) / 3) : 0; line += chars[Math.min(8, Math.round(d * 8))]; }
  for (let i = 0; i < line.length; i += 60) console.log(`${(i * bin).toFixed(1).padStart(6)}s ${line.slice(i, i + 60)}`);
  const ons = onsets(pcm, { thr: +(thrArg || 0.2) });
  console.log(`onsets(${ons.length}): ` + ons.slice(0, 60).map(o => `${o.t}(${o.peak})`).join(' '));
}
