# BUNKER: ZIUA ZERO

Joc 3D first-person de supraviețuire post-nucleară pentru Windows, făcut în **Godot 4.7** (Forward+, Jolt Physics).

> 14 octombrie 2031. Sirenele pornesc. Ai mai puțin de un minut ca să ajungi la Obiectivul 17, adăpostul uitat de sub uzina Electromaș, și să închizi ușa blindată înainte să sosească unda de șoc. Apoi trebuie să supraviețuiești.

Designul complet (povestea, mecanicile, planul de dezvoltare) e în [docs/GDD.md](docs/GDD.md).

## Cum pornești jocul

- **Din editor:** deschide proiectul în Godot 4.7.2 și apasă F5.
- **Build:** `build/BunkerZiuaZero.exe` este un singur fișier, cu toate resursele incluse.
- **Ca să refaci build-ul:**
  ```
  Godot_v4.7.2-stable_win64.exe --headless --path . --export-release "Windows Desktop" build/BunkerZiuaZero.exe
  ```

## Ce conține versiunea 0.1 (vertical slice)

| Sistem | Stare |
|---|---|
| Meniu principal 3D (ușa blindată, praf, lumină care pâlpâie), setări, credite | ✅ |
| Intro jucabil: stația de autobuz → alertă → sirene → bliț → ciuperca nucleară → zidul de praf al undei de șoc → fuga spre buncăr → închiderea ușii (sau moartea) | ✅ |
| Buncăr cu 7 camere (2 prăbușite, se deschid prin săpat), lumini legate de energie | ✅ |
| Supraviețuire: sănătate, hrană, apă, energie, radiație; timp de joc (1 oră = 1 min) | ✅ |
| Sisteme: generator diesel (combustibil), baterii, filtrare aer, rezervor de apă, purificator | ✅ |
| Agricultură: roșii, salată, cartofi, ciuperci; udat, lumină, uscare | ✅ |
| Fabricare: 10 rețete la bancul de lucru | ✅ |
| Construcție: 10 obiecte, hologramă verde/roșie, rotire, plasare liberă | ✅ |
| Radio: 8 transmisiuni care deblochează locații | ✅ |
| Raiduri pe suprafață: 5 locații procedurale, containere cu pradă, zone radioactive, Geiger, filtre de mască, mutanți cu AI, topor și pistol | ✅ |
| Somn, salvare/încărcare automată, moarte → reîncărcare | ✅ |
| **v0.2** — HUD profesional (busolă cu markere, viață segmentată + stamină, iconițe de stare, armă/muniție, dozimetru + inel filtru, sisteme buncăr, hitmarker, indicatori de daune, HUD dinamic) | ✅ |
| **v0.2** — Inventar STALKER-style cu iconițe randate din modelele 3D, rucsac + depozit, echipament, greutate maximă | ✅ |
| **v0.2** — Setări „AAA”: preseturi Scăzut→Cinematic (auto-detectare GPU), FSR 1/2.2, SMAA/TAA/MSAA, SDFGI/SSIL, SSAO, SSR, ceață volumetrică, umbre, LOD, VSync, limită FPS, luminozitate, contrast, efecte post | ✅ |
| **v0.2** — Logică: stamină, sângerare, supraîncărcare, încărcare automată echipament înainte de raid, descărcare pradă după | ✅ |
| **v0.2** — Inamici: mutant, zombi în costum (aură radioactivă), câini mutanți în haită, jefuitori cu pușcă (distanță, strafe, pradă) | ✅ |
| **v0.3** — Arme profesionale: viewmodel procedural (echipare, balans, legănare, respirație, ADS cu zoom, recul pe arc, reîncărcare pe faze cu încărcător animat, sprint, retragere lângă pereți), AKM automat, pușcă cu două țevi, flacără, tuburi, trasoare, găuri de glonț, praf/scântei/sânge | ✅ |
| **v0.3** — Arbore de dezvoltare cu 18 îmbunătățiri în 6 ramuri, cu efecte reale (motorină, filtre, puț, solar, hidroponie, bucătărie, strung, rucsac, infirmerie, apărare, antenă, hărți, costum) | ✅ |
| **v0.3** — Construcție: lipire automată de perete, demontare cu 50% rambursare (X), mobilier cu confort, aragaz + rețete gătite, raft hidroponic, animații la plasare | ✅ |
| **v0.3** — Hărți: harta PDA a regiunii (râu, drumuri, epicentru, zonă radioactivă, rute, detalii) + harta locală (M) randată de sus din scena reală; locație nouă: Metroul „Piața Unirii” | ✅ |
| **v0.2** — Ruine din piese modulare reale, hale industriale, gard PO-2, turn de apă, ecran de încărcare cu preîncărcare, Shader Baker, texturi optimizate | ✅ |
| **v0.4** — Brațe first-person animate (rig-uri FPS reale): pistol 9 mm, Kalașnikov AK-74M, Saiga-12, topor de pompier. Idle / mers / alergare / foc / reîncărcare rapidă și completă / scoatere armă, mișcarea camerei din animație, ochire pe cătare calculată din geometria armei, câmp vizual propriu al armei | ✅ |
| **v0.4** — Inamici: mutant nou (zombi detaliat) cu animații transferate între schelete (retargeting), țipăt la reperare, reacții la impact pe oase, mers sincronizat cu viteza, moarte cu ragdoll fizic împins de glonț (câinii: animație de moarte) | ✅ |
| **v0.4** — Suprafață cu relief real: dealuri, cratere de bombă, drumuri asfaltate, platforme sub ruine, iarbă uscată animată de vânt, bolovani, trunchiuri căzute, cioturi; totul așezat pe teren | ✅ |
| **v0.4** — Ieșirea 4 a rețelei de adăposturi: portal de beton îngropat în deal, ușă blindată animată, ziduri de sprijin, copertină, lămpi cu sodiu, girofar, guri de aerisire, antenă | ✅ |

