class_name ItemDB
extends RefCounted
## Static game data: items, recipes, buildables, crops, locations, radio log.

## cat: food, drink, med, res (material), tool, gear, weapon, ammo, seed, fuel
## w = weight (kg). food/water = restores %. heal = health. rad = mSv removed.
const ITEMS := {
	"canned_meat": {"name": "Conservă de carne", "cat": "food", "w": 0.4, "food": 38, "water": -4, "desc": "Carne de vită din rezervele de stat, 1987. Încă bună. Probabil."},
	"canned_beans": {"name": "Fasole cu cârnați", "cat": "food", "w": 0.45, "food": 32, "water": 4, "desc": "Conservă clasică. Sățioasă."},
	"crackers": {"name": "Pesmeți", "cat": "food", "w": 0.2, "food": 18, "water": -8, "desc": "Uscați ca deșertul. Îți fac sete."},
	"tomato": {"name": "Roșie", "cat": "food", "w": 0.15, "food": 10, "water": 8, "desc": "Crescută sub lămpi. Are gust de speranță."},
	"lettuce": {"name": "Salată", "cat": "food", "w": 0.2, "food": 8, "water": 10, "desc": "Frunze verzi, proaspete."},
	"potato": {"name": "Cartof", "cat": "food", "w": 0.25, "food": 22, "water": 0, "desc": "Hrană adevărată. Se poate și planta."},
	"mushroom": {"name": "Ciuperci", "cat": "food", "w": 0.1, "food": 12, "water": 2, "desc": "Cresc în întuneric. Ca și noi."},
	"water_bottle": {"name": "Sticlă de apă", "cat": "drink", "w": 0.5, "food": 0, "water": 35, "desc": "Apă potabilă, 0,5 L."},
	"dirty_water": {"name": "Apă murdară (5 L)", "cat": "res", "w": 5.0, "desc": "Trebuie purificată înainte de a fi băută."},
	"bandage": {"name": "Bandaj", "cat": "med", "w": 0.1, "heal": 18, "desc": "Oprește sângerarea."},
	"medkit": {"name": "Trusă medicală", "cat": "med", "w": 0.6, "heal": 55, "desc": "Trusă militară completă."},
	"antirad": {"name": "Antirad", "cat": "med", "w": 0.05, "rad": 180, "desc": "Pastile care elimină o parte din radiația absorbită."},
	"fuel_can": {"name": "Canistră motorină (10 L)", "cat": "fuel", "w": 9.0, "fuel": 10.0, "desc": "Combustibil pentru generator."},
	"mask_filter": {"name": "Filtru de mască", "cat": "gear", "w": 0.3, "desc": "Un filtru ține aproximativ 6 minute la suprafață."},
	"air_filter": {"name": "Filtru de aer", "cat": "gear", "w": 2.0, "desc": "Cartuș pentru unitatea de ventilație a buncărului."},
	"gas_mask": {"name": "Mască de gaze GP-5", "cat": "gear", "w": 0.8, "desc": "Obligatorie la suprafață."},
	"hazmat_suit": {"name": "Costum de protecție L-1", "cat": "gear", "w": 3.0, "desc": "Reduce radiația absorbită cu 70%."},
	"shovel": {"name": "Lopată", "cat": "tool", "w": 2.0, "desc": "Pentru săpat prin dărâmături."},
	"flashlight": {"name": "Lanternă", "cat": "tool", "w": 0.3, "desc": "[F] aprinde / stinge."},
	"geiger": {"name": "Contor Geiger", "cat": "tool", "w": 0.5, "desc": "Arată nivelul radiației din jur."},
	"axe": {"name": "Topor de pompier", "cat": "weapon", "w": 2.2, "dmg": 45, "desc": "Armă de corp la corp. [1]"},
	"pistol": {"name": "Pistol de 9 mm", "cat": "weapon", "w": 0.8, "dmg": 34, "desc": "Pistol semiautomat de serviciu, 15 cartușe. [2]"},
	"ammo_9mm": {"name": "Cartușe 9 mm", "cat": "ammo", "w": 0.01, "desc": "Muniție pentru pistol."},
	"rifle": {"name": "Kalașnikov AK-74M", "cat": "weapon", "w": 3.4, "dmg": 36, "desc": "Automată, 5,45 mm, cu pat rabatabil. [3]"},
	"ammo_762": {"name": "Cartușe 5,45 mm", "cat": "ammo", "w": 0.011, "desc": "Muniție pentru AK-74M."},
	"shotgun": {"name": "Saiga-12", "cat": "weapon", "w": 3.6, "dmg": 110, "desc": "Pușcă semiautomată cal. 12 cu încărcător de 8. Devastatoare de aproape. [4]"},
	"shells_12": {"name": "Cartușe cal. 12", "cat": "ammo", "w": 0.04, "desc": "Alice pentru Saiga-12."},
	"baked_potato": {"name": "Cartofi copți", "cat": "food", "w": 0.25, "food": 34, "water": 0, "desc": "Gătiți pe aragaz. Mult mai sățioși."},
	"mushroom_soup": {"name": "Supă de ciuperci", "cat": "food", "w": 0.4, "food": 30, "water": 22, "desc": "Caldă. Îți amintește de casă."},
	"tomato_salad": {"name": "Salată de roșii", "cat": "food", "w": 0.3, "food": 22, "water": 16, "desc": "Proaspătă. Moralul crește."},
	"stew": {"name": "Tocană din conservă", "cat": "food", "w": 0.5, "food": 55, "water": 10, "desc": "Conservă încălzită cu cartofi."},
	"scrap": {"name": "Fier vechi", "cat": "res", "w": 1.0, "desc": "Bucăți de metal utile."},
	"wood": {"name": "Lemn", "cat": "res", "w": 1.2, "desc": "Scânduri și bucăți de mobilier."},
	"cloth": {"name": "Material textil", "cat": "res", "w": 0.2, "desc": "Haine vechi, cearșafuri."},
	"plastic": {"name": "Plastic", "cat": "res", "w": 0.2, "desc": "Recipiente, carcase."},
	"electronics": {"name": "Componente electronice", "cat": "res", "w": 0.3, "desc": "Plăci, fire, relee."},
	"charcoal": {"name": "Cărbune activ", "cat": "res", "w": 0.3, "desc": "Esențial pentru filtre."},
	"duct_tape": {"name": "Bandă adezivă", "cat": "res", "w": 0.2, "desc": "Repară orice. Aproape."},
	"gunpowder": {"name": "Praf de pușcă", "cat": "res", "w": 0.1, "desc": "Pentru muniție."},
	"pipe": {"name": "Țeavă", "cat": "res", "w": 1.5, "desc": "Țeavă metalică."},
	"soil": {"name": "Sac cu pământ", "cat": "res", "w": 5.0, "desc": "Pământ pentru jardiniere."},
	"battery_cell": {"name": "Acumulator", "cat": "res", "w": 4.0, "desc": "Baterie auto. Stochează energie."},
	"seeds_tomato": {"name": "Semințe de roșii", "cat": "seed", "w": 0.01, "crop": "tomato", "desc": "Se plantează în jardinieră."},
	"seeds_lettuce": {"name": "Semințe de salată", "cat": "seed", "w": 0.01, "crop": "lettuce", "desc": "Se plantează în jardinieră."},
	"seed_potato": {"name": "Cartof de sămânță", "cat": "seed", "w": 0.25, "crop": "potato", "desc": "Se plantează în jardinieră."},
	"spores_mushroom": {"name": "Spori de ciuperci", "cat": "seed", "w": 0.01, "crop": "mushroom", "desc": "Se plantează în patul de ciuperci. Nu au nevoie de lumină."},
}

