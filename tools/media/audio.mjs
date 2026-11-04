// Builds every audio id from tools/media/catalog.json into assets/audio/<id>.ogg
// Recipes layer/trim/process raw sources (see sources.mjs) and procedural layers (synth.mjs),
// then normalize (two-pass loudnorm for long sounds, peak normalize for short SFX) and
// encode Ogg Vorbis q5 @ 44.1 kHz. Usage: node audio.mjs [id ...]
import fs from 'node:fs';
import path from 'node:path';
import { ASSETS, CACHE, ensureDir, ffmpeg, duration, readJSON, writeJSON } from './lib.mjs';
import { SOURCES, fetchSource } from './sources.mjs';
import { synth } from './synth.mjs';

const OUT = ensureDir(path.join(ASSETS, 'audio'));
const TMP = ensureDir(path.join(CACHE, 'tmp'));
const manifestPath = path.join(OUT, 'manifest.json');
const manifest = readJSON(manifestPath);

const pitch = r => `aresample=44100,asetrate=${Math.round(44100 * r)},aresample=44100`;
const ROOM = 'aecho=0.8:0.6:45|95|160:0.30|0.20|0.12';          // concrete room
const CORRIDOR = 'aecho=0.8:0.7:70|140|230|340:0.35|0.25|0.16|0.10'; // long concrete corridor

// in(src, opts): src = SOURCES key, 'synth:<name>', or {key, inner}
const I = (src, o = {}) => ({ src, ...o });

