# BUNKER: ZIUA ZERO — Game Design Document

> Titlu de lucru. Joc 3D first-person de supraviețuire post-nucleară pentru PC (Windows).
> Motor: Godot 4.7 (Forward+, Jolt Physics). Stil vizual: realist, PBR, atmosferă rece, lumini pâlpâitoare, praf, ceață volumetrică.

---

## 1. Premisa

**14 octombrie 2031, 07:41.** Orașul Vadul Nou, o zi obișnuită de toamnă.

Ești **Alex Moraru**, inginer de întreținere la uzina „Electromaș”. Sub uzină se află un adăpost antiatomic din anii '70, **Obiectivul 17**, uitat de toată lumea, în afară de tine. Îl verifici o dată pe lună și știi codurile.

Aștepți autobuzul când telefoanele încep să țipe în același timp:

> **ALERTĂ NAȚIONALĂ — ATAC NUCLEAR IMINENT. ADĂPOSTIȚI-VĂ IMEDIAT.**

Sirenele pornesc. Ai mai puțin de un minut și jumătate ca să ajungi la Obiectivul 17, să cobori scările și să închizi ușa blindată înainte să ajungă unda de șoc.

Ce urmează după ce ușa se închide e jocul.

## 2. Pilonii jocului

1. **Supraviețuire tensionată.** Foame, sete, oboseală, radiație. Fiecare zi contează.
2. **Buncărul ca personaj.** Un adăpost vechi, pe jumătate prăbușit, pe care îl repari, îl sapi, îl extinzi și îl transformi în casă.
3. **Suprafața ca pericol.** Raiduri scurte și riscante în orașul distrus, cu filtrul de mască pe terminate și un contor Geiger care țăcăne tot mai des.
4. **Povestea prin radio.** Lumea de afară o afli doar prin frecvențele care încă emit: armata rămasă, negustori, jefuitori și un semnal misterios.

## 3. Bucla de joc

```
   ┌───────────── BUNCĂR ─────────────┐
   │ mănânci / bei / dormi            │
   │ întreții generator, aer, apă     │
   │ cultivi plante                   │
   │ fabrici unelte / filtre          │
   │ construiești stații noi          │
   │ sapi camere noi                  │
   │ asculți radioul ──► locații noi  │
   └──────────────┬───────────────────┘
                  │ ușa blindată (mască + filtre)
   ┌──────────────▼───────────────────┐
   │ RAID PE SUPRAFAȚĂ                │
   │ jefuiești containere, mașini,    │
   │ rafturi; eviți zonele radioactive│
   │ lupți cu mutanți / jefuitori     │
   │ te întorci înainte să se termine │
   │ filtrul sau să iei doza fatală   │
   └──────────────┬───────────────────┘
                  └──► înapoi în buncăr cu prada
```

## 4. Actul I: Ziua Zero (intro jucabil)

| Timp | Eveniment |
|---|---|
| 0:00 | Stația de autobuz. Dimineață, păsări, trafic îndepărtat. |
| 0:03 | Alertă pe telefon (UI). Pornește sirena. Obiectiv: *Ajunge la Obiectivul 17* (~130 m). |
| 0:45 | **Blițul.** Lumină albă orbitoare dinspre centrul orașului (≈5 km). Se ridică mingea de foc și ciuperca. |
| 0:45–1:00 | Zidul de praf al undei de șoc se apropie vizibil. Sunetul exploziei vine odată cu ea (viteza sunetului). |
| 1:00 | Unda de șoc lovește. Dacă ușa nu e închisă, mori și reiei. |
| — | Ușa se închide (ții apăsat **E**): un clanc greu, apoi vibrații, praf din tavan, luminile pâlpâie, beznă. |

Text final: *„Ziua 1. Lumea de deasupra nu mai există.”*

## 5. Buncărul — Obiectivul 17

Proiectat pentru 50 de oameni, abandonat de 30 de ani.