const CAT_NAMES := {
	"food": "Hrană", "drink": "Apă", "med": "Medicale", "res": "Materiale", "tool": "Unelte",
	"gear": "Echipament", "weapon": "Arme", "ammo": "Muniție", "seed": "Semințe", "fuel": "Combustibil",
}

## time = game minutes spent crafting
const RECIPES := [
	{"out": "mask_filter", "n": 1, "cost": {"charcoal": 1, "cloth": 1, "plastic": 1}, "time": 30},
	{"out": "air_filter", "n": 1, "cost": {"charcoal": 2, "cloth": 2, "scrap": 1}, "time": 60},
	{"out": "charcoal", "n": 2, "cost": {"wood": 2}, "time": 45},
	{"out": "bandage", "n": 2, "cost": {"cloth": 2}, "time": 10},
	{"out": "medkit", "n": 1, "cost": {"bandage": 2, "plastic": 1, "antirad": 1}, "time": 20},
	{"out": "axe", "n": 1, "cost": {"scrap": 3, "wood": 2, "duct_tape": 1}, "time": 60},
	{"out": "ammo_9mm", "n": 8, "cost": {"scrap": 1, "gunpowder": 1}, "time": 30},
	{"out": "soil", "n": 1, "cost": {"mushroom": 2, "wood": 1}, "time": 30},
	{"out": "water_bottle", "n": 1, "cost": {"plastic": 1}, "time": 5, "needs_water": 0.5},
	{"out": "hazmat_suit", "n": 1, "cost": {"cloth": 6, "plastic": 4, "duct_tape": 2}, "time": 120},
	{"out": "ammo_762", "n": 10, "cost": {"scrap": 2, "gunpowder": 2}, "time": 45, "req": "bench_2"},
	{"out": "shells_12", "n": 6, "cost": {"plastic": 1, "scrap": 1, "gunpowder": 1}, "time": 30, "req": "bench_2"},
	{"out": "medkit", "n": 2, "cost": {"bandage": 2, "antirad": 1, "plastic": 2}, "time": 30, "req": "infirmary"},
	{"out": "baked_potato", "n": 2, "cost": {"potato": 2}, "time": 20, "station": "stove"},
	{"out": "mushroom_soup", "n": 1, "cost": {"mushroom": 2}, "time": 20, "station": "stove", "needs_water": 0.5},
	{"out": "tomato_salad", "n": 1, "cost": {"tomato": 2, "lettuce": 1}, "time": 10, "station": "stove"},
	{"out": "stew", "n": 1, "cost": {"canned_meat": 1, "potato": 1}, "time": 25, "station": "stove"},
]