const R = {
  siren_air_raid: { desc: 'French SAIP national alert siren, first full cycle (rise/fall wails + wind-down)', stereo: true, norm: ['lufs', -16],
    in: [I('bsb_siren_saip', { ss: 0, t: 100 })], post: 'afade=t=out:st=93:d=7' },

  explosion_nuclear: { desc: 'Designed distant nuclear blast: pitched-down explosion + thunder claps + procedural sub-boom and rolling rumble', stereo: true, norm: ['peak', -1],
    in: [
      I('synth:sub_boom', { gain: 0.9 }),
      I({ key: 'oga_explosions', inner: 'explosions/explode.wav' }, { chain: `${pitch(0.5)},lowpass=f=2500,afade=t=out:st=2.2:d=1.2`, gain: 0.8 }),
      I('wm_thunder_claps', { ss: 3.4, t: 15, chain: `${pitch(0.75)},lowpass=f=3500`, gain: 0.75, delay: 250 }),
      I('synth:rumble', { gain: 0.9, delay: 400 }),
    ], post: 'afade=t=out:st=12:d=4.5', maxlen: 16.5 },

  shockwave_wind: { desc: 'Blast wave: swelling procedural roar + violent wind gusts', stereo: true, norm: ['peak', -1],
    in: [
      I('synth:roar', { gain: 1.0 }),
      I('bsb_wind_foley', { ss: 30.8, t: 8.5, chain: 'highpass=f=70', gain: 0.8 }),
      I('wm_howling_wind', { ss: 42, t: 8.5, gain: 0.45 }),
    ], post: 'afade=t=in:d=0.3,afade=t=out:st=6:d=2.5', maxlen: 8.5 },

  door_vault_close: { desc: 'Heavy blast door: hinge grind, slam (pitched-down metal + sub thump), bolt lock, concrete corridor echo', norm: ['peak', -1],
    in: [
      I({ key: 'oga_workshop', inner: 'workshop/workshop - dragging metal.wav' }, { ss: 4.2, t: 2.5, chain: `${pitch(0.62)},afade=t=in:d=0.3,afade=t=out:st=2.3:d=0.6`, gain: 0.55 }),
      I({ key: 'oga_metalwood', inner: 'metal_slam_01.ogg' }, { chain: pitch(0.55), gain: 1.0, delay: 2500 }),
      I({ key: 'oga_metalwood', inner: 'metal_close_01.ogg' }, { chain: pitch(0.45), gain: 0.6, delay: 2520 }),
      I('synth:thump', { gain: 0.9, delay: 2480 }),
      I({ key: 'oga_metalwood', inner: 'lock_open_01.ogg' }, { chain: pitch(0.7), gain: 0.55, delay: 3500 }),
      I('wm_door_clasp', { ss: 14.5, t: 0.9, chain: `${pitch(0.8)},afade=t=out:st=0.75:d=0.35`, gain: 0.5, delay: 3900 }),
    ], post: `apad=pad_dur=2,${CORRIDOR},afade=t=out:st=5.4:d=1.4`, maxlen: 6.8 },

  metal_impact: { desc: 'Metal clang hit', norm: ['peak', -1], in: [I({ key: 'oga_metalwood', inner: 'metal_hit_03.ogg' })], post: `apad=pad_dur=0.4,${ROOM}` },

  ambient_bunker: { desc: 'Underground room tone: refrigeration motor + ventilation fan + 50 Hz mains hum', stereo: true, norm: ['lufs', -20], loop: [58, 3],
    in: [
      I('bsb_fridge_motor', { ss: 0.2, t: 61, chain: 'lowpass=f=700,highpass=f=35', gain: 0.6 }),
      I('loop:vmc', { t: 61, chain: 'lowpass=f=4000', gain: 0.35 }),
      I('synth:hum', { t: 61, gain: 0.12 }),
    ] },

  ambient_wasteland: { desc: 'Desolate howling wind', stereo: true, norm: ['lufs', -18], loop: [88, 4],
    in: [I('wm_howling_wind', { ss: 8, t: 92.5, chain: 'lowpass=f=9000' })] },

  ambient_morning: { desc: 'Morning bird song with distant traffic', stereo: true, norm: ['lufs', -20], loop: [60, 3],
    in: [I('wm_birds_morning', { ss: 1, t: 63.5, chain: 'highpass=f=60' })] },

  generator_loop: { desc: 'Running diesel engine (idle), loop', norm: ['lufs', -16], loop: [32, 3],
    in: [I('bsb_excavator', { ss: 2, t: 35.5, chain: 'highpass=f=30' })] },

  radio_static: { desc: 'Procedural shortwave radio static loop', norm: ['lufs', -20], loop: [19, 2.5], procedural: true,
    in: [I('synth:radio_static')] },

  geiger_click: { desc: 'Procedural geiger counter click', norm: ['peak', -1], procedural: true, in: [I('synth:geiger_click')] },
  ui_click: { desc: 'Old mechanical switch click', norm: ['peak', -3], in: [I('bsb_switch_old', { ss: 3.08, t: 0.14, chain: 'highpass=f=150,afade=t=out:st=0.09:d=0.05' })] },
  ui_hover: { desc: 'Procedural soft UI tick', norm: ['peak', -10], procedural: true, in: [I('synth:ui_hover')] },
  pickup: { desc: 'Cloth/item rustle', norm: ['peak', -2], in: [I('bsb_coat_rub', { ss: 3.45, t: 0.5, chain: 'afade=t=in:d=0.03,afade=t=out:st=0.3:d=0.2' }), I('bsb_canvas_bag', { ss: 4.2, t: 0.3, gain: 0.35, delay: 120, chain: 'afade=t=out:st=0.18:d=0.12' })] },
  eat: { desc: 'Crunch and chewing', norm: ['peak', -2], in: [I('bsb_eat_rusk', { ss: 0.15, t: 2.7, chain: 'afade=t=out:st=2.3:d=0.4' })] },
  drink: { desc: 'Drinking gulps', norm: ['peak', -2], in: [I('wm_drinking', { ss: 3.15, t: 2.6, chain: 'highpass=f=80,afade=t=in:d=0.05,afade=t=out:st=2.2:d=0.4' })] },
  craft: { desc: 'Metal hammering on workbench', norm: ['peak', -1], in: [I({ key: 'oga_workshop', inner: 'workshop/workshop - metal hammering.wav' }, { ss: 0.6, t: 1.95, chain: 'afade=t=out:st=1.6:d=0.35' })], post: `apad=pad_dur=0.5,${ROOM}` },
  dig: { desc: 'Shovel digging into soil', norm: ['peak', -1], in: [I('bsb_dig', { ss: 52.0, t: 1.8, chain: 'afade=t=in:d=0.02,afade=t=out:st=1.4:d=0.4' })] },
  gunshot_pistol: { desc: '.357 Magnum revolver shot', norm: ['peak', -1], in: [I('bsb_357', { ss: 0.03, t: 2.3, chain: 'afade=t=out:st=1.4:d=0.9' })] },
  gunshot_rifle: { desc: 'Winchester Magnum XTR shot (heavy long gun)', norm: ['peak', -1], in: [I('bsb_winchester', { ss: 0.98, t: 2.2, chain: 'afade=t=out:st=1.3:d=0.9' })] },
  reload: { desc: 'Handgun reload', norm: ['peak', -1], in: [I('oga_reload')] },
  melee_swing: { desc: 'Whoosh swing', norm: ['peak', -2], in: [I('bsb_sword_air', { chain: pitch(0.85) })] },
  melee_hit: { desc: 'Blunt hit: shovel knock + body thud', norm: ['peak', -1], in: [I('bsb_shovel_hit', { ss: 17.07, t: 0.45, chain: 'lowpass=f=3000,afade=t=out:st=0.3:d=0.15' }), I('bsb_canvas_bag', { ss: 4.2, t: 0.35, gain: 0.8, chain: 'afade=t=out:st=0.2:d=0.15' })] },
  creature_growl: { desc: 'Low monster growl', norm: ['peak', -1], in: [I('bsb_grunts', { ss: 0.0, t: 3.0, chain: `${pitch(0.85)},afade=t=out:st=2.4:d=0.6` })], post: `apad=pad_dur=0.5,${ROOM}` },
  creature_attack: { desc: 'Monster attack scream (zombie + monster pain layered)', norm: ['peak', -1],
    in: [I({ key: 'oga_zombies', inner: 'zombies/zombie-1.wav' }, { chain: pitch(0.92) }), I({ key: 'oga_monsters', inner: 'monster/painb.wav' }, { chain: pitch(0.75), gain: 0.6, delay: 40 })], post: `apad=pad_dur=0.5,${ROOM}` },
  heartbeat: { desc: 'Heartbeat loop (7 beats, ~66 bpm)', norm: ['peak', -2], loop: [6.33, 0.04], in: [I('bsb_heartbeat', { ss: 0.92, t: 6.4, chain: 'lowpass=f=1400' })] },
  water_pour: { desc: 'Pouring water from a bottle', norm: ['peak', -2], in: [I('bsb_glass_fill', { ss: 0.9, t: 4.6, chain: 'afade=t=in:d=0.05,afade=t=out:st=4.1:d=0.5' })] },
  gasmask_breath: { desc: 'Breathing processed to sound like a gas mask (band-limited, rubbery resonance)', norm: ['lufs', -20], loop: [30, 1.5],
    in: [I('bsb_breathing', { ss: 2, t: 31.5, chain: 'highpass=f=160,lowpass=f=2400,equalizer=f=900:t=q:w=1.2:g=7,aecho=0.7:0.6:7|13:0.35|0.22' })] },
  power_down: { desc: 'Breaker clack + falling electrical hum', norm: ['peak', -1],
    in: [I('bsb_breaker', { ss: 9.34, t: 0.35, chain: 'afade=t=out:st=0.25:d=0.1' }), I('synth:power_sweep_down', { gain: 0.6, delay: 30 })], post: `apad=pad_dur=0.5,${ROOM}` },
  power_up: { desc: 'Breaker clack + rising electrical hum', norm: ['peak', -1],
    in: [I('bsb_breaker', { ss: 13.75, t: 0.35, chain: 'afade=t=out:st=0.25:d=0.1' }), I('synth:power_sweep_up', { gain: 0.55, delay: 80 })], post: `apad=pad_dur=0.5,${ROOM}` },
  tinnitus: { desc: 'EXTRA (not in catalog): post-blast ear ringing', norm: ['lufs', -22], extra: true, in: [I('bsb_tinnitus', { ss: 2, t: 10, chain: 'afade=t=in:d=0.2,afade=t=out:st=4:d=6' })] },

  music_menu: { desc: 'Menu music', stereo: true, norm: ['lufs', -16], music: true, in: [I('km_thunder_dreams')] },
  music_bunker: { desc: 'Bunker music', stereo: true, norm: ['lufs', -16], music: true, in: [I('km_heavy_heart')] },
  music_tension: { desc: 'Expedition / danger music', stereo: true, norm: ['lufs', -16], music: true, in: [I('km_static_motion')] },
};

