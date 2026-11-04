// Audio source registry: every raw recording used by audio.mjs, with license info.
// Each source is fetched into its own dir: .cache/raw/<key>/
import path from 'node:path';
import fs from 'node:fs';
import { RAW, download, getJSON } from './lib.mjs';

const BSB = (id, title) => ({
  url: `https://bigsoundbank.com/UPLOAD/flac/${id}.flac`, file: `${id}.flac`,
  alts: [['ogg', `https://bigsoundbank.com/UPLOAD/ogg/${id}.ogg`], ['mp3', `https://bigsoundbank.com/UPLOAD/mp3/${id}.mp3`]], bsbId: id,
  title, author: 'Joseph Sardin (BigSoundBank.com)', license: 'CC0 1.0',
  source_url: `https://bigsoundbank.com/search?q=${id}`,
});
const WM = (fileTitle, author, license) => ({
  commons: fileTitle, title: fileTitle.replace(/^File:/, ''), author, license,
  source_url: `https://commons.wikimedia.org/wiki/${encodeURIComponent(fileTitle.replace(/ /g, '_'))}`,
});
const OGA = (slug, fileUrl, title, author, license, inner) => ({
  url: fileUrl, file: decodeURIComponent(path.basename(fileUrl)), inner, title, author, license,
  source_url: `https://opengameart.org/content/${slug}`,
});
const KM = (title) => ({
  url: `https://incompetech.com/music/royalty-free/mp3-royaltyfree/${encodeURIComponent(title)}.mp3`, file: `${title}.mp3`,
  title: `"${title}"`, author: 'Kevin MacLeod (incompetech.com)', license: 'CC BY 4.0',
  source_url: 'https://incompetech.com/music/royalty-free/music.html',
  notes: `"${title}" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License http://creativecommons.org/licenses/by/4.0/`,
});

