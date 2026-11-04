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
| **v0.5** — Amenajarea buncărului: orice mobilă (inclusiv cea inițială) se mută cu **G** — hologramă verde/roșie, amprentă pe podea, aliniere la grilă și la perete (T), rotire liberă / 90°, obiectele de pe masă se mută cu ea, verificări de spațiu și de treceri libere | ✅ |
| **v0.5** — 9 corpuri de iluminat pe podea, perete și tavan (lampă industrială, tub fluorescent, aplică, lampă etanșă, girofar, ghirlandă, lampadar, proiector pe trepied, felinar cu baterie); fiecare lumină se reglează cu **E**: pornit/oprit, 8 culori, intensitate, umbre; consumă motorină | ✅ |
| **v0.5** — Ziua Zero într-un oraș viu: pornești în stația de autobuz; în jur rândul de magazine cu firme (pâine, farmacie, flori, frizerie, cafenea), chioșcuri, parcarea din fața blocurilor, fire de troleibuz, trecere de pietoni cu semafoare care funcționează, panouri publicitare. Mașini în trafic (păstrează distanța, opresc la roșu și la pietoni, claxonează), oameni care așteaptă autobuzul, merg la uzină, traversează pe verde, porumbei. La alertă toți se opresc, la sirenă fug spre blocuri și mașinile intră în panică; la bliț motoarele și semafoarele mor. Fiecare om și fiecare mașină are alte culori | ✅ |
| **v0.5** — Teritoriul uzinei Electromaș: poartă cu punct de control, barieră și poartă glisantă; aleea centrală cu peluze, copaci și felinare; clădirea administrativă cu litere pe acoperiș, steaguri, straturi de flori și panoul de onoare; cantina, atelierul auto, hale numerotate pe două drumuri interne, depozite cu rampă de încărcare și camioane, depozit în aer liber (containere, țevi, plăci, tamburi de cablu), centrala termică sub coș, conducte de abur pe suporturi (ridicate peste alee), post de transformare, calea ferată uzinală cu vagoane, zid împrejmuitor; adăpostul în piațeta lui, cu indicatoare de la poartă; muncitori la lucru care fug în hale la sirenă | ✅ |
| **v0.5** — Personajul urcă singur borduri, praguri și trepte de până la 32 cm | ✅ |
| **v0.5** — Orașe adevărate la suprafață: străzi cu loturi, case de sat cu curte, gard, fântână și acoperiș de tablă, blocuri, magazine, garaje și câte o clădire principală pe locație (supermarketul „Unic”, spitalul, poliția, hala Electromaș, metroul, cazarma). În toate se intră: camere cu uși și ferestre, mobilier pe tip de cameră | ✅ |
| **v0.5** — Prada stă doar în mobilier: frigidere, bufete, șifoniere, noptiere, genți, dulăpioare cu medicamente, rafturi, lăzi, portbagaje — fiecare cu obiectele potrivite; ce ai cercetat rămâne gol câteva zile. Orașul e același la fiecare vizită (prada și inamicii se schimbă) și rulează de ~10× mai repede decât varianta veche | ✅ |
| **v0.4** — Ieșirea 4 a rețelei de adăposturi: portal de beton îngropat în deal, ușă blindată animată, ziduri de sprijin, copertină, lămpi cu sodiu, girofar, guri de aerisire, antenă | ✅ |
| **v0.6** — Arme corectate: pistolul ochește drept (cătările calculate de pe culisă), toporul stă în pumn cu tăișul înainte, lovitură nouă din umăr (diagonală, apoi laterală în combo), oprire la impact și ricoșeu din pereți | ✅ |
| **v0.6** — Mâini first-person peste tot: în buncăr și pe suprafață fără armă vezi mâna, care se întinde când cauți sau folosești ceva; somnul culcă camera pe pernă; jefuitorii trag cu flacără la gura țevii, trasor și recul în trunchi | ✅ |
| **v0.6** — Corbii: după amenințarea de la radio ai 3 zile să lași provizii în lada de la ecluză; altfel atacă noaptea — barele de la ușă, alarma, sacii de nisip și armureria decid dacă ușa ține (pradă de la jefuitori) sau pierzi din depozit și motorină; răspunsul lor la radio și ambuscada de la ieșire | ✅ |
| **v0.6** — Moș Petru: după transmisiunea lui, din panoul radio faci schimb de marfă (fier vechi → motorină, conserve → trusă medicală, cartușe → Antirad, electronice → filtre, apă → praf de pușcă, pânză → semințe) | ✅ |
| **v0.6** — Optimizare pentru plăci integrate: blur-ul de ecran doar când e deschis un panou, bloom în 3 trepte, buget de umbre (doar lămpile de lângă tine), lumini mai concentrate, umbra soarelui într-o singură hartă pe „Scăzut”, teren cu jumătate din texturi pe „Scăzut”, geometria orașelor tăiată pe celule de 40 m, pietoni ascunși fără animație, cadavre curățate, greutatea inventarului în cache. Pe Intel UHD 630: 22 → ~29 FPS la 77% rezoluție, ~33 la 67% | ✅ |
| **v0.6** — Modelele grele de pe suprafață (clădirea ruinată 170k triunghiuri, piatra mică 6k, gardul de beton 5,6k, mașini, copaci, bolovani) se randează din LOD-urile generate la import: lista `Assets.SLIM` păstrează 10–40% din triunghiuri, calculat o dată la încărcare (~0,7 s); 320k → 62k triunghiuri unice la uzină. Proiectul a scăpat de 177 de JPG-uri orfane (14 MB) din rădăcină | ✅ |
| **v0.6** — Inventar cu drag & drop: tragi obiectele cu mausul între rucsac, depozit și sloturile de echipament (pe slot sau pe fila RUCSAC / DEPOZIT); tot teancul odată, cu Shift câte o bucată; selecția nu mai reconstruiește grila | ✅ |
| **v0.6** — Interioare care arată locuite: fiecare cameră are tavan propriu cu cornișă, plinte, bandă de vopsea cu șipcă (faianță în bucătării, băi și saloane), lampă cu abajur sau tuburi fluorescente (stinse), perdele cu galerie și calorifere sub ferestre, întrerupătoare lângă uși, covoare, tablouri, ceas oprit, hârtii, sticle, conserve, cutii de carton, pantofi în hol, cioburi sub ferestrele sparte, tencuială căzută și scaune răsturnate; totul în batch-ul interior, fără draw call-uri în plus | ✅ |
| **v0.6** — Mobilierul se deschide când îl cauți: ușile de frigider, dulap, bufet, vestiar și dulăpior se rotesc, sertarele noptierei, comodei, biroului și tejghelei ies, capacele lăzilor se ridică; rămân deschise cât e containerul gol | ✅ |
| **v0.6** — HUD: caseta armei arată silueta armei randată din model, încărcătorul desenat cartuș cu cartuș, cifra care „sare” la fiecare foc și bara de reîncărcare | ✅ |
| **v0.6** — Texturi dedicate pentru interioare (12 seturi Poly Haven CC0, 2K): tapet decrepit în case și blocuri, tencuială vopsită în instituții, vopsea cojită în ruine, parchet în blocuri, dușumea uzată în case, linoleum în spital / poliție / birouri, faianță murdară în bucătării și băi, gresie, tavan tencuit, covor murdar, in pentru canapele și perdele, lemn de bucătărie pentru mobilier | ✅ |
| **v0.6** — Mobilier real în loc de cutii: frigider, canapea, rafturi metalice, vestiar, banc de lucru, lăzi de lemn și militare sunt modelele 3D, păstrează prada și intră în lista de slăbire a geometriei | ✅ |
| **v0.6** — Supermarket cu produse adevărate pe rafturi: conserve cu etichetă, cartoane, sticle cu dop, pungi, în culori spălăcite, cu o parte căzute pe jos; igrasie la baza pereților, dâre sub ferestre și mucegai în colțurile de sus ale băilor, bucătăriilor și ruinelor (straturi translucide în batch, fără decal-uri) | ✅ |
| **v0.6** — Catalogul de modele are pat, șifonier, masă de lemn, cadă și chiuvetă alese de pe Sketchfab (`tools/assets/picks.json`); se descarcă cu `node fetch.mjs --all` când există `SKETCHFAB_API_TOKEN` în `.env`, iar clădirile le folosesc automat în locul cutiilor (`"model"` + `"long"` în `Building.FURN`) | ✅ |
| **v0.6** — Reparat: pușca, Saiga și munițiile lor intră în echipamentul automat de raid; moartea prin radiații/aer are motivul ei; „Membrana de osmoză” dublează purificatorul; o singură regulă de greutate pe suprafață (rucsacul militar contează); tuburile cad la fel la orice FPS; condensatorul și puțul spun ce fac | ✅ |
| **v0.7** — Texturi reale peste tot (Poly Haven CC0, 2K): tencuială albă / galbenă / albastră / uzată pe case, panouri de beton pe blocuri și hale, tablă ondulată și țiglă pe acoperișuri, tâmplărie vopsită, dușumea veche; buncărul are beton turnat adevărat pe pereți, pardoseală de beton uzat și tavan de beton brut (nu mai arată a lemn); portalul de la ieșire și săpăturile din beton | ✅ |
| **v0.7** — Buncărul echipat ca unul real: trasee de cabluri pe console, tubulatură de ventilație sub tavan, detector de fum, cutii de distribuție, cameră de supraveghere la ecluză; în spatele ușii blindate o galerie de ieșire luminată cu tuburi fluorescente, cabluri și indicator „GALERIA → IEȘIRILE 1–6” | ✅ |
| **v0.7** — Case mobilate cu modele 3D (Sketchfab CC-BY): șifonier vechi, pat metalic, noptiere, comodă, dulap de bucătărie, aragaz, bibliotecă cu cărți, televizor vechi pe suport, sobă de teracotă, birou, WC, valiză, rucsac, canistră, vitrină frigorifică, strung; scaune la mese, ceainic / oală / cană pe blat, casă de marcat în magazin, candelabru și lămpi suspendate, ceasuri, tablouri și oglinzi pe pereți (niciodată în dreptul ușilor), plante, lăzi; dulapul suspendat din bucătărie are uși și mânere | ✅ |
| **v0.7** — Lumină în interioare: fiecare clădire mobilată are sondă de reflexie și o lumină de umplere pe cameră (SDFGI ignoră ambientul sondei), stinsă cu distanța — camerele nu mai sunt negre | ✅ |
| **v0.7** — Iarbă adevărată: smocuri de iarbă scanate (MultiMesh, shader cu vânt mai puternic la vârfuri, translucență, fără umbre), uscată pe teren și verde pe peluzele uzinei, densitate după setarea de vegetație | ✅ |
| **v0.7** — Ziua Zero: mașinile din trafic și cele parcate sunt Volga și Lada curate, vopsite în culori diferite (nu mai sunt epave ruginite); pietonii sunt oameni realiști (bărbat cu palton, muncitor, femeie) cu animații retargetate de mers / alergare / așteptare | ✅ |
| **v0.7** — Obiecte în mână ca în DayZ: mâncarea, apa, bandajul și pastilele se iau în mână („Ia în mână” din inventar, **H** pentru bandaj) și se folosesc **ținând apăsat click stânga** cât ai nevoie — înghițitură cu înghițitură, lingură cu lingură, tură cu tură de bandaj; **click dreapta** le pune deoparte. Ce ai început rămâne început (sticlă băută pe jumătate, conservă cu câteva linguri rămase, salvat în joc). Ambele brațe sunt puse prin IK pe două oase (umăr–cot–încheietură, cu răsucirea antebrațului) pe cadre-cheie: sticla de 0,5 L transparentă dusă la gură cu capul pe spate, conserva ținută în stânga și lingura în dreapta, castronul de supă, roșia / cartoful / pâinea mușcate (se micșorează), pastilele duse la gură, bandajul înfășurat pe antebrațul stâng (tifonul crește tură cu tură). Caseta din HUD arată obiectul, cât a rămas și tastele | ✅ |
| **v0.8** — Strânsoarea degetelor făcută în Blender (`tools/blender/grip_fit.py`): rigul brațelor și fiecare obiect (sticla, conserva, lingura, rola de bandaj, roșia, cartoful, pâinea) se pun în Blender exact ca în joc (potrivire pe articulații, eroare 0), degetele se deschid / închid falangă cu falangă după grosimea obiectului și obiectul se așază în palmă; rezultatul (`assets/data/hand_grips.json`) pune degetele în jurul obiectului peste IK-ul brațelor | ✅ |
| **v0.8** — Reparat: după băut puteau rămâne pe ecran „plăci” mari / linii — antebrațul se răsucea peste limita anatomică (până la 116°) și pielea se strângea într-o panglică; răsucirea e acum limitată (±40°, restul la încheietură, sub manșetă) și umerii stau anatomic (mai jos), deci brațul nu mai trece prin fața camerei | ✅ |
| **v0.7** — Sunete noi (CC0 / domeniu public, pastilele CC BY 4.0): înghițitură, mușcătură, mestecat, lingură în conservă, rupere și înfășurare de bandaj, pastile, răsuflare după băut, arcurile patului când te culci și când te ridici, căscat la trezire | ✅ |
| **v0.7** — Intrarea în buncăr de la suprafață: ce părea „o bucată de lemn” după ușă era terenul (un perete de pământ cu textura întinsă); acum ușa se deschide spre un vestibul de beton luminat, cu „↓ OBIECTIVUL 17 ↓”, balustrade și scări care coboară la ușa interioară a ecluzei | ✅ |
| **v0.7** — Reparat: ambuscada Corbilor apare pe hartă, în fața ieșirii, pe teren liber; mâna nu mai e neagră în lumina zilei (lumină de umplere doar pentru viewmodel); texturile se încarcă cu compresie BC7/BC5 și mipmaps — nivelul se încarcă în ~3,5 s în loc de 15 s; mașinile și modelele cu multe piese sunt unite într-un singur mesh pe material (intro: 19 500 → 8 300 draw call-uri, ~100 FPS la 1080p Ultra pe RTX 3080) | ✅ |

