# Media pipeline (textures, HDRIs, audio)

Fills `tools/media/catalog.json` into:

- `assets/textures/<id>/{albedo,normal,roughness,ao,height[,metallic]}.jpg` (2K, OpenGL normals) + `manifest.json`
- `assets/hdri/<id>.hdr` (Poly Haven "pure sky") + `manifest.json`
- `assets/audio/<id>.ogg` (Vorbis q5, 44.1 kHz) + `manifest.json`
- `assets/CREDITS_media.md` (authors, licenses, required attributions)

## Run

```sh
cd tools/media
npm install            # sharp + ffmpeg-static
node textures.mjs      # [id ...] to rebuild specific ids
node hdri.mjs
node audio.mjs         # [id ...]; fetches sources on demand into .cache/raw/<source>/
node credits.mjs
```

Re-running is safe: raw downloads are cached in `.cache/raw/` (each source in its own folder), outputs are overwritten, manifests are merged.

## Files

| file | purpose |
|---|---|
| `textures.mjs` | curated Poly Haven / ambientCG picks (`PICKS`), downloads 2K maps, re-encodes to JPG; metallic only for real metals |
| `hdri.mjs` | Poly Haven HDRI picks (4K morning/overcast, 2K sunset) |
| `sources.mjs` | registry of every raw audio recording (BigSoundBank CC0, Wikimedia Commons, OpenGameArt, incompetech) with author/license; `node sources.mjs` prefetches all |
| `audio.mjs` | one recipe per audio id: trims, layers, pitch, EQ, echo, seamless loops (equal-power crossfade), then two-pass `loudnorm` (long sounds: music -16 LUFS, ambience -18/-20 LUFS) or peak normalize (SFX, ≤ -1 dBFS), with a post-encode peak guard |
| `synth.mjs` | procedural layers/sounds (geiger click, UI hover, radio static, sub-boom, rumble, roar, thump, 50 Hz hum, power sweeps) |
| `analyze.mjs` | `node analyze.mjs <file> [bin] [thr]`: duration, peak/RMS, envelope sparkline, onsets (used to pick trim points / footstep slices) |
| `contact.mjs` | thumbnail contact sheets for choosing textures/HDRIs |
| `wmsearch.mjs`, `bsbsearch.mjs`, `oga.mjs` | search helpers for Commons / BigSoundBank / OpenGameArt |

## Notes

- Only CC0 / public domain / CC BY / CC BY-SA sources are used (no NC/ND).
- `explosion_nuclear.ogg` includes a CC BY-SA 4.0 thunder recording, so that file is CC BY-SA 4.0.
- Kenney.nl packs were not used (their download endpoint requires a browser session).
- `tinnitus.ogg` is an extra id (post-blast ear ringing) not listed in the catalog.
- `footstep_concrete.ogg` / `footstep_grass.ogg` are copies of variant `_1` for loaders that ask for the base id.