| Cameră | Stare inițială | Funcție |
|---|---|---|
| Ecluza (sas) | funcțională | ușa blindată, ieșirea la suprafață, punct de apărare |
| Sala principală | funcțională | paturi, masă, radio, bancul de lucru |
| Depozitul | funcțional | rafturi cu provizii vechi (conserve, apă, combustibil) |
| Camera tehnică | parțial | generator diesel, panou electric, rezervor de apă, purificator, filtrul de aer |
| Sera | goală | jardiniere și lămpi de creștere; aici se cultivă |
| Atelierul (Secțiunea B) | **prăbușit** | trebuie săpat: spațiu de construcție și provizii sovietice |
| Infirmeria (Secțiunea C) | **prăbușit** | trebuie săpată: medicamente și pat medical |

### Sisteme ale buncărului

- **Energie.** Generatorul diesel consumă ~0,3 L/oră. Lumina, filtrul de aer, purificatorul, lămpile de creștere și radioul consumă din buget. Fără energie rămân doar lămpile roșii de urgență.
- **Aer.** Filtrul se uzează ~4%/zi. Sub 30% scade calitatea aerului, crește radiația din interior și pierzi viață. Filtrul se înlocuiește cu un *Filtru de aer* (fabricat sau găsit).
- **Apă.** Rezervorul pornește cu 120 L. Purificatorul transformă *apa murdară* adusă de afară în apă potabilă, folosind energie.
- **Hrană.** Conserve vechi, apoi recolte din seră.

## 6. Supraviețuire (jucător)

| Statistică | Comportament |
|---|---|
| Sănătate | 0 = moarte; se reface lent când nevoile sunt satisfăcute |
| Foame | −100 în ~3 zile de joc; sub 15 pierzi sănătate |
| Sete | −100 în ~1,5 zile de joc; sub 15 pierzi sănătate |
| Oboseală | crește când ești treaz; somnul o resetează; oboseala mare îți scade viteza |
| Radiație (mSv) | se acumulează afară și din aer contaminat; >250 boală, >1000 letal; pastilele *Antirad* o scad |

Timpul: **1 oră de joc = 1 minut real** (o zi = 24 min). Somnul sare peste ore.

## 7. Agricultură

| Cultură | Timp | Lumină | Recoltă |
|---|---|---|---|
| Salată | 48 h | da | 2 salate + 1 sămânță |
| Roșii | 72 h | da | 3 roșii + 1 sămânță |
| Cartofi | 96 h | da | 5 cartofi + 2 tuberculi |
| Ciuperci | 60 h | **nu** | 4 ciuperci + 1 spori |

Jardinierele trebuie udate (1 L din rezervor). Fără apă sau lumină, creșterea se oprește. Neglijate 24 h, plantele mor.

## 8. Fabricare (bancul de lucru)

Exemple: *Filtru de mască* (cărbune + material textil + plastic), *Filtru de aer* (cărbune ×2 + material textil ×2 + fier vechi), *Bandaj* (material textil ×2), *Jardinieră*, *Lampă de creștere*, *Cutie de depozitare*, *Pat de ciuperci*, *Topor*, *Cartușe 9 mm* (fier vechi + praf de pușcă).

## 9. Construcție

Modul de construcție se deschide cu **B**. Construcția apare ca hologramă (verde = valid, roșu = invalid). Se rotește cu **R** sau cu rotița mouse-ului și se plasează cu **click stânga**, dacă ai materialele.

Construcții posibile: jardinieră, lampă de creștere, pat de ciuperci, pat suplimentar, lădiță de depozitare, bicicletă-dinam (energie manuală), baterii, colector de apă, sac de nisip.

**Săpatul:** o secțiune prăbușită se deschide cu lopata (ții apăsat **E**, 3 etape × 2 h de joc). Camera nouă apare cu tot cu provizii.

## 10. Raiduri pe suprafață

Pentru a ieși ai nevoie de **mască de gaze** și **filtre**. Un filtru ține ~6 minute reale. Costumul de protecție reduce radiația cu 70%.