## Weapon handling (procedural viewmodel). type: melee | gun.
const WEAPONS := {
	"axe": {"type": "melee", "model": "weapon_axe", "dmg": 45.0, "rate": 0.75, "reach": 2.1, "stamina": 9.0, "slot": 1},
	"pistol": {"type": "gun", "model": "weapon_pistol", "ammo": "ammo_9mm", "mag": 15, "dmg": 34.0, "rate": 0.22, "auto": false,
		"spread": 0.014, "ads_spread": 0.004, "recoil": 0.035, "kick": 0.06, "reload": 1.5, "range": 70.0, "pellets": 1,
		"sound": "gunshot_pistol", "reload_sound": "reload", "ads_fov": 0.85, "slot": 2},
	"rifle": {"type": "gun", "model": "weapon_rifle", "ammo": "ammo_762", "mag": 30, "dmg": 36.0, "rate": 0.1, "auto": true,
		"spread": 0.03, "ads_spread": 0.006, "recoil": 0.022, "kick": 0.045, "reload": 2.4, "range": 120.0, "pellets": 1,
		"sound": "rifle_shot", "reload_sound": "reload_rifle", "ads_fov": 0.72, "slot": 3, "tracer": true},
	"shotgun": {"type": "gun", "model": "weapon_saiga", "ammo": "shells_12", "mag": 8, "dmg": 13.0, "rate": 0.32, "auto": false,
		"spread": 0.075, "ads_spread": 0.05, "recoil": 0.09, "kick": 0.12, "reload": 2.2, "range": 35.0, "pellets": 9,
		"sound": "shotgun_shot", "reload_sound": "reload_shotgun", "ads_fov": 0.9, "slot": 4},
}

