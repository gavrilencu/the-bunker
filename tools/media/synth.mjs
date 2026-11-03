// Procedural sound synthesis -> 32-bit float WAV in .cache/synth/<name>.wav
// Used as layers for designed sounds (explosion sub-boom, rumble, roar, hum...) and
// for ids with no suitable recording (geiger click, UI hover, radio static).
import fs from 'node:fs';
import path from 'node:path';
import { CACHE, ensureDir } from './lib.mjs';

const SR = 44100;
export const SYNTH_DIR = ensureDir(path.join(CACHE, 'synth'));

function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296 * 2 - 1; }; }

function writeWav(name, chans) {
  const n = chans[0].length, nc = chans.length;
  const buf = Buffer.alloc(44 + n * nc * 4);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * nc * 4, 4); buf.write('WAVE', 8);
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(3, 20); buf.writeUInt16LE(nc, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * nc * 4, 28); buf.writeUInt16LE(nc * 4, 32); buf.writeUInt16LE(32, 34);
  buf.write('data', 36); buf.writeUInt32LE(n * nc * 4, 40);
  let o = 44;
  for (let i = 0; i < n; i++) for (let c = 0; c < nc; c++) { buf.writeFloatLE(chans[c][i], o); o += 4; }
  const f = path.join(SYNTH_DIR, `${name}.wav`);
  fs.writeFileSync(f, buf);
  return f;
}

// one-pole lowpass with per-sample cutoff function
function lowpass(x, cutoff) {
  const y = new Float32Array(x.length); let z = 0;
  for (let i = 0; i < x.length; i++) {
    const fc = typeof cutoff === 'function' ? cutoff(i / SR) : cutoff;
    const a = 1 - Math.exp(-2 * Math.PI * fc / SR);
    z += a * (x[i] - z); y[i] = z;
  }
  return y;
}
const highpass = (x, fc) => { const l = lowpass(x, fc); return x.map((v, i) => v - l[i]); };
function brown(n, seed) { const r = rng(seed); const y = new Float32Array(n); let z = 0; for (let i = 0; i < n; i++) { z = (z + 0.02 * r()) * 0.998; y[i] = z; } return y; }
function white(n, seed) { const r = rng(seed); const y = new Float32Array(n); for (let i = 0; i < n; i++) y[i] = r(); return y; }
function norm(x, peak = 0.9) { let m = 0; for (const v of x) m = Math.max(m, Math.abs(v)); const g = m ? peak / m : 1; return x.map(v => v * g); }
// smooth random modulation in [0,1]
function slowRandom(n, rateHz, seed) {
  const r = rng(seed); const step = Math.floor(SR / rateHz); const pts = [];
  for (let i = 0; i <= n / step + 2; i++) pts.push((r() + 1) / 2);
  const y = new Float32Array(n);
  for (let i = 0; i < n; i++) { const k = i / step, a = Math.floor(k), f = k - a; const s = (1 - Math.cos(f * Math.PI)) / 2; y[i] = pts[a] * (1 - s) + pts[a + 1] * s; }
  return y;
}

