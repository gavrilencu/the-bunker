# Bunker — 3D model pipeline

Finds, downloads, optimizes and normalizes the 3D models listed in `catalog.json`.

Sources: **Sketchfab** (Data API v3; token `SKETCHFAB_API_TOKEN` in the project `.env`; licenses CC0 / CC-BY / CC-BY-SA only)
and **Poly Haven** (CC0). Output goes to `assets/models/<id>/<id>.glb` + `assets/models/manifest.json` + `assets/models/CREDITS.md`.

## Contract (what the game can rely on)
- One GLB per catalog id at `res://assets/models/<id>/<id>.glb`.
- Real-world scale in meters: the `fit` dimension of the catalog entry (`h` = height, `l` = longest of X/Z, `m` = max axis) equals the target.
- Pivot at bottom-center: min Y = 0, X/Z centered. The fix is a parent node named after the id (uniform scale + translation); an optional `orient_fix` node holds rotation fixes.
- Textures resized to the entry's `tex` (opaque PNGs re-encoded as JPEG q88); meshes deduped/welded; no Draco/meshopt (Godot can't read them); lights/cameras stripped.
- Fake transparency fixed: BLEND/MASK materials whose base color is really opaque become OPAQUE, binary cut-outs become MASK (cutoff 0.5); genuine glass stays BLEND (listed in manifest `notes`).
- `manifest.json` per id: title/author/license/source, `faces`, `size_m` (after normalization), `animations` (rigged models), `notes` (footprint axis, alpha materials), optional `parts` + `hinge_hint` (split models, e.g. the vault door).

## Commands (run inside `tools/assets/`)
```
npm install                                   # once
node search.mjs <id...> | --prio N [--q "custom query"] [--tag t]
                                              # candidates -> .cache/candidates/<id>.json, contact sheets -> .cache/sheets/*.png
node adhoc.mjs <id> <tag> "q1" "q2" ... [--animated]   # wider multi-query search + sheet
node pick.mjs <sheet tag_n> <code...> [--simplify r]   # record sheet codes (e.g. 0f) into picks.json
node fetch.mjs <id> <sketchfabUid | ph:<polyhavenId>> [--keep <nodeRegex>] [--yaw deg] [--rot x,y,z] [--simplify r]
node fetch.mjs --all [--force] [--jobs 3]     # (re)process everything in picks.json
node split.mjs <id> <partA> <partB> <x|y|z> <lt|gt> <value> [--hinge]   # split a normalized model by triangle centroid
node inspect.mjs <id | file>                  # node tree + per-node bounds (to choose --keep)
node yawfind.mjs <glb>                        # yaw that aligns the dominant planar faces to the axes
node validate.mjs                             # re-check every output (fit, pivot, extensions, size)
node stack.mjs out.png a.png b.png ...        # stack contact sheets
node weaponaxis.mjs <id...>                   # estimate barrel axis / grip end (guns) or head end (axe) from geometry
```
`picks.json` is the source of truth for what was chosen (and with which keep/yaw/rot/simplify options), so `node fetch.mjs --all --force`
rebuilds every model from the cached raw downloads (`.cache/raw/<uid>/`, gitignored). Re-run `split.mjs vault_door leaf frame z lt 0.89`
after a forced rebuild of `vault_door` (the hinge hint in the manifest is kept).

Downloads are treated as untrusted data: each lives in its own `.cache/raw/<uid>/` folder and is only parsed as glTF, never executed.