## Bunker development tree. effect keys: mul_* multiply, add_* add, unlock_* flags.
const UPGRADES := {
	"gen_2": {"name": "Reglaj injectoare", "branch": "energie", "tier": 1, "icon": "power", "cost": {"scrap": 4, "electronics": 2, "duct_tape": 1}, "hours": 3,
		"desc": "Generatorul consumă cu 25% mai puțină motorină.", "effect": {"mul_fuel": 0.75}},
	"battery_2": {"name": "Baterii în paralel", "branch": "energie", "tier": 2, "icon": "battery", "req": ["gen_2"], "cost": {"battery_cell": 2, "electronics": 2, "scrap": 2}, "hours": 2,
		"desc": "+100% capacitate a bateriilor de avarie.", "effect": {"add_battery": 100.0}},
	"solar": {"name": "Panouri solare", "branch": "energie", "tier": 3, "icon": "power", "req": ["battery_2"], "cost": {"electronics": 6, "plastic": 4, "pipe": 2, "scrap": 4}, "hours": 6,
		"desc": "Panouri pe acoperișul uzinei: încarcă bateriile ziua, chiar și cu generatorul oprit.", "effect": {"add_solar": 9.0}},
	"fvu_2": {"name": "Filtre în cascadă", "branch": "aer", "tier": 1, "icon": "filter", "cost": {"charcoal": 3, "cloth": 2, "pipe": 1}, "hours": 3,
		"desc": "Filtrul FVU se uzează de două ori mai încet.", "effect": {"mul_filter_wear": 0.5}},
	"water_2": {"name": "Membrană de osmoză", "branch": "aer", "tier": 2, "icon": "water", "req": ["fvu_2"], "cost": {"plastic": 4, "charcoal": 2, "electronics": 1}, "hours": 3,
		"desc": "Purificatorul produce dublu din aceeași apă murdară.", "effect": {"mul_purify": 2.0}},
	"well": {"name": "Puț de adâncime", "branch": "aer", "tier": 3, "icon": "water", "req": ["water_2"], "dig": "sec_b", "cost": {"pipe": 4, "scrap": 6, "electronics": 2}, "hours": 8,
		"desc": "Forează prin podeaua atelierului: +10 L de apă pe zi, fără curent.", "effect": {"add_water_day": 10.0}},
	"hydro_1": {"name": "Hidroponie", "branch": "agricultura", "tier": 1, "icon": "seed", "cost": {"plastic": 4, "pipe": 2, "electronics": 1}, "hours": 4,
		"desc": "Culturile cresc cu 40% mai repede și consumă mai puțină apă.", "effect": {"mul_growth": 1.4, "mul_crop_water": 0.7}},
	"led": {"name": "Lămpi LED de creștere", "branch": "agricultura", "tier": 2, "icon": "power", "req": ["hydro_1"], "cost": {"electronics": 4, "scrap": 1}, "hours": 2,
		"desc": "Lămpile consumă mai puțin și accelerează creșterea cu încă 20%.", "effect": {"mul_growth": 1.2, "mul_lamp_power": 0.4}},
	"kitchen": {"name": "Bucătăria buncărului", "branch": "agricultura", "tier": 3, "icon": "food", "req": ["led"], "cost": {"scrap": 4, "pipe": 1, "wood": 2}, "hours": 3,
		"desc": "Deblochează aragazul de campanie: mâncarea gătită e cu mult mai sățioasă.", "effect": {"unlock_stove": 1.0}},
	"bench_2": {"name": "Strung și menghină", "branch": "atelier", "tier": 1, "icon": "tool", "cost": {"scrap": 6, "pipe": 2, "electronics": 1}, "hours": 4,
		"desc": "Fabricarea e cu 30% mai rapidă. Deblochează muniție 5,45 și cal. 12.", "effect": {"mul_craft_time": 0.7}},
	"backpack": {"name": "Rucsac militar", "branch": "atelier", "tier": 2, "icon": "weight", "req": ["bench_2"], "cost": {"cloth": 6, "duct_tape": 2, "scrap": 1}, "hours": 3,
		"desc": "+15 kg capacitate de transport.", "effect": {"add_carry": 15.0}},
	"infirmary": {"name": "Infirmerie echipată", "branch": "atelier", "tier": 3, "icon": "med", "req": ["backpack"], "dig": "sec_c", "cost": {"plastic": 3, "cloth": 4, "electronics": 2}, "hours": 4,
		"desc": "Somnul vindecă de două ori mai repede. Poți fabrica truse medicale.", "effect": {"mul_sleep_heal": 2.0}},
	"door_2": {"name": "Bare de oțel la ușă", "branch": "aparare", "tier": 1, "icon": "skull", "cost": {"scrap": 8, "pipe": 3}, "hours": 4,
		"desc": "Ușa blindată rezistă atacurilor jefuitorilor.", "effect": {"add_defense": 1.0}},
	"alarm": {"name": "Senzori și alarmă", "branch": "aparare", "tier": 2, "icon": "radio", "req": ["door_2"], "cost": {"electronics": 4, "plastic": 2}, "hours": 3,
		"desc": "Te avertizează când cineva se apropie de buncăr.", "effect": {"add_defense": 1.0}},
	"armory": {"name": "Armurerie", "branch": "aparare", "tier": 3, "icon": "weapon", "req": ["alarm"], "cost": {"scrap": 6, "wood": 4, "gunpowder": 2}, "hours": 4,
		"desc": "Arme întreținute: reîncărcare cu 20% mai rapidă și recul mai mic.", "effect": {"mul_reload": 0.8, "mul_recoil": 0.8}},
	"radio_2": {"name": "Antenă cu bandă largă", "branch": "explorare", "tier": 1, "icon": "radio", "cost": {"electronics": 3, "pipe": 3, "scrap": 2}, "hours": 3,
		"desc": "Prinzi frecvențe îndepărtate. Deblochează stația de metrou „Piața Unirii”.", "effect": {"unlock_loc": 1.0}},
	"maps": {"name": "Hărți topografice", "branch": "explorare", "tier": 2, "icon": "objective", "req": ["radio_2"], "cost": {"cloth": 1, "plastic": 1}, "hours": 1,
		"desc": "Drumurile spre locații durează cu 30% mai puțin.", "effect": {"mul_travel": 0.7}},
	"suit_2": {"name": "Costum căptușit cu plumb", "branch": "explorare", "tier": 3, "icon": "rad", "req": ["maps"], "cost": {"scrap": 6, "cloth": 4, "duct_tape": 2}, "hours": 5,
		"desc": "Costumul de protecție blochează 85% din radiație (în loc de 70%).", "effect": {"mul_suit": 0.5}},
}
const BRANCHES := [["energie", "ENERGIE"], ["aer", "APĂ & AER"], ["agricultura", "AGRICULTURĂ"], ["atelier", "ATELIER"], ["aparare", "APĂRARE"], ["explorare", "EXPLORARE"]]