export const GENERATORS = {
  // Sub-bass boom for the nuclear blast: falling sine + low noise thump
  sub_boom() {
    const n = SR * 8, y = new Float32Array(n); let ph = 0; const nz = lowpass(white(n, 7), 120);
    for (let i = 0; i < n; i++) {
      const t = i / SR; const f = 24 + 40 * Math.exp(-t * 1.6);
      ph += 2 * Math.PI * f / SR;
      const env = (1 - Math.exp(-t * 60)) * Math.exp(-t * 0.55);
      y[i] = env * (Math.sin(ph) + 0.25 * Math.sin(2 * ph)) + 2.5 * nz[i] * Math.exp(-t * 1.2);
    }
    return [norm(y)];
  },
  // Long rolling rumble (stereo, decorrelated)
  rumble() {
    const n = SR * 16; const out = [];
    for (const seed of [11, 12]) {
      const b = lowpass(lowpass(brown(n, seed), 180), 220); const mod = slowRandom(n, 1.3, seed + 100);
      out.push(norm(b.map((v, i) => { const t = i / SR; const env = (1 - Math.exp(-t * 3)) * Math.exp(-t * 0.22); return v * env * (0.55 + 0.45 * mod[i]); })));
    }
    return out;
  },
  // Blast-wave roar: swelling noise with sweeping filter (stereo)
  roar() {
    const n = SR * 9; const out = [];
    for (const seed of [21, 22]) {
      const w = white(n, seed);
      const cut = t => (t < 1.6 ? 300 + 2200 * (t / 1.6) : 2500 * Math.exp(-(t - 1.6) * 0.45) + 250);
      const f = lowpass(lowpass(w, cut), cut); const mod = slowRandom(n, 6, seed + 5);
      out.push(norm(f.map((v, i) => { const t = i / SR; const env = t < 1.6 ? Math.pow(t / 1.6, 2) : Math.exp(-(t - 1.6) * 0.42); return v * env * (0.7 + 0.3 * mod[i]); })));
    }
    return out;
  },
  // Low thump for heavy door slam
  thump() {
    const n = Math.floor(SR * 0.8), y = new Float32Array(n); let ph = 0;
    for (let i = 0; i < n; i++) { const t = i / SR; ph += 2 * Math.PI * (38 + 30 * Math.exp(-t * 18)) / SR; y[i] = Math.sin(ph) * (1 - Math.exp(-t * 400)) * Math.exp(-t * 7); }
    return [norm(y)];
  },
  // Mains hum (50 Hz + harmonics) with faint electrical buzz, 62 s
  hum() {
    const n = SR * 62, y = new Float32Array(n); const nz = lowpass(white(n, 31), 900); const mod = slowRandom(n, 0.2, 33);
    for (let i = 0; i < n; i++) { const t = i / SR; const w = 2 * Math.PI * 50 * t; y[i] = 0.6 * Math.sin(w) + 0.3 * Math.sin(2 * w + 0.4) + 0.15 * Math.sin(3 * w + 1.1) + 0.06 * Math.sin(6 * w) + 0.05 * nz[i] * (0.6 + 0.4 * mod[i]); }
    return [norm(y, 0.7)];
  },
  // Geiger counter single click: sharp broadband tick + tiny metallic ring
  geiger_click() {
    const n = Math.floor(SR * 0.03), y = new Float32Array(n); const w = white(n, 41);
    for (let i = 0; i < n; i++) { const t = i / SR; y[i] = w[i] * Math.exp(-t * 2200) + 0.35 * Math.sin(2 * Math.PI * 3800 * t) * Math.exp(-t * 400); }
    return [norm(highpass(y, 400))];
  },
  // Soft UI hover tick
  ui_hover() {
    const n = Math.floor(SR * 0.06), y = new Float32Array(n);
    for (let i = 0; i < n; i++) { const t = i / SR; y[i] = (Math.sin(2 * Math.PI * 2400 * t) * 0.6 + Math.sin(2 * Math.PI * 4100 * t) * 0.2) * (1 - Math.exp(-t * 3000)) * Math.exp(-t * 90); }
    return [norm(y)];
  },
  // Radio static: band-limited hiss, crackles, slow fading (22 s)
  radio_static() {
    const n = SR * 22; const w = white(n, 51);
    const band = highpass(lowpass(lowpass(w, 3600), 3600), 350);
    const fade = slowRandom(n, 0.7, 52), flutter = slowRandom(n, 9, 53); const r = rng(54);
    const y = new Float32Array(n);
    let crackle = 0;
    for (let i = 0; i < n; i++) {
      if (r() > 0.99965) crackle = 0.9 + 0.6 * Math.abs(r());
      crackle *= 0.985;
      const pop = crackle * w[(i * 7) % n];
      y[i] = band[i] * (0.45 + 0.4 * fade[i]) * (0.85 + 0.15 * flutter[i]) + pop * 0.5 + 0.03 * Math.sin(2 * Math.PI * 1000 * i / SR) * fade[i];
    }
    return [norm(y, 0.8)];
  },
  // Power down: buzzing hum whose pitch and level fall
  power_sweep_down() {
    const n = Math.floor(SR * 1.8), y = new Float32Array(n); let ph = 0;
    for (let i = 0; i < n; i++) { const t = i / SR; const f = 100 * Math.exp(-t * 1.3) + 18; ph += 2 * Math.PI * f / SR; const s = Math.sin(ph) + 0.5 * Math.sin(2 * ph) + 0.3 * Math.sign(Math.sin(3 * ph)) * 0.4; y[i] = s * Math.exp(-t * 1.6) * (1 - Math.exp(-t * 200)); }
    return [norm(lowpass(y, 2500))];
  },
  // Power up: rising hum that settles
  power_sweep_up() {
    const n = Math.floor(SR * 1.6), y = new Float32Array(n); let ph = 0;
    for (let i = 0; i < n; i++) { const t = i / SR; const f = 100 - 78 * Math.exp(-t * 3.2); ph += 2 * Math.PI * f / SR; const s = Math.sin(ph) + 0.5 * Math.sin(2 * ph) + 0.12 * Math.sign(Math.sin(3 * ph)); const env = Math.min(1, t / 0.5) * (t > 1.2 ? Math.max(0, 1 - (t - 1.2) / 0.4) : 1); y[i] = s * env; }
    return [norm(lowpass(y, 2500))];
  },
};

export function synth(name) {
  const f = path.join(SYNTH_DIR, `${name}.wav`);
  if (fs.existsSync(f)) return f;
  if (!GENERATORS[name]) throw new Error('no generator ' + name);
  return writeWav(name, GENERATORS[name]());
}

if (process.argv[1]?.endsWith('synth.mjs')) for (const k of Object.keys(GENERATORS)) console.log(synth(k));