**Rețeaua de adăposturi.** Obiectivul 17 face parte din rețeaua de protecție civilă a orașului: galerii subterane din anii '80 leagă
buncărul de ieșiri de urgență („Ieșirea 1…6”) ascunse sub dealurile de pământ din cartiere. Drumul spre o locație e timpul de mers prin galerii.
La sosire, ușa blindată a ieșirii se deschide, jucătorul urcă la suprafață și ușa se închide în urma lui. Întoarcerea se face prin aceeași
ieșire, marcată de un girofar portocaliu.

**Terenul.** Fiecare zonă e o vale: cenușă și pământ ars, cratere de bombă, drumuri, ruine pe platforme, iarbă moartă, bolovani și copaci uscați;
dealurile din jur închid zona de joc.

| Locație | Deblocare | Pericol | Pradă tipică |
|---|---|---|---|
| Zona uzinei Electromaș | ziua 2 | scăzut | fier vechi, material textil, combustibil |
| Supermarketul „Unic” | ziua 3 | mediu | conserve, apă, semințe |
| Spitalul Raional | radio, ziua 5 | mediu-ridicat | medicamente, Antirad, bandaje |
| Secția de poliție | radio, ziua 8 | ridicat | arme, muniție |
| Baza militară 2214 | radio, ziua 12 | foarte ridicat | filtre, costume, piese rare |

Radiația de la suprafață scade în timp (regula 7–10). În primele zile e extrem de periculos să ieși.

## 11. Povestea prin radio (Actele II–III)

- **Ziua 1–2:** mesaj automat de urgență în buclă.
- **Ziua 5 — „Garda Civilă”:** resturile armatei, cu bază la Barajul Vadului. Promit evacuare pentru cei care aduc provizii.
- **Ziua 8 — Moș Petru:** un negustor care umblă între adăposturi. Comerț.
- **Ziua 12 — „Corbii”:** jefuitori care cer tribut. Dacă refuzi, îți atacă ușa noaptea, deci trebuie să-ți aperi buncărul.
- **Ziua 20 — „Proiectul Lumina”:** un semnal criptat de la Baza 2214. Cine a lansat de fapt racheta?
- **Finaluri (plan):** evacuarea cu Garda / comunitate autonomă în Obiectivul 17 / adevărul despre Proiectul Lumina.

## 12. Controale

| Tastă | Acțiune |
|---|---|
| WASD | mișcare |
| Shift | sprint |
| Ctrl / C | ghemuit |
| Space | săritură |
| E (ține apăsat) | interacțiune |
| Tab | inventar |
| B | mod construcție |
| R | rotire (construcție) / reîncărcare |
| F | lanternă |
| Click stânga | atac / plasare |
| Esc | pauză |

## 13. Plan de dezvoltare

- **M1 — Vertical slice:** meniu, intro cu explozie, buncăr cu sistemele de bază, agricultură, fabricare, construcție, săpat, primul raid, salvare/încărcare.
- **M2 — Conținut:** toate locațiile, poveștile radio, negustorul, inamici diverși, arme.
- **M3 — Apărare:** atacurile Corbilor, întărirea ușii, capcane, turele improvizate.
- **M4 — Comunitate:** supraviețuitori recrutați (NPC cu nevoi și sarcini), moral.
- **M5 — Finaluri și polish:** cinematice, muzică dinamică, localizare EN, optimizare, build Steam.

## 14. Surse de asset-uri

- Modele 3D: Sketchfab (doar CC0 / CC-BY / CC-BY-SA, fără NC/ND), Poly Haven (CC0). Vezi `assets/models/CREDITS.md`.
- Texturi și HDRI: Poly Haven, ambientCG (CC0).
- Sunete și muzică: Wikimedia Commons, OpenGameArt, Kenney (CC0), incompetech (CC-BY), plus sunete procedurale. Vezi `assets/CREDITS_media.md`.
- Fonturi: Oswald, Barlow, Share Tech Mono (SIL OFL).

Pipeline-urile sunt în `tools/assets` (modele) și `tools/media` (texturi și audio).