// Footstep variants (onsets picked by analyze.mjs on the source recordings)
[14.49, 16.87, 23.93, 26.18].forEach((t, i) => {
  R[`footstep_concrete_${i + 1}`] = { desc: `Footstep on concrete, variant ${i + 1}`, norm: ['peak', -1], in: [I('bsb_steps_concrete', { ss: t - 0.02, t: 0.34, chain: 'highpass=f=60,afade=t=in:d=0.005,afade=t=out:st=0.24:d=0.1' })] };
});
[10.49, 15.94, 24.35, 27.68].forEach((t, i) => {
  R[`footstep_grass_${i + 1}`] = { desc: `Footstep on grass, variant ${i + 1}`, norm: ['peak', -1], in: [I('bsb_steps_grass', { ss: t - 0.04, t: 0.48, chain: 'highpass=f=80,afade=t=in:d=0.01,afade=t=out:st=0.33:d=0.15' })] };
});

// ---------------------------------------------------------------------------
// Round 3: weapons, impacts, building, UI, vault door, metal footsteps, heavy breathing
const FF = (sub) => ({ key: 'oga_firearms', inner: `Prepared SFX Library/${sub}` });
const MW = (f) => ({ key: 'oga_metalwood', inner: f });
const C100 = (f) => ({ key: 'oga_100cc0', inner: f });
const WS = (f) => ({ key: 'oga_workshop', inner: `workshop/workshop - ${f}.wav` });
const SG = (f) => ({ key: 'oga_shotgun_sounds', inner: `ShotgunSounds/${f}` });
Object.assign(R, {
  rifle_shot: { desc: 'AK-47 single shot (Free Firearm Sound Library), outdoor tail', norm: ['peak', -1],
    in: [I(FF('AK-47/C_31P.wav'), { ss: 0.28, t: 1.7, chain: 'highpass=f=35,afade=t=in:d=0.004,afade=t=out:st=0.9:d=0.8' })] },
  shotgun_shot: { desc: 'Pump shotgun shot (Mossberg, Free Firearm Sound Library)', norm: ['peak', -1],
    in: [I(FF('Mossberg/N_26P.wav'), { ss: 0.72, t: 2.2, chain: 'highpass=f=30,afade=t=in:d=0.004,afade=t=out:st=1.3:d=0.9' })] },
  dry_fire: { desc: 'Empty gun: trigger / hammer click', norm: ['peak', -3],
    in: [I('oga_equip_clicks', { ss: 0.12, t: 0.22, chain: 'highpass=f=300,afade=t=out:st=0.14:d=0.08' })] },
  weapon_equip: { desc: 'Weapon raised / handled: metal clicks + cloth', norm: ['peak', -2],
    in: [I('oga_equip_clicks3', { ss: 1.4, t: 0.62, chain: 'highpass=f=120,afade=t=out:st=0.45:d=0.17' }),
      I('bsb_coat_rub', { ss: 0.4, t: 0.4, chain: 'afade=t=in:d=0.05,afade=t=out:st=0.25:d=0.15', gain: 0.35 })] },
  reload_rifle: { desc: 'Assault rifle reload (mag out / in / charge)', norm: ['peak', -1], in: [I('oga_rifle_reload', { chain: 'highpass=f=60' })] },
  reload_shotgun: { desc: 'Shotgun: shell loaded into the chamber + pump rack', norm: ['peak', -1],
    in: [I(SG('Shell in Chamber.mp3'), { t: 1.75, chain: 'afade=t=out:st=1.6:d=0.15' }), I('oga_shotgun_cock', { delay: 1700 })] },
  bullet_whizz: { desc: 'Bullet passing close by (derived: fast air swish pitched up, band-passed)', norm: ['peak', -3],
    in: [I('bsb_sword_air', { chain: `${pitch(1.9)},highpass=f=900,lowpass=f=9000,afade=t=in:d=0.02,afade=t=out:st=0.18:d=0.12` })], maxlen: 0.35 },
  build_place: { desc: 'Heavy object placed and secured: hammer blows + thud', norm: ['peak', -1],
    in: [I(MW('hammer_02.ogg'), { gain: 0.8 }), I(WS('thuds'), { ss: 0.4, t: 1.0, gain: 1.0, delay: 260 }), I(MW('hammer_01.ogg'), { gain: 0.6, delay: 900 })], post: `apad=pad_dur=0.3,${ROOM}` },
  demolish: { desc: 'Dismantling: crowbar clank + metal clatter + falling scrap', norm: ['peak', -1],
    in: [I('oga_mech_clank', { gain: 0.9 }), I(WS('loud clatter'), { gain: 0.9, delay: 200 }), I(MW('metal_falling_01.ogg'), { gain: 0.8, delay: 550 })], post: `apad=pad_dur=0.3,${ROOM}` },
  upgrade_done: { desc: 'Upgrade finished: ratchet turns, clank, soft metallic ping', norm: ['peak', -2],
    in: [I(WS('ratchet1'), { ss: 0, t: 1.55, chain: 'afade=t=out:st=1.4:d=0.15' }), I('oga_mech_clank', { gain: 0.8, delay: 1550 }), I(WS('ping'), { gain: 3.0, delay: 1800 })], post: 'apad=pad_dur=0.4' },
  map_open: { desc: 'Paper map unfolded', norm: ['peak', -3], in: [I('oga_map')] },
  ui_confirm: { desc: 'UI confirm: firm button press', norm: ['peak', -4], in: [I({ key: 'oga_buttons', inner: 'buttons_and_clicks/button05.mp3.flac' }, { ss: 0.03, t: 0.3, chain: 'afade=t=out:st=0.2:d=0.1' })] },
  ui_deny: { desc: 'UI deny: low double click', norm: ['peak', -4], in: [I({ key: 'oga_buttons', inner: 'buttons_and_clicks/button01.mp3.flac' }, { ss: 0.02, t: 0.55, chain: `${pitch(0.75)},lowpass=f=3500,afade=t=out:st=0.45:d=0.1` })] },
  door_vault_open: { desc: 'Heavy blast door opening: bolts released, long hinge groan, settling thump, corridor echo', norm: ['peak', -1],
    in: [
      I(MW('lock_open_01.ogg'), { chain: pitch(0.7), gain: 0.7 }),
      I('oga_mech_clank', { chain: pitch(0.6), gain: 0.8, delay: 450 }),
      I('bsb_metal_creak', { ss: 11.8, t: 4.4, chain: `${pitch(0.78)},afade=t=in:d=0.4,afade=t=out:st=3.6:d=0.8`, gain: 0.9, delay: 900 }),
      I(WS('dragging metal'), { ss: 4.2, t: 2.5, chain: `${pitch(0.6)},afade=t=in:d=0.3,afade=t=out:st=2.0:d=0.5`, gain: 0.4, delay: 1400 }),
      I('synth:thump', { gain: 0.7, delay: 4900 }),
    ], post: `apad=pad_dur=1,${CORRIDOR},afade=t=out:st=5.2:d=0.8`, maxlen: 6.0 },
  breath_heavy: { desc: 'Exhausted heavy breathing (two takes, seamless loop)', norm: ['lufs', -22], loop: [5.8, 0.3],
    in: [I('oga_breath_tired', { chain: 'highpass=f=80' }), I('oga_breath_tired', { chain: `${pitch(0.96)},highpass=f=80`, delay: 3000 })] },
});
[[C100('metal_03.ogg'), 1.9], [MW('metal_hit_01.ogg'), 2.2], [WS('ping'), 1.5]].forEach(([src, r], i) => {
  R[`shell_casing_${i + 1}`] = { desc: `Brass casing hitting the floor, variant ${i + 1} (derived: small metal hit pitched up, with bounces)`, norm: ['peak', -6],
    in: [I(src, { chain: `${pitch(r)},highpass=f=1800,afade=t=out:st=0.18:d=0.12`, t: 0.3 }), I(src, { chain: `${pitch(r * 1.08)},highpass=f=1800,afade=t=out:st=0.1:d=0.08`, t: 0.18, gain: 0.45, delay: 150 }),
      I(src, { chain: `${pitch(r * 1.15)},highpass=f=1800,afade=t=out:st=0.06:d=0.06`, t: 0.12, gain: 0.2, delay: 260 })], maxlen: 0.6 };
});
[1.0, 1.18, 0.86].forEach((r, i) => {
  R[`impact_concrete_${i + 1}`] = { desc: `Bullet hitting concrete, variant ${i + 1}`, norm: ['peak', -2],
    in: [I({ key: 'oga_impact', inner: 'qubodupImpact/qubodupImpactStone.flac' }, { chain: `${pitch(r)},highpass=f=200` }), ...(i === 2 ? [I(WS('quiet scrape'), { t: 0.5, gain: 0.5, delay: 60, chain: 'highpass=f=400' })] : [])], maxlen: 0.6 };
});
[[{ key: 'oga_impact', inner: 'qubodupImpact/qubodupImpactMetal.flac' }, 1.0], [MW('metal_hit_01.ogg'), 1.25], [C100('metal_07.ogg'), 1.1]].forEach(([src, r], i) => {
  R[`impact_metal_${i + 1}`] = { desc: `Bullet hitting metal, variant ${i + 1}`, norm: ['peak', -2], in: [I(src, { chain: `${pitch(r)},highpass=f=250`, t: 0.6 })], maxlen: 0.6 };
});
['qubodupImpactMeat01.flac', 'qubodupImpactMeat02.flac'].forEach((f, i) => {
  R[`impact_flesh_${i + 1}`] = { desc: `Bullet / blow hitting flesh, variant ${i + 1}`, norm: ['peak', -2], in: [I({ key: 'oga_impact', inner: `qubodupImpact/${f}` }, { chain: 'highpass=f=80' })] };
});
['metal_steps_01.wav', 'metal_steps_03.wav', 'metal_steps_05.wav', 'metal_steps_07.wav'].forEach((f, i) => {
  R[`footstep_metal_${i + 1}`] = { desc: `Footstep on metal plates, variant ${i + 1}`, norm: ['peak', -1], in: [I({ key: 'oga_metal_steps', inner: f }, { chain: 'highpass=f=60,afade=t=in:d=0.003' })], post: 'apad=pad_dur=0.15,aecho=0.6:0.5:35:0.18' };
});
R.footstep_metal = { ...R.footstep_metal_1, desc: 'Footstep on metal (= variant 1; see footstep_metal_1.._4)' };