## Things placed with build mode. cat = build-menu tab; mount = floor (default) | wall | ceiling;
## wall = floor furniture that backs onto the nearest wall. Footprints come from the real
## model bounds (size is only the fallback for procedural meshes).
## Lights: power = litres of diesel per game hour at 100 % brightness; self_powered = own battery.
const BUILDABLES := {
	"planter": {"name": "Jardinieră", "cat": "agricultura", "model": "planter_box", "cost": {"wood": 4, "scrap": 1, "soil": 1}, "size": Vector3(1.2, 0.5, 0.6), "desc": "Pentru roșii, salată, cartofi. Are nevoie de lumină."},
	"mushroom_bed": {"name": "Pat de ciuperci", "cat": "agricultura", "model": "planter_box", "cost": {"wood": 3, "soil": 1}, "size": Vector3(1.2, 0.5, 0.6), "desc": "Ciuperci în întuneric. Fără lumină."},
	"grow_lamp": {"name": "Lampă de creștere", "cat": "agricultura", "model": "lamp_cage", "cost": {"electronics": 2, "scrap": 2}, "size": Vector3(0.4, 1.8, 0.4), "desc": "Luminează jardinierele pe o rază de 3 m. Consumă energie."},
	"water_collector": {"name": "Condensator de apă", "cat": "utilitati", "model": "water_purifier", "cost": {"scrap": 4, "pipe": 2, "plastic": 2, "electronics": 1}, "size": Vector3(0.9, 1.4, 0.6), "desc": "Extrage ~6 L de apă pe zi din aer. Consumă energie."},
	"bike_generator": {"name": "Bicicletă-dinam", "cat": "utilitati", "model": "", "cost": {"scrap": 6, "electronics": 2, "pipe": 2}, "size": Vector3(0.6, 1.1, 1.6), "desc": "Pedalezi și încarci bateriile de urgență."},
	"battery_bank": {"name": "Banc de baterii", "cat": "utilitati", "model": "car_battery", "cost": {"battery_cell": 2, "electronics": 1, "scrap": 1}, "size": Vector3(0.7, 0.4, 0.4), "desc": "+50% capacitate baterii de urgență."},
	"bed": {"name": "Pat suplimentar", "cat": "mobilier", "model": "bunk_bed", "wall": true, "comfort": 3.0, "cost": {"wood": 4, "scrap": 4, "cloth": 4}, "size": Vector3(0.95, 1.8, 2.0), "desc": "Pentru viitorii locatari."},
	"storage": {"name": "Ladă de depozitare", "cat": "mobilier", "model": "wooden_crate", "cost": {"wood": 4}, "size": Vector3(0.6, 0.6, 0.6), "desc": "Ordinea face buncărul mai uman (confort).", "comfort": 2.0},
	"sandbags": {"name": "Saci de nisip", "cat": "utilitati", "model": "sandbags", "cost": {"cloth": 2, "soil": 2}, "size": Vector3(1.2, 0.5, 0.5), "desc": "Fortificație pentru ecluză."},
	"stove": {"name": "Aragaz de campanie", "cat": "utilitati", "model": "camping_stove", "cost": {"scrap": 2, "pipe": 1}, "size": Vector3(0.5, 0.8, 0.5), "desc": "Gătește mâncare caldă (necesită Bucătăria). Încape și pe masă.", "req": "kitchen", "comfort": 4.0},
	"sofa": {"name": "Canapea", "cat": "mobilier", "model": "sofa_old", "cost": {"wood": 4, "cloth": 6}, "size": Vector3(2.0, 0.9, 0.9), "desc": "Confort: somn mai odihnitor.", "comfort": 8.0, "wall": true},
	"table": {"name": "Masă", "cat": "mobilier", "model": "table_metal", "cost": {"scrap": 3, "wood": 2}, "size": Vector3(1.6, 0.7, 0.8), "desc": "Confort. Pe ea poți pune felinare, radiouri, conserve.", "comfort": 4.0},
	"chair": {"name": "Scaun", "cat": "mobilier", "model": "chair", "cost": {"scrap": 1, "wood": 1}, "size": Vector3(0.5, 0.9, 0.5), "desc": "Confort.", "comfort": 2.0},
	"shelf": {"name": "Raft metalic", "cat": "mobilier", "model": "metal_shelf", "cost": {"scrap": 4}, "size": Vector3(1.0, 2.0, 0.65), "desc": "Ordine în buncăr (confort).", "comfort": 3.0, "wall": true},
	"weapon_rack": {"name": "Rastel de arme", "cat": "mobilier", "model": "weapon_rack", "cost": {"wood": 3, "scrap": 2}, "size": Vector3(1.2, 1.6, 0.4), "desc": "Arme la îndemână (confort, decor).", "comfort": 3.0, "wall": true},
	"hydro_rack": {"name": "Raft hidroponic", "cat": "agricultura", "model": "hydroponic_rack", "cost": {"plastic": 3, "pipe": 2, "electronics": 1}, "size": Vector3(1.4, 1.8, 0.6), "desc": "Cultură verticală de salată și roșii (necesită Hidroponie).", "req": "hydro_1", "wall": true},
	# --- lights (DecoLight): colour, brightness, shadows and on/off are set per light with [E]
	"lamp": {"name": "Lampă industrială", "cat": "lumini", "mount": "ceiling", "model": "lamp_cage", "cost": {"electronics": 1, "scrap": 1}, "size": Vector3(0.3, 0.45, 0.3), "power": 0.012,
		"desc": "Lampă cu grilaj, suspendată de tavan. Lumină puternică pentru o cameră întreagă."},
	"fluoro": {"name": "Tub fluorescent", "cat": "lumini", "mount": "ceiling", "model": "fluorescent_lamp", "cost": {"electronics": 2, "scrap": 1, "plastic": 1}, "size": Vector3(0.15, 0.25, 1.2), "power": 0.015,
		"desc": "Lumină rece, uniformă, de atelier. Pâlpâie când pornește."},
	"sconce": {"name": "Aplică de perete", "cat": "lumini", "mount": "wall", "model": "", "cost": {"electronics": 1, "scrap": 2}, "size": Vector3(0.2, 0.35, 0.35), "power": 0.008, "comfort": 1.0,
		"desc": "Braț metalic cu o lampă mică cu grilaj. Lumină caldă de-a lungul pereților."},
	"bulkhead": {"name": "Lampă etanșă de buncăr", "cat": "lumini", "mount": "wall", "model": "", "cost": {"electronics": 1, "scrap": 1, "plastic": 1}, "size": Vector3(0.28, 0.2, 0.12), "power": 0.008,
		"desc": "Clasica lampă ovală cu grilaj din adăposturile sovietice."},
	"beacon": {"name": "Girofar", "cat": "lumini", "mount": "wall", "model": "", "cost": {"electronics": 2, "scrap": 1, "plastic": 1}, "size": Vector3(0.16, 0.22, 0.28), "power": 0.01,
		"desc": "Lumină rotativă de avertizare. Implicit roșie — bună pentru ecluză."},
	"string_lights": {"name": "Ghirlandă de becuri", "cat": "lumini", "mount": "wall", "model": "", "cost": {"electronics": 2, "cloth": 1, "duct_tape": 1}, "size": Vector3(2.4, 0.25, 0.08), "power": 0.006, "comfort": 3.0,
		"desc": "Becuri mici pe un fir de 2,4 m. Buncărul începe să semene a casă."},
	"floor_lamp": {"name": "Lampadar", "cat": "lumini", "mount": "floor", "model": "", "cost": {"electronics": 1, "pipe": 1, "cloth": 2}, "size": Vector3(0.42, 1.62, 0.42), "power": 0.008, "comfort": 3.0,
		"desc": "Abajur de pânză pe picior metalic. Lumină caldă și difuză, lângă canapea sau pat."},
	"work_light": {"name": "Proiector pe trepied", "cat": "lumini", "mount": "floor", "model": "", "cost": {"electronics": 2, "pipe": 2, "scrap": 1}, "size": Vector3(0.8, 1.75, 0.8), "power": 0.03,
		"desc": "Reflector de șantier: fascicul puternic în direcția în care îl rotești, cu umbre."},
	"lantern": {"name": "Felinar de campanie", "cat": "lumini", "mount": "floor", "model": "", "cost": {"battery_cell": 1, "plastic": 1, "scrap": 1}, "size": Vector3(0.14, 0.22, 0.14), "self_powered": true, "comfort": 1.0,
		"desc": "Are baterie proprie — luminează și fără curent. Încape pe masă sau pe raft."},
}
const BUILD_CATS := [["mobilier", "MOBILIER"], ["lumini", "LUMINI"], ["agricultura", "AGRICULTURĂ"], ["utilitati", "UTILITĂȚI"]]
const MOUNT_NAMES := {"floor": "Podea / masă", "wall": "Perete", "ceiling": "Tavan"}