export const SOURCES = {
  // --- BigSoundBank (CC0) ---
  bsb_siren_saip:     BSB('3259', 'National Alert Signal'),
  bsb_wind_village:   BSB('0625', 'Strong Wind in a Village'),
  bsb_wind_foley:     BSB('0595', 'Wind'),
  bsb_metal_creak:    BSB('0616', 'Creaking metallic door'),
  bsb_steps_concrete: BSB('1318', 'Fast Steps on Concrete'),
  bsb_steps_concrete2: BSB('0514', 'Footsteps, Shoe on Concrete'),
  bsb_steps_grass:    BSB('0854', 'Steps in the short grass'),
  bsb_fridge_motor:   BSB('3597', 'Refrigeration unit'),
  bsb_vmc:            BSB('0957', 'VMC engine'),
  bsb_excavator:      BSB('2147', 'Excavator, engine'),
  bsb_switch_old:     BSB('0540', 'Old switch'),
  bsb_coat_rub:       BSB('1104', 'Synthetic Coat Rubbed'),
  bsb_canvas_bag:     BSB('0576', 'Canvas bag on floor'),
  bsb_eat_rusk:       BSB('0407', 'Eat a Rusk'),
  bsb_dig:            BSB('1305', 'Dig With a Shovel'),
  bsb_357:            BSB('0438', 'Shot in .357 Magnum'),
  bsb_winchester:     BSB('0397', 'Shot of Winchester Magnum XTR'),
  bsb_sword_air:      BSB('0128', 'Sword Through the Air'),
  bsb_shovel_hit:     BSB('1084', 'Shot of shovel'),
  bsb_grunts:         BSB('0486', 'Grunts'),
  bsb_heartbeat:      BSB('0218', 'Heart Beat'),
  bsb_glass_fill:     BSB('0003', 'Glass (filling with a water bottle)'),
  bsb_breathing:      BSB('2195', 'Man Breathing'),
  bsb_breaker:        BSB('1092', 'Electric circuit breaker'),
  bsb_tinnitus:       BSB('1388', 'Tinnitus'),
  // --- Wikimedia Commons ---
  wm_birds_morning:   WM('File:Bird sings in the morning with cars in the background.ogg', 'ezwa', 'Public domain'),
  wm_howling_wind:    WM('File:Howling wind.ogg', 'Tvabutzku1234', 'CC0 1.0'),
  wm_drinking:        WM('File:Drinking a glass of wat.ogg', 'ezwa', 'Public domain'),
  wm_thunder_claps:   WM('File:Thunder Claps.ogg', 'Jonathan Hunt', 'CC BY-SA 4.0'),
  wm_door_clasp:      WM('File:Rusty metal door clasp.ogg', 'stephan', 'Public domain'),
  // --- OpenGameArt ---
  oga_explosions:     OGA('2-high-quality-explosions', 'https://opengameart.org/sites/default/files/explosions.7z', '2 High Quality Explosions', 'Michel Baradari (uploaded by qubodup)', 'CC BY 3.0'),
  oga_monsters:       OGA('15-monster-gruntpaindeath-sounds', 'https://opengameart.org/sites/default/files/michelbaradari-monsters.7z', '15 monster grunt/pain/death sounds', 'Michel Baradari (uploaded by qubodup)', 'CC BY 3.0'),
  oga_zombies:        OGA('zombies-sound-pack', 'https://opengameart.org/sites/default/files/zombies.zip', 'Zombies Sound Pack', 'artisticdude', 'CC0 1.0'),
  oga_metalwood:      OGA('100-cc0-metal-and-wood-sfx', 'https://opengameart.org/sites/default/files/100-CC0-wood-metal-SFX.zip', '100 CC0 metal and wood SFX', 'rubberduck', 'CC0 1.0'),
  oga_workshop:       OGA('68-workshop-sounds', 'https://opengameart.org/sites/default/files/workshop.7z', '68 Workshop Sounds', 'bart', 'CC0 1.0'),
  oga_reload:         OGA('handgun-reload-sound-effect', 'https://opengameart.org/sites/default/files/reload.wav', 'Handgun Reload Sound Effect', 'zer0_sol', 'CC0 1.0'),
  // round 3 (weapons / building / UI)
  oga_firearms:       OGA('the-free-firearm-sound-library', 'https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z', 'The Free Firearm Sound Library (Prepared SFX Library)', 'The Free Firearm Sound Library team (uploaded by bart)', 'CC0 1.0'),
  oga_metal_steps:    OGA('metal-footsteps-on-concrete', 'https://opengameart.org/sites/default/files/metal_steps_48k24b.7z', 'Metal footsteps on concrete', 'Thimras', 'CC0 1.0'),
  oga_impact:         OGA('impact', 'https://opengameart.org/sites/default/files/qubodupImpact.7z', 'Impact', 'qubodup', 'CC0 1.0'),
  oga_breath_tired:   OGA('breathing-tired', 'https://opengameart.org/sites/default/files/breathing%20tired.wav', 'Breathing Tired', 'mikeask', 'CC0 1.0'),
  oga_equip_clicks:   OGA('equipment-clicks-ii', 'https://opengameart.org/sites/default/files/equipmentclicks.wav', 'Equipment Clicks II', 'LFA', 'CC0 1.0'),
  oga_equip_clicks3:  OGA('equipment-clicks-iii', 'https://opengameart.org/sites/default/files/equipment_clicks3.wav', 'equipment clicks III', 'LFA', 'CC0 1.0'),
  oga_rifle_reload:   OGA('gun-reload-sounds', 'https://opengameart.org/sites/default/files/assaultriflereload1_0.wav', 'Gun reload sounds (assault rifle reload)', 'SpringySpringo', 'CC0 1.0'),
  oga_gun_reload:     OGA('gun-reload-sounds', 'https://opengameart.org/sites/default/files/gunreload1.wav', 'Gun reload sounds (gun reload)', 'SpringySpringo', 'CC0 1.0'),
  oga_shotgun_cock:   OGA('gun-reload-sounds', 'https://opengameart.org/sites/default/files/shotguncock_0.wav', 'Gun reload sounds (shotgun cock)', 'SpringySpringo', 'CC0 1.0'),
  oga_shotgun_sounds: OGA('shotgun-reload-sound-effects', 'https://opengameart.org/sites/default/files/shotgunsounds.zip', 'Shotgun Reload Sound effects', 'zer0_sol', 'CC0 1.0'),
  oga_map:            OGA('opening-and-closing-a-map-sounds', 'https://opengameart.org/sites/default/files/snd_use_map.wav', 'Opening and Closing a Map Sounds', 'Spring Spring', 'CC0 1.0'),
  oga_buttons:        OGA('16-button-clicks', 'https://opengameart.org/sites/default/files/independent_nu_ljudbank-buttons_and_clicks.7z', '16 button clicks (Independent.nu ljudbank)', 'qubodup', 'CC0 1.0'),
  oga_mech_clank:     OGA('mechanical-sounds', 'https://opengameart.org/sites/default/files/clank1.wav', 'Mechanical Sounds (clank1)', 'BMacZero', 'CC0 1.0'),
  oga_mech_rattle:    OGA('mechanical-sounds', 'https://opengameart.org/sites/default/files/rattle1.wav', 'Mechanical Sounds (rattle1)', 'BMacZero', 'CC0 1.0'),
  oga_mech_1:         OGA('mechanical-sounds', 'https://opengameart.org/sites/default/files/mechanical1.wav', 'Mechanical Sounds (mechanical1)', 'BMacZero', 'CC0 1.0'),
  oga_mech_click:     OGA('mechanical-sounds', 'https://opengameart.org/sites/default/files/squeakyclick1.wav', 'Mechanical Sounds (squeakyclick1)', 'BMacZero', 'CC0 1.0'),
  oga_100cc0:         OGA('100-cc0-sfx', 'https://opengameart.org/sites/default/files/100-CC0-SFX_0.zip', '100 CC0 SFX', 'rubberduck', 'CC0 1.0'),
  bsb_ratchet_large:  BSB('0795', 'Large ratchet'),
  bsb_metal_door_creak: BSB('0616', 'Creaking metallic door'),
  // round 4 (consume / bandage / sleep actions)
  bsb_spoon_mug:      BSB('0411', 'Spoon in a mug empty'),
  bsb_cloth_tear:     BSB('0013', 'Cloth'),
  bsb_bottle_caps:    BSB('1392', 'Bottle Caps'),
  bsb_sigh_nose:      BSB('1404', 'Sigh by the nose'),
  bsb_sigh_mouth:     BSB('1405', 'Sigh by the Mouth'),
  bsb_spring_large:   BSB('0206', 'Large spring'),
  wm_ketchup_bottle:  WM('File:Ketchup bottle opening and closing screw top.ogg', 'stephan', 'Public domain'),
  wm_yawn_1:          WM('File:Yawning 1.ogg', 'ezwa', 'Public domain'),
  wm_yawn_2:          WM('File:Yawning 2.ogg', 'ezwa', 'Public domain'),
  wm_pill_shake:      WM('File:Pill bottle shake once (Gravity Sound).wav', 'Gravity Sound', 'CC BY 4.0'),
  // --- Music: Kevin MacLeod (CC BY 4.0) ---
  km_thunder_dreams:  KM('Thunder Dreams'),
  km_heavy_heart:     KM('Heavy Heart'),
  km_static_motion:   KM('Static Motion'),
};