// ---------------------------------------------------------------------------
// Round 4: first-person consume / bandage / sleep actions (slices picked with analyze.mjs)
const GAUZE = 'highpass=f=150,lowpass=f=3200:p=1,lowpass=f=7500'; // soften the synthetic-coat rustle
const SPRING = (r) => `${pitch(r)},highpass=f=250`;              // large tension spring -> bed springs
Object.assign(R, {
  gulp: { desc: 'Single swallow / gulp of water', norm: ['peak', -2],
    in: [I('wm_drinking', { ss: 3.36, t: 0.46, chain: 'highpass=f=90,afade=t=in:d=0.04,afade=t=out:st=0.32:d=0.14' })] },
  bite: { desc: 'Single crunchy bite into a dry biscuit', norm: ['peak', -1],
    in: [I('bsb_eat_rusk', { ss: 9.6, t: 0.46, chain: 'highpass=f=60,afade=t=in:d=0.005,afade=t=out:st=0.34:d=0.12' })] },
  chew: { desc: 'Chewing with the mouth closed (three chews, no crunch)', norm: ['peak', -3.5],
    in: [I('bsb_eat_rusk', { ss: 11.42, t: 1.32, chain: 'highpass=f=60,afade=t=in:d=0.01,afade=t=out:st=1.24:d=0.08' })] },
  spoon_can: { desc: 'Spoon scraping and clinking inside a container', norm: ['peak', -4],
    in: [I('bsb_spoon_mug', { ss: 0.11, t: 0.62, chain: 'highpass=f=200,afade=t=in:d=0.003,afade=t=out:st=0.47:d=0.15' })] },
  bandage_tear: { desc: 'Short cloth tear (tearing a bandage strip)', norm: ['peak', -2],
    in: [I('bsb_cloth_tear', { ss: 1.84, t: 0.82, chain: 'highpass=f=100,afade=t=in:d=0.005,afade=t=out:st=0.7:d=0.12' })] },
  bandage_wrap: { desc: 'Soft gauze rustle: wrapping one turn of a bandage', norm: ['peak', -9],
    in: [I('bsb_coat_rub', { ss: 7.82, t: 0.6, chain: `${pitch(0.8)},${GAUZE},afade=t=in:d=0.06,afade=t=out:st=0.58:d=0.17` })] },
  pills: { desc: 'Pills rattling in a small plastic bottle (one shake)', norm: ['peak', -8],
    in: [I('wm_pill_shake', { ss: 0.28, t: 0.34, chain: 'highpass=f=120,afade=t=in:d=0.01,afade=t=out:st=0.24:d=0.1' })] },
  breath_out: { desc: 'Relieved exhale through the mouth (after drinking)', norm: ['peak', -8],
    in: [I('bsb_sigh_mouth', { ss: 1.98, t: 1.15, chain: 'highpass=f=100,afade=t=in:d=0.03,afade=t=out:st=0.6:d=0.55' })] },
  bed_lie: { desc: 'Lying down on an old metal bunk: spring creaks + blanket rustle', norm: ['peak', -3.5],
    in: [ // sit down (rustle + creak), legs under the blanket (rustle), lie back (creak with settling accents)
      I('bsb_coat_rub', { ss: 0.32, t: 0.55, chain: `${pitch(0.85)},${GAUZE},afade=t=in:d=0.04,afade=t=out:st=0.45:d=0.2`, gain: 0.5 }),
      I('bsb_spring_large', { ss: 14.99, t: 0.7, chain: `${SPRING(1.7)},afade=t=in:d=0.01,afade=t=out:st=0.28:d=0.13`, gain: 0.75, delay: 80 }),
      I('bsb_coat_rub', { ss: 1.36, t: 0.55, chain: `${pitch(0.85)},${GAUZE},afade=t=in:d=0.05,afade=t=out:st=0.45:d=0.2`, gain: 0.4, delay: 520 }),
      I('bsb_spring_large', { ss: 7.55, t: 1.2, chain: `${SPRING(1.7)},afade=t=in:d=0.02,afade=t=out:st=0.42:d=0.28`, gain: 0.8, delay: 640 }),
    ], post: 'afade=t=out:st=1.2:d=0.15', maxlen: 1.36 },
  bed_rise: { desc: 'Getting up from an old metal bunk: blanket pushed off, springs release', norm: ['peak', -2],
    in: [
      I('bsb_coat_rub', { ss: 2.57, t: 0.55, chain: `${pitch(0.85)},${GAUZE},afade=t=in:d=0.05,afade=t=out:st=0.5:d=0.2`, gain: 0.55 }),
      I('bsb_spring_large', { ss: 39.93, t: 0.7, chain: `${SPRING(1.7)},afade=t=in:d=0.01,afade=t=out:st=0.3:d=0.11`, gain: 0.8, delay: 100 }),
      I('bsb_spring_large', { ss: 45.62, t: 0.75, chain: `${SPRING(1.85)},afade=t=in:d=0.01,afade=t=out:st=0.25:d=0.15`, gain: 0.7, delay: 650 }),
    ], post: 'afade=t=out:st=1.1:d=0.2', maxlen: 1.3 },
  yawn: { desc: 'Man yawning on waking (airy inhale, falling "aah")', norm: ['peak', -11],
    in: [I('wm_yawn_2', { ss: 1.1, t: 2.0, chain: 'highpass=f=100,afftdn=nr=12:nf=-52,acompressor=threshold=0.05:ratio=4:attack=10:release=150,afade=t=in:d=0.08,afade=t=out:st=1.75:d=0.25' })] },
});