## Furniture that ships with the bunker (movable with [G]): model id -> name, wall = backs onto a wall.
const PROPS := {
	"table_metal": {"name": "Masă metalică"}, "chair": {"name": "Scaun"}, "canned_food": {"name": "Conserve"},
	"water_jug": {"name": "Bidon cu apă"}, "radio_station": {"name": "Stație radio R-105"}, "crt_computer": {"name": "Terminal ZX-17"},
	"bunk_bed": {"name": "Pat", "wall": true}, "metal_shelf": {"name": "Raft metalic", "wall": true}, "locker": {"name": "Dulap", "wall": true},
	"sofa_old": {"name": "Canapea", "wall": true}, "workbench": {"name": "Banc de lucru", "wall": true}, "toolbox": {"name": "Trusă de scule"},
	"first_aid_kit": {"name": "Trusă medicală"}, "diesel_generator": {"name": "Generator diesel"}, "planter_box": {"name": "Jardinieră"},
	"wooden_crate": {"name": "Ladă de lemn"}, "military_crate": {"name": "Ladă militară"}, "camping_stove": {"name": "Aragaz de campanie"},
	"car_battery": {"name": "Baterie auto"}, "bucket": {"name": "Găleată"}, "fridge_old": {"name": "Frigider vechi", "wall": true},
	"fire_extinguisher": {"name": "Stingător"}, "jerrycan": {"name": "Canistre"}, "oil_barrel": {"name": "Butoi"},
	"sandbags": {"name": "Saci de nisip"}, "water_tank": {"name": "Rezervor de apă"}, "water_purifier": {"name": "Purificator de apă"},
	"air_filter_unit": {"name": "Unitate FVU", "wall": true}, "hydroponic_rack": {"name": "Raft hidroponic", "wall": true},
	"weapon_rack": {"name": "Rastel de arme", "wall": true},
}