## Comenzi

`WASD` mișcare · `Shift` sprint · `Ctrl/C` ghemuit · `Space` săritură · `E` (ține apăsat) interacțiune · `Tab` inventar · `B` construcție · `U` dezvoltare · `M` harta zonei · `X` demontare · `R` reîncărcare / rotire · `F` lanternă · `1/2/3/4` topor / pistol / AK-74M / Saiga-12 · rotița schimbă arma · `click stânga` foc / atac / plasare · `click dreapta` ochire · `H` bandaj · `Esc` pauză.

## Structura proiectului

```
scenes/             scenele (doar rădăcina, conținutul e construit din cod)
scripts/core/       autoload-uri: Settings, Assets, Audio, State, Game (+ Synth, SelfTest)
scripts/data/       ItemDB: obiecte, rețete, construcții, culturi, locații, radio
scripts/levels/     main_menu, intro, bunker, expedition (+ LevelBase)
scripts/player/     controller first-person
scripts/npc/        inamici
scripts/world/      Interactable, Geo (helperi de geometrie), Planter, DigSite, LootContainer
scripts/ui/         HUD și toate panourile
scripts/vfx/        explozia nucleară procedurală
shaders/            post-procesare, pereți de buncăr, nor nuclear, zidul undei de șoc
assets/models/      67 de modele GLB (Sketchfab CC-BY/CC0 + Poly Haven CC0), normalizate la scară reală
assets/textures/    15 seturi PBR 2K (Poly Haven / ambientCG, CC0)
assets/hdri/        3 ceruri HDRI (Poly Haven, CC0)
assets/audio/       44 de sunete și 3 piese muzicale (CC0 / PD / CC-BY)
tools/assets/       pipeline Node pentru modele (căutare, contact sheets, descărcare, optimizare)
tools/media/        pipeline Node pentru texturi, HDRI și audio
```

Cheia API Sketchfab e în `.env`, care e ignorat de git. Nu o publica.

## Pipeline-ul de asset-uri

- **Modele:** vezi [tools/assets/README.md](tools/assets/README.md). Pe scurt:
  - `node search.mjs <id>` caută și face contact sheet.
  - `node fetch.mjs <id> <uid>` descarcă, optimizează și normalizează modelul.
  - Totul e înregistrat în `picks.json`.
- **Texturi, HDRI și sunete:** vezi [tools/media/README.md](tools/media/README.md).
- **Licențe:** doar CC0 / CC-BY / CC-BY-SA. Creditele sunt în `assets/models/CREDITS.md` și `assets/CREDITS_media.md` și apar în joc la **Credite**.

## Flaguri de debug

Se dau după `--`:

```
--scene=intro|bunker|surface|menu   pornește direct o scenă
--lit                               (bunker) generator pornit, tutorial terminat
--loc=market --day=4                (surface) locația și ziua
--skip=36                           (intro) sare în timeline
--pose=x,y,z,yaw[,pitch]            poziția jucătorului
--shots=2,5 --shotdir=DIR --quit=6  capturi de ecran automate
--nolook --windowed                 nu capturează mouse-ul / fereastră
--selftest                          test automat al buclei de joc (bunker → raid → înapoi)
--give=all                          5 bucăți din fiecare obiect
--panel=inventory|settings|craft    deschide un panou (capturi)
--spawn=bandit|dog|hazmat|mutant    (surface) inamic în fața jucătorului
--goto=surface                      testează ecranul de încărcare
--weapon=rifle --ads                (surface) armă în mână (+120 cartușe), ochire permanentă
--act=fire@6,reload@7,kill@8,fps@9  acțiuni programate (fire, reload, swing, kill, hit, walk, sprint, stop, fps)
--swingt=0.2                        îngheață balansul toporului la momentul dat (capturi)
--trace                             jurnal detaliat (arme, ragdoll, ușă)
```

Unelte de dezvoltare: `scripts/debug/fp_probe.gd` (randează un rig FPS pe animații), `scripts/debug/matinfo.gd` (materialele unui model),
`tools/assets/fpsfix.mjs` (texturi rig-uri FPS: recolorare + import VRAM/mipmaps), `tools/assets/montage.mjs` (planșe de capturi).
#   t h e - b u n k e r  
 