// Base ids (= variant 1) so a loader asking for plain 'footstep_concrete' also works
R.footstep_concrete = { ...R.footstep_concrete_1, desc: 'Footstep on concrete (= variant 1; see footstep_concrete_1.._4)' };
R.footstep_grass = { ...R.footstep_grass_1, desc: 'Footstep on grass (= variant 1; see footstep_grass_1.._4)' };

// ---------------------------------------------------------------------------
const helperLoops = {
  // seamless VMC fan loop, so it can be repeated under a 60 s bed
  vmc: { src: 'bsb_vmc', L: 18.5, X: 2.5 },
};

async function resolveInput(inp) {
  if (typeof inp.src === 'string' && inp.src.startsWith('synth:')) return { file: synth(inp.src.slice(6)), credit: null };
  if (typeof inp.src === 'string' && inp.src.startsWith('loop:')) {
    const h = helperLoops[inp.src.slice(5)];
    const f = path.join(TMP, `helper_${inp.src.slice(5)}.wav`);
    if (!fs.existsSync(f)) {
      const raw = await fetchSource(h.src);
      const tmpIn = path.join(TMP, `helper_${inp.src.slice(5)}_src.wav`);
      ffmpeg(['-i', raw, '-c:a', 'pcm_f32le', tmpIn]);
      makeLoop(tmpIn, f, h.L, h.X);
    }
    return { file: f, credit: h.src, loopFile: true };
  }
  const key = typeof inp.src === 'string' ? inp.src : inp.src.key;
  const p = await fetchSource(key);
  const file = typeof inp.src === 'string' ? p : path.join(p, inp.src.inner);
  return { file, credit: key };
}