## Surface loot by container kind (town furniture): item -> max count per roll.
## Empty tables ("crate", "car") use the location's own loot table.
const LOOT_KINDS := {
	"fridge": {"canned_meat": 2, "canned_beans": 2, "water_bottle": 3, "potato": 3, "tomato": 2, "lettuce": 1},
	"cupboard": {"canned_beans": 2, "crackers": 3, "canned_meat": 1, "water_bottle": 2, "charcoal": 1, "seed_potato": 1, "duct_tape": 1},
	"pantry": {"canned_meat": 2, "canned_beans": 3, "crackers": 2, "water_bottle": 3, "seeds_tomato": 1, "seeds_lettuce": 1, "seed_potato": 2},
	"wardrobe": {"cloth": 4, "gas_mask": 1, "bandage": 1, "duct_tape": 1},
	"drawer": {"bandage": 2, "antirad": 1, "battery_cell": 1, "electronics": 1, "duct_tape": 1, "ammo_9mm": 5},
	"bag": {"water_bottle": 1, "canned_meat": 1, "bandage": 2, "battery_cell": 1, "ammo_9mm": 6, "mask_filter": 1, "crackers": 2},
	"medicine": {"bandage": 3, "medkit": 1, "antirad": 2},
	"tools": {"scrap": 4, "pipe": 2, "duct_tape": 2, "electronics": 1, "wood": 3, "battery_cell": 1, "shovel": 1},
	"shop": {"canned_meat": 3, "canned_beans": 3, "crackers": 3, "water_bottle": 4, "seeds_tomato": 1, "seeds_lettuce": 1, "plastic": 2},
	"shelf": {"plastic": 2, "cloth": 2, "electronics": 1, "battery_cell": 1, "charcoal": 2, "water_bottle": 1, "duct_tape": 1},
	"locker": {"cloth": 2, "gas_mask": 1, "mask_filter": 2, "ammo_9mm": 8, "bandage": 2},
	"crate": {},
	"car": {},
}

## hours = growth time; light = needs grow light; bed = planter type
const CROPS := {
	"tomato": {"name": "Roșii", "hours": 72.0, "light": true, "bed": "planter", "model": "plant_tomato", "yield": {"tomato": 3, "seeds_tomato": 1}},
	"lettuce": {"name": "Salată", "hours": 48.0, "light": true, "bed": "planter", "model": "plant_lettuce", "yield": {"lettuce": 2, "seeds_lettuce": 1}},
	"potato": {"name": "Cartofi", "hours": 96.0, "light": true, "bed": "planter", "model": "plant_pepper", "yield": {"potato": 5, "seed_potato": 2}},
	"mushroom": {"name": "Ciuperci", "hours": 60.0, "light": false, "bed": "mushroom_bed", "model": "mushrooms", "yield": {"mushroom": 4, "spores_mushroom": 1}},
}

## Surface locations for expeditions.
## rad = base radiation (mSv/min at day 1, decays), danger = enemy count factor
const LOCATIONS := {
	"factory": {"name": "Zona uzinei Electromaș", "desc": "Hale industriale chiar deasupra buncărului. Aproape și relativ sigur.", "travel": 0.5, "rad": 1.0, "danger": 0.6, "day": 2,
		"loot": {"scrap": 6, "wood": 4, "cloth": 3, "plastic": 3, "electronics": 2, "fuel_can": 1, "pipe": 2, "duct_tape": 1, "charcoal": 1, "battery_cell": 1, "dirty_water": 2}},
	"market": {"name": "Supermarketul „Unic”", "desc": "Rafturi răsturnate, dar poate a mai rămas mâncare.", "travel": 1.0, "rad": 1.4, "danger": 1.0, "day": 3,
		"loot": {"canned_meat": 4, "canned_beans": 4, "crackers": 3, "water_bottle": 5, "plastic": 3, "cloth": 2, "seeds_tomato": 1, "seeds_lettuce": 1, "seed_potato": 1, "duct_tape": 1}},
	"hospital": {"name": "Spitalul Raional", "desc": "Medicamente, bandaje, poate Antirad. Și ceva ce urlă noaptea.", "travel": 1.5, "rad": 1.8, "danger": 1.4, "day": 5,
		"loot": {"bandage": 4, "medkit": 2, "antirad": 3, "cloth": 4, "plastic": 2, "electronics": 2, "water_bottle": 2, "charcoal": 2}},
	"police": {"name": "Secția de poliție nr. 2", "desc": "Armurăria ar putea fi încă încuiată.", "travel": 1.5, "rad": 2.0, "danger": 1.8, "day": 8,
		"loot": {"pistol": 1, "ammo_9mm": 14, "shotgun": 1, "shells_12": 10, "gunpowder": 3, "bandage": 2, "electronics": 2, "scrap": 3, "gas_mask": 1, "mask_filter": 2}},
	"metro": {"name": "Stația de metrou „Piața Unirii”", "desc": "Tuneluri întunecate, vagoane abandonate. Oamenii s-au ascuns aici în Ziua Zero.", "travel": 2.0, "rad": 0.8, "danger": 2.0, "day": 99, "req_up": "radio_2",
		"loot": {"canned_meat": 3, "water_bottle": 4, "bandage": 3, "ammo_9mm": 12, "shells_12": 6, "shotgun": 1, "electronics": 3, "battery_cell": 2, "cloth": 3}},
	"military": {"name": "Baza militară 2214", "desc": "Filtre, costume, piese. Și cei care le păzesc.", "travel": 3.0, "rad": 3.0, "danger": 2.4, "day": 12,
		"loot": {"mask_filter": 4, "air_filter": 2, "hazmat_suit": 1, "ammo_9mm": 20, "rifle": 1, "ammo_762": 45, "medkit": 2, "antirad": 3, "electronics": 4, "fuel_can": 2, "canned_meat": 4}},
}