async function commonsUrl(fileTitle) {
  const u = `https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url&titles=${encodeURIComponent(fileTitle)}`;
  const j = await getJSON(u);
  const p = Object.values(j.query.pages)[0];
  return p.imageinfo[0].url;
}

/** Fetches a source; returns the path of the raw file (or extracted dir for archives). */
export async function fetchSource(key) {
  const s = SOURCES[key];
  if (!s) throw new Error('unknown source ' + key);
  let file;
  if (s.commons) {
    const dir = path.join(RAW, key);
    const existing = fs.existsSync(dir) && fs.readdirSync(dir).find(f => !f.startsWith('.'));
    if (existing) return path.join(dir, existing);
    const url = await commonsUrl(s.commons);
    await new Promise(r => setTimeout(r, 1200)); // be gentle with Commons
    file = await download(url, key);
  } else {
    try { file = await download(s.url, key, s.file); }
    catch (e) {
      if (!s.alts) throw e;
      let ok = false;
      for (const [ext, u] of s.alts) {
        try { file = await download(u, key, `${s.bsbId}.${ext}`); ok = true; break; } catch {}
      }
      if (!ok) throw e;
    }
  }
  if (/\.(7z|zip)$/i.test(file)) {
    const x = path.join(path.dirname(file), 'x');
    if (!fs.existsSync(x)) {
      fs.mkdirSync(x, { recursive: true });
      const { spawnSync } = await import('node:child_process');
      const tar = process.platform === 'win32' ? 'C:\\Windows\\System32\\tar.exe' : 'bsdtar';
      const r = spawnSync(tar, ['-xf', file, '-C', x]);
      if (r.status !== 0) throw new Error('extract failed ' + file);
    }
    return x;
  }
  return file;
}

if (process.argv[1]?.endsWith('sources.mjs')) {
  for (const k of Object.keys(SOURCES)) {
    try { const f = await fetchSource(k); console.log('ok', k, '->', path.relative(RAW, f)); }
    catch (e) { console.error('FAIL', k, e.message); }
  }
}