/** Seamless loop of length L: head [0,L) fades in while tail [L,L+X) fades out over its first X seconds
 *  (equal-power). Uses two separate inputs of the same file so both branches start at t=0. */
function makeLoop(inFile, outFile, L, X) {
  ffmpeg(['-t', String(L), '-i', inFile, '-ss', String(L), '-t', String(X), '-i', inFile, '-filter_complex',
    `[0:a]afade=t=in:st=0:d=${X}:curve=qsin[h];[1:a]afade=t=out:st=0:d=${X}:curve=qsin[t];[h][t]amix=inputs=2:duration=first:normalize=0[o]`,
    '-map', '[o]', '-c:a', 'pcm_f32le', outFile]);
}

// astats works on float data, so peaks above 0 dBFS are measured correctly (volumedetect clips)
function peakDb(file) {
  const err = ffmpeg(['-i', file, '-af', 'astats=measure_perchannel=none', '-f', 'null', '-'], { quiet: false });
  return parseFloat(/Peak level dB: ([-\d.inf]+)/.exec(err.slice(err.lastIndexOf('Overall')))[1]);
}

/** Encode with filters; if the decoded Vorbis peak overshoots maxPeak (common on clipped sources),
 *  re-encode with an extra trim. */
function encodeGuarded(inFile, outFile, af, stereo, maxPeak) {
  let trim = 0;
  for (let i = 0; i < 3; i++) {
    const chain = [af, trim ? `volume=${trim.toFixed(2)}dB` : null].filter(Boolean).join(',');
    ffmpeg(['-i', inFile, '-af', chain, '-ac', stereo ? '2' : '1', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '5', outFile]);
    const p = peakDb(outFile);
    if (!(p > maxPeak + 0.1)) return { peak_db: +p.toFixed(2) };
    trim -= (p - maxPeak) + 0.2;
  }
  return { peak_db: +peakDb(outFile).toFixed(2) };
}