## Radio broadcasts. `day` = earliest day, `unlock` = location unlocked.
const RADIO := [
	{"id": "r1", "day": 1, "from": "Sistemul Național de Alertă", "text": "...Aceasta este o transmisiune automată. A fost declarată stare de urgență nucleară. Rămâneți în adăposturi. Nu ieșiți la suprafață cel puțin 14 zile. Raționalizați apa și hrana. Mesajul se va repeta..."},
	{"id": "r2", "day": 2, "from": "Frecvență necunoscută", "text": "...dacă mă aude cineva... sunt la uzina Electromaș, hala trei... au căzut toate... e liniște... prea multă liniște... (zgomot)"},
	{"id": "r3", "day": 3, "from": "Sistemul Național de Alertă", "text": "...nivelul radiației în zona Vadul Nou scade. Ieșirile scurte sunt posibile doar cu mască și filtru. Supermarketurile și depozitele din cartiere pot conține provizii..."},
	{"id": "r4", "day": 5, "from": "Garda Civilă — Barajul Vadului", "text": "Aici Garda Civilă. Avem apă, curent și medici. Spitalul Raional a fost abandonat cu stocuri întregi. Oricine aduce medicamente la baraj va fi primit. Repet: aici Garda Civilă.", "unlock": "hospital"},
	{"id": "r5", "day": 8, "from": "Moș Petru", "text": "Hehe... mă auziți, șoareci de buncăr? Petru vă salută. Am auzit că armurăria de la secția doi a rămas încuiată. Cine o deschide, mă caută pe frecvența asta. Fac schimb cinstit... aproape cinstit.", "unlock": "police"},
	{"id": "r6", "day": 12, "from": "Frecvență militară criptată", "text": "...PROIECTUL LUMINA... Baza 2214... codul de acces... rezervele de filtre... nu trebuie să afle nimeni ce s-a lansat de aici... (transmisiune întreruptă)", "unlock": "military"},
	{"id": "r7", "day": 14, "from": "Corbii", "text": "Ascultați, cârtițelor. Noi suntem Corbii. Știm unde sunteți. Lăsați lângă intrare provizii pentru o săptămână sau intrăm noi după ele. Aveți trei zile."},
	{"id": "r8", "day": 20, "from": "Garda Civilă — Barajul Vadului", "text": "Convoiul de evacuare pleacă de la baraj în ziua 40. Locuri limitate. Aduceți-vă proviziile. Garda Civilă, terminat."},
	# answers to what the player did (day 0 = gated only by the flag)
	{"id": "r7_paid", "day": 0, "req_flag": "corbii_paid", "from": "Corbii", "text": "Bravo, cârtițelor. Ați fost cuminți. Proviziile au ajuns unde trebuie. Poate ne mai vedem... poate nu."},
	{"id": "r7_repelled", "day": 0, "req_flag": "corbii_repelled", "from": "Corbii", "text": "...ușa aia blestemată... (tuse)... Mircea e mort... Lasă, cârtițelor. Nu uităm. Ne mai vedem pe afară."},
	{"id": "r7_raided", "day": 0, "req_flag": "corbii_raided", "from": "Corbii", "text": "Mulțumim pentru ospitalitate, cârtițelor. Data viitoare lăsați ușa deschisă, să nu mai stricăm nimic."},
]


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "cat": "res", "w": 0.1, "desc": ""})


static func item_name(id: String) -> String:
	return item(id).get("name", id)


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%s ×%d" % [item_name(k), cost[k]])
	return ", ".join(parts)