## Comenzi

`WASD` mișcare · `Shift` sprint · `Ctrl/C` ghemuit · `Space` săritură · `E` (ține apăsat) interacțiune · `Tab` inventar · `B` construcție · `G` mută mobila / lumina · `T` aliniere la plasare · `U` dezvoltare · `M` harta zonei · `X` demontare · `R` reîncărcare / rotire · `F` lanternă · `1/2/3/4` topor / pistol / AK-74M / Saiga-12 · rotița schimbă arma · `click stânga` foc / atac / plasare · `click dreapta` ochire · `H` bandaj · `Esc` pauză.

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
assets/textures/    27 seturi PBR 2K (Poly Haven / ambientCG, CC0)
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
                                    (orice rulare cu --scene sau --selftest salvează în user://debug_slot.json, nu peste jocul tău)
--continue                          încarcă salvarea reală (ca „Continuă” din meniu) doar pentru capturi; nu scrie înapoi în ea
--give=all                          5 bucăți din fiecare obiect
--panel=inventory|settings|craft    deschide un panou (capturi)
--spawn=bandit|dog|hazmat|mutant    (surface) inamic în fața jucătorului
--goto=surface                      testează ecranul de încărcare
--weapon=rifle --ads                (surface) armă în mână (+120 cartușe), ochire permanentă
--act=fire@6,reload@7,kill@8,fps@9  acțiuni programate (fire, reload, swing, kill, hit, walk, sprint, stop, fps)
--swingt=0.2                        îngheață balansul toporului la momentul dat (capturi)
--swingseq=0,0.12,0.25 [--swingside] foaie de capturi a loviturii de topor (a doua: lovitura laterală)
--sightdbg                          marchează cătările detectate (verde = față, magenta = spate)
--act=fps@9                         acum tipărește și timpii CPU/GPU, luminile cu umbre; alte acțiuni: reach, hands, sleep (--sleeph=16, pe cel mai apropiat pat)
--act=drink@3,use@5 --usehold=2     ia în mână (drink, eat, soup, bite, bread, potato, pills, bandage), apoi „ține click stânga” 2 s; putaway@t pune deoparte
--hsfreeze=loop:0.3                 îngheață mâinile în starea / momentul dat (draw, idle, start, loop, finish, end) pentru capturi
--posedbg=r:x,y,z:rx,ry,rz:spin     înlocuiește poza mâinii drepte (și/sau /l:... stânga) în idle/loop — pentru reglaje
--portalopen --portalnight          (surface) ușa buncărului deschisă / fără soare, pentru verificarea intrării
--outside=N                         (surface) în fața clădirii N, cu fața spre ea
--room=bedroom|kitchen|living|bath [--nth=K]  (surface) în mijlocul unei camere de acel tip
--noshadow=all|sun|omni             (cu fps) oprește umbrele ca să măsori costul lor
--off=post,glow,sky,lights,world,…  (cu fps) bisecție a costului GPU: post, glow, glowlite, sky, fog, aa, deband, fsr, half, full, lights, world, grass, terrain, props, batches, range, ortho, lod8, meshstats, triplanar
--flags=corbii:threat,corbii_deadline:17  setează flaguri de joc la pornire (testul raidului Corbilor)
--slowfx                            flacăra și trasoarele NPC-urilor durează 1,5 s (capturi)
--panel=inventory --act=dragtest@9  test automat de drag & drop în inventar (depozit → echipament → depozit), tipărește numărătorile
--enter=2 --act=facecont@9,openall@10   (surface) te pune în fața primului container cu părți mobile, apoi deschide toate containerele
--face=Frigider --act=facecont@9        (surface) te pune în fața primului container al cărui titlu începe așa
--trace                             jurnal detaliat (arme, ragdoll, ușă)
--showcase=lights                   (bunker) toate tipurile de lumini în sala principală
--build=TYPE --move=f:hall_table    (bunker) pornește plasarea unei construcții / mutarea unui obiect
--panel=light                       (bunker) setările celei mai apropiate lumini
--enter=N --torch                   (surface) în ușa clădirii N (0 = clădirea principală), cu lanternă
--cam=x,y,z,yaw,pitch               cameră fixă pentru capturi (ex. vederea de sus a orașului)
```

Unelte de dezvoltare: `scripts/debug/fp_probe.gd` (randează un rig FPS pe animații), `scripts/debug/matinfo.gd` (materialele unui model),
`tools/assets/fpsfix.mjs` (texturi rig-uri FPS: recolorare + import VRAM/mipmaps), `tools/assets/montage.mjs` (planșe de capturi),
`tools/assets/texfix.mjs` (setează importul BC7/BC5 + mipmaps pentru texturile tuturor modelelor și seturilor — rulează-l după orice descărcare, apoi `--headless --import`),
`tools/assets/joinmesh.mjs <id…>` (unește piesele statice ale unui model pe material: mai puține draw call-uri),
`tools/blender/grip_fit.py` (Blender 5.2: `blender -b -P tools/blender/grip_fit.py -- assets/models/fps_pistol/fps_pistol.glb <dump.json> assets/models <out.json> <renders>`; dump-ul vine din joc cu `--dumpgrips=<dump.json>`; tabelul de deschidere a degetelor e în script; copiază rezultatul în `assets/data/hand_grips.json`),
`scripts/debug/showroom.gd` (`godot --path . -s res://scripts/debug/showroom.gd -- --ids=a,b,c --out=x.png` — modele în rând, fața spre +Z, pentru verificarea orientării).