function loudnorm(inFile, outFile, I, stereo) {
  const base = `loudnorm=I=${I}:TP=-1.5:LRA=11`;
  const err = ffmpeg(['-i', inFile, '-af', `${base}:print_format=json`, '-f', 'null', '-'], { quiet: false });
  const j = JSON.parse(err.slice(err.lastIndexOf('{'), err.lastIndexOf('}') + 1));
  const af = `${base}:measured_I=${j.input_i}:measured_TP=${j.input_tp}:measured_LRA=${j.input_lra}:measured_thresh=${j.input_thresh}:offset=${j.target_offset}:linear=true,aresample=44100,alimiter=limit=0.84:attack=3:release=60:level=false`;
  return { measured_lufs: +j.input_i, ...encodeGuarded(inFile, outFile, af, stereo, -1.0) };
}

function peaknorm(inFile, outFile, target, stereo) {
  const g = target - peakDb(inFile);
  return { gain_db: +g.toFixed(2), ...encodeGuarded(inFile, outFile, `volume=${g.toFixed(2)}dB`, stereo, target) };
}

async function build(id, r) {
  const args = [], parts = [], credits = new Set();
  const lay = r.stereo ? 'stereo' : 'mono';
  for (let i = 0; i < r.in.length; i++) {
    const inp = r.in[i];
    const { file, credit, loopFile } = await resolveInput(inp);
    if (credit) credits.add(credit);
    if (loopFile) args.push('-stream_loop', '-1');
    if (inp.ss) args.push('-ss', String(inp.ss));
    if (inp.t) args.push('-t', String(inp.t));
    args.push('-i', file);
    const ch = [`aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=${lay}`];
    if (inp.chain) ch.push(inp.chain);
    if (inp.gain !== undefined) ch.push(`volume=${inp.gain}`);
    if (inp.delay) ch.push(`adelay=delays=${inp.delay}:all=1`);
    parts.push(`[${i}:a]${ch.join(',')}[s${i}]`);
  }
  let graph = parts.join(';');
  let last;
  if (r.in.length > 1) { graph += `;${r.in.map((_, i) => `[s${i}]`).join('')}amix=inputs=${r.in.length}:duration=longest:normalize=0[m]`; last = 'm'; }
  else last = 's0';
  const post = [r.post, r.maxlen ? `atrim=end=${r.maxlen}` : null].filter(Boolean).join(',');
  if (post) { graph += `;[${last}]${post}[p]`; last = 'p'; }
  let tmp = path.join(TMP, `${id}.wav`);
  ffmpeg([...args, '-filter_complex', graph, '-map', `[${last}]`, '-c:a', 'pcm_f32le', tmp]);
  if (r.loop) { const lt = path.join(TMP, `${id}_loop.wav`); makeLoop(tmp, lt, r.loop[0], r.loop[1]); tmp = lt; }
  const out = path.join(OUT, `${id}.ogg`);
  const info = r.norm[0] === 'lufs' ? loudnorm(tmp, out, r.norm[1], !!r.stereo) : peaknorm(tmp, out, r.norm[1], !!r.stereo);
  const dur = duration(out);
  const srcs = [...credits].map(k => SOURCES[k]);
  manifest[id] = {
    file: `res://assets/audio/${id}.ogg`,
    title: r.desc,
    author: srcs.length ? [...new Set(srcs.map(s => s.author))].join('; ') : 'procedural (Bunker media pipeline)',
    source_url: srcs.map(s => s.source_url).join(' ; ') || 'tools/media/synth.mjs',
    license: srcs.length ? [...new Set(srcs.map(s => s.license))].join(' + ') : 'CC0 1.0 (procedural, original)',
    notes: [
      srcs.length ? 'Sources: ' + srcs.map(s => `${s.title} (${s.author}, ${s.license})`).join('; ') : null,
      r.in.some(x => typeof x.src === 'string' && x.src.startsWith('synth:')) ? 'Includes procedural layers (tools/media/synth.mjs).' : null,
      srcs.find(s => s.notes)?.notes || null,
      r.extra ? 'Extra id, not in catalog.' : null,
    ].filter(Boolean).join(' '),
    ...(r.loop || r.music ? { loop: true } : {}),
    duration_s: dur ? +dur.toFixed(2) : null,
    channels: r.stereo ? 2 : 1,
    ...(r.norm[0] === 'lufs' ? { loudness_lufs: r.norm[1] } : { peak_dbfs: r.norm[1] }),
    ...(r.procedural || !srcs.length ? { procedural: true } : {}),
  };
  return dur;
}

const only = process.argv.slice(2);
for (const [id, r] of Object.entries(R)) {
  if (only.length && !only.includes(id)) continue;
  try { const d = await build(id, r); console.log(`ok ${id} ${d?.toFixed(2)}s`); }
  catch (e) { console.error(`FAILED ${id}: ${e.message.slice(0, 600)}`); }
}
writeJSON(manifestPath, manifest);
console.log('done');
