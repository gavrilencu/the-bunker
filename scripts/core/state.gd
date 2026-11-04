extends Node
## Persistent game state + survival simulation (time, needs, bunker systems, crops).

signal new_day(day: int)
signal notify(text: String, kind: String)
signal died(reason: String)
signal inventory_changed
signal item_gained(id: String, n: int, to_stash: bool)

## Debug / self-test runs (--scene, --selftest) point this at a scratch slot so they never
## overwrite the player's game.
var save_path := "user://save_slot1.json"
const FUEL_MAX := 40.0
const WATER_MAX := 200.0

## Simulation is only active during gameplay scenes.
var running := false
## "menu" | "intro" | "bunker" | "surface"
var context := "menu"
## game minutes per real second (1 game hour = 1 real minute)
var time_scale := 1.0

var day := 1
var minute := 8.0 * 60.0

var health := 100.0
var food := 85.0
var hydration := 80.0
var energy := 90.0
var radiation := 0.0

var fuel := 22.0
var generator_on := true
var water := 120.0
var air_filter := 62.0
var air_quality := 100.0
var battery := 100.0
var battery_max := 100.0

var inventory := {}
## bunker storage (only reachable inside the bunker)
var stash := {}
var carry_max: float:
	get: return 30.0 + addv("carry")
## purchased bunker upgrades (ids of ItemDB.UPGRADES)
var upgrades: Array = []
## 0..3 — real-time bleeding level (stopped by bandages / medkits)
var bleeding := 0.0
var flags := {}
var dig := {}
var planters := {}
var built: Array = []
## Bunker furniture that ships with the level, rearranged by the player:
## key -> {p: [x, y, z], r: yaw, light: {on, c, l, s}}
var layout := {}
var radio_heard: Array = []
var locations: Array = ["factory"]
var containers := {}
var stats := {"expeditions": 0, "kills": 0, "crafted": 0, "harvests": 0, "days": 0}
var mask_filter_left := 0.0
var current_location := ""
var dead := false
var _ripe_notified := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not running or dead:
		return
	simulate(delta * time_scale, false)
	if bleeding > 0.0:
		damage(bleeding * 0.55 * delta, "bleed")
		bleeding = maxf(bleeding - delta / 50.0, 0.0)


# --------------------------------------------------------------------------
# New game / save / load
# --------------------------------------------------------------------------

func reset() -> void:
	running = false
	context = "intro"
	day = 1
	minute = 7.0 * 60.0 + 42.0
	health = 100.0
	food = 85.0
	hydration = 80.0
	energy = 90.0
	radiation = 0.0
	fuel = 22.0
	generator_on = true
	water = 120.0
	air_filter = 62.0
	air_quality = 100.0
	battery = 100.0
	battery_max = 100.0
	inventory = {"flashlight": 1, "canned_meat": 1, "water_bottle": 1}
	stash = {}
	bleeding = 0.0
	upgrades = []
	flags = {}
	dig = {}
	planters = {}
	built = []
	layout = {}
	radio_heard = []
	locations = ["factory"]
	containers = {}
	stats = {"expeditions": 0, "kills": 0, "crafted": 0, "harvests": 0, "days": 0}
	mask_filter_left = 0.0
	current_location = ""
	dead = false
	_ripe_notified = {}


func to_dict() -> Dictionary:
	return {
		"version": 1, "day": day, "minute": minute,
		"health": health, "food": food, "hydration": hydration, "energy": energy, "radiation": radiation,
		"fuel": fuel, "generator_on": generator_on, "water": water, "air_filter": air_filter,
		"air_quality": air_quality, "battery": battery, "battery_max": battery_max,
		"inventory": inventory, "stash": stash, "upgrades": upgrades, "flags": flags, "dig": dig, "planters": planters, "built": built, "layout": layout,
		"radio_heard": radio_heard, "locations": locations, "containers": containers, "stats": stats,
		"mask_filter_left": mask_filter_left,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	day = int(d.get("day", 1))
	minute = float(d.get("minute", 480.0))
	health = float(d.get("health", 100.0))
	food = float(d.get("food", 80.0))
	hydration = float(d.get("hydration", 80.0))
	energy = float(d.get("energy", 80.0))
	radiation = float(d.get("radiation", 0.0))
	fuel = float(d.get("fuel", 20.0))
	generator_on = bool(d.get("generator_on", true))
	water = float(d.get("water", 100.0))
	air_filter = float(d.get("air_filter", 60.0))
	air_quality = float(d.get("air_quality", 100.0))
	battery = float(d.get("battery", 100.0))
	battery_max = float(d.get("battery_max", 100.0))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		inventory[k] = int(inv[k])
	stash = {}
	var st: Dictionary = d.get("stash", {})
	for k in st:
		stash[k] = int(st[k])
	upgrades = d.get("upgrades", [])
	flags = d.get("flags", {})
	dig = d.get("dig", {})
	planters = d.get("planters", {})
	built = d.get("built", [])
	layout = d.get("layout", {})
	radio_heard = d.get("radio_heard", [])
	locations = d.get("locations", ["factory"])
	containers = d.get("containers", {})
	stats = d.get("stats", stats)
	mask_filter_left = float(d.get("mask_filter_left", 0.0))
	refresh_caps()


func save_game() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	from_dict(data)
	return true


# --------------------------------------------------------------------------
# Upgrades / comfort
# --------------------------------------------------------------------------

func has_up(id: String) -> bool:
	return upgrades.has(id)


## Product of all owned "mul_<key>" effects (1.0 when none).
func mul(key: String) -> float:
	var m := 1.0
	for id in upgrades:
		var e: Dictionary = ItemDB.UPGRADES.get(id, {}).get("effect", {})
		m *= float(e.get("mul_" + key, 1.0))
	return m


## Sum of all owned "add_<key>" effects.
func addv(key: String) -> float:
	var a := 0.0
	for id in upgrades:
		var e: Dictionary = ItemDB.UPGRADES.get(id, {}).get("effect", {})
		a += float(e.get("add_" + key, 0.0))
	return a


## Why an upgrade can't be bought yet ("" = it can).
func upgrade_block(id: String) -> String:
	var u: Dictionary = ItemDB.UPGRADES[id]
	if has_up(id):
		return "Deja construit"
	for r in u.get("req", []):
		if not has_up(r):
			return "Necesită: " + ItemDB.UPGRADES[r].name
	if u.has("dig") and int(dig.get(u.dig, 0)) < 3:
		return "Necesită: săparea secțiunii " + ("B (atelierul)" if u.dig == "sec_b" else "C (infirmeria)")
	if not has_all(u.cost):
		return "Materiale insuficiente"
	return ""


func buy_upgrade(id: String) -> bool:
	if upgrade_block(id) != "":
		return false
	var u: Dictionary = ItemDB.UPGRADES[id]
	consume(u.cost)
	simulate(float(u.get("hours", 2)) * 60.0, false)
	upgrades.append(id)
	refresh_caps()
	if u.effect.has("unlock_loc") and not locations.has("metro"):
		locations.append("metro")
		notify.emit("Locație nouă: %s" % ItemDB.LOCATIONS.metro.name, "good")
	notify.emit("Îmbunătățire finalizată: %s" % u.name, "good")
	return true


func refresh_caps() -> void:
	battery_max = 100.0 + 50.0 * building_count("battery_bank") + addv("battery")
	battery = minf(battery, battery_max)


## Comfort from furniture (0..40): better sleep and regeneration.
func comfort() -> float:
	var c := 0.0
	for b in built:
		c += float(ItemDB.BUILDABLES.get(b.get("type", ""), {}).get("comfort", 0.0))
	return minf(c, 40.0)


# --------------------------------------------------------------------------
# Inventory
# --------------------------------------------------------------------------

## Backpack count.
func count(id: String) -> int:
	return int(inventory.get(id, 0))


func stash_count(id: String) -> int:
	return int(stash.get(id, 0))


## Backpack + stash (stash only reachable inside the bunker).
func available(id: String) -> int:
	return count(id) + (stash_count(id) if context == "bunker" else 0)


func add(id: String, n: int = 1, silent := false, to_stash := false) -> void:
	if n <= 0:
		return
	var inv := stash if to_stash else inventory
	inv[id] = int(inv.get(id, 0)) + n
	inventory_changed.emit()
	if not silent:
		item_gained.emit(id, n, to_stash)


## Removes from the backpack only.
func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true


## Removes from the stash first, then the backpack (bunker), else backpack only.
func take(id: String, n: int = 1) -> bool:
	if available(id) < n:
		return false
	var left := n
	if context == "bunker":
		var s := mini(stash_count(id), left)
		if s > 0:
			stash[id] = stash_count(id) - s
			if stash[id] <= 0:
				stash.erase(id)
			left -= s
	if left > 0:
		inventory[id] = count(id) - left
		if inventory[id] <= 0:
			inventory.erase(id)
	inventory_changed.emit()
	return true


func has_all(cost: Dictionary) -> bool:
	for k in cost:
		if available(k) < int(cost[k]):
			return false
	return true


func consume(cost: Dictionary) -> bool:
	if not has_all(cost):
		return false
	for k in cost:
		take(k, int(cost[k]))
	return true


func move_to_stash(id: String, n: int) -> void:
	n = mini(n, count(id))
	if n <= 0:
		return
	remove(id, n)
	stash[id] = stash_count(id) + n
	inventory_changed.emit()


func move_to_backpack(id: String, n: int) -> void:
	n = mini(n, stash_count(id))
	if n <= 0:
		return
	stash[id] = stash_count(id) - n
	if stash[id] <= 0:
		stash.erase(id)
	inventory[id] = count(id) + n
	inventory_changed.emit()


const GEAR := ["gas_mask", "mask_filter", "hazmat_suit", "geiger", "axe", "pistol", "ammo_9mm", "flashlight", "shovel"]
const LOADOUT := {"gas_mask": 1, "mask_filter": 4, "hazmat_suit": 1, "geiger": 1, "axe": 1, "pistol": 1, "ammo_9mm": 40,
	"rifle": 1, "ammo_762": 60, "shotgun": 1, "shells_12": 16,
	"flashlight": 1, "bandage": 3, "medkit": 1, "antirad": 2, "water_bottle": 2, "canned_meat": 1}


## Before a raid: take essential gear from the stash into the backpack.
func auto_loadout() -> Array:
	var moved: Array = []
	for id in LOADOUT:
		var want: int = LOADOUT[id]
		var need := want - count(id)
		if need > 0 and stash_count(id) > 0:
			var n := mini(need, stash_count(id))
			move_to_backpack(id, n)
			moved.append("%s ×%d" % [ItemDB.item_name(id), n])
	return moved


## After a raid: everything that isn't gear goes into the stash.
func unload_to_stash() -> int:
	var n := 0
	for id in inventory.keys():
		var keep: int = LOADOUT.get(id, 0)
		var extra := count(id) - keep
		if extra > 0:
			move_to_stash(id, extra)
			n += extra
	return n


var _w_hash := 0
var _w_cache := -1.0


## Cached: the HUD and the player ask several times per frame.
func total_weight() -> float:
	var h := inventory.hash()
	if h == _w_hash and _w_cache >= 0.0:
		return _w_cache
	var w := 0.0
	for k in inventory:
		w += float(ItemDB.item(k).get("w", 0.1)) * count(k)
	_w_hash = h
	_w_cache = w
	return w


func stash_weight() -> float:
	var w := 0.0
	for k in stash:
		w += float(ItemDB.item(k).get("w", 0.1)) * stash_count(k)
	return w


func overweight() -> float:
	return maxf(total_weight() - carry_max, 0.0)


## Use a consumable (backpack first, then the stash in the bunker).
func use_item(id: String) -> bool:
	if available(id) <= 0:
		return false
	var it := ItemDB.item(id)
	match it.get("cat", ""):
		"food", "drink":
			take(id)
			food = clampf(food + float(it.get("food", 0)), 0, 100)
			hydration = clampf(hydration + float(it.get("water", 0)), 0, 100)
			Audio.sfx("drink" if it.get("cat") == "drink" else "eat", -4.0)
			notify.emit("Ai consumat: %s" % it.name, "info")
			return true
		"med":
			take(id)
			health = clampf(health + float(it.get("heal", 0)), 0, 100)
			if id in ["bandage", "medkit"]:
				bleeding = 0.0
			radiation = maxf(radiation - float(it.get("rad", 0)), 0)
			Audio.sfx("pickup", -4.0)
			notify.emit("Ai folosit: %s" % it.name, "info")
			return true
		"fuel":
			if context != "bunker":
				notify.emit("Combustibilul se toarnă în generator, în buncăr.", "warn")
				return false
			if fuel >= FUEL_MAX - 0.5:
				notify.emit("Rezervorul generatorului este plin.", "warn")
				return false
			take(id)
			fuel = minf(fuel + float(it.get("fuel", 10.0)), FUEL_MAX)
			notify.emit("Generator alimentat: %.0f / %.0f L" % [fuel, FUEL_MAX], "info")
			return true
	return false


# --------------------------------------------------------------------------
# Time & simulation
# --------------------------------------------------------------------------

func clock_text() -> String:
	var h := int(minute / 60.0) % 24
	var m := int(minute) % 60
	return "%02d:%02d" % [h, m]


func is_night() -> bool:
	var h := minute / 60.0
	return h < 6.0 or h >= 21.0


func power_state() -> String:
	if generator_on and fuel > 0.0:
		return "gen"
	if battery > 0.5:
		return "battery"
	return "none"


func grow_lamp_count() -> int:
	var n := 0
	for b in built:
		if b.get("type", "") == "grow_lamp":
			n += 1
	return n + 1  # the greenhouse ships with one lamp


func building_count(type: String) -> int:
	var n := 0
	for b in built:
		if b.get("type", "") == type:
			n += 1
	return n


func fuel_rate() -> float:
	## litres per game hour while the generator runs
	return (0.22 + 0.04 * grow_lamp_count() * mul("lamp_power") + 0.05 * building_count("water_collector") + light_power()) * mul("fuel")


## Extra generator load of the player-built lights that are switched on (L / game hour).
func light_power() -> float:
	var w := 0.0
	for b in built:
		var def: Dictionary = ItemDB.BUILDABLES.get(b.get("type", ""), {})
		var lc: Dictionary = b.get("light", {})
		if float(def.get("power", 0.0)) > 0.0 and bool(lc.get("on", true)):
			w += float(def.power) * float(lc.get("l", 1.0))
	return w


## Surface radiation multiplier — decays following the "7-10" rule of thumb.
func surface_rad_mult() -> float:
	return clampf(2.0 * pow(float(maxi(day, 1)), -0.9), 0.08, 2.0)


## Advance the world by `minutes` of game time.
func simulate(minutes: float, sleeping: bool) -> void:
	var left := minutes
	while left > 0.0001 and not dead:
		var step := minf(left, 20.0)
		_step(step / 60.0, sleeping)
		left -= step
		minute += step
		if minute >= 1440.0:
			minute -= 1440.0
			day += 1
			stats["days"] = day - 1
			new_day.emit(day)
			_check_radio()


func _step(h: float, sleeping: bool) -> void:
	var mul := 0.5 if sleeping else 1.0
	var exertion := 1.25 if context == "surface" else 1.0
	food = maxf(food - h * 100.0 / 72.0 * mul * exertion, 0.0)
	hydration = maxf(hydration - h * 100.0 / 40.0 * mul * exertion, 0.0)
	if sleeping:
		energy = minf(energy + h * 100.0 / 7.0 * (1.0 + comfort() / 200.0), 100.0)
	else:
		energy = maxf(energy - h * 100.0 / 18.0 * exertion, 0.0)

	# damage per cause, so the death screen names the one that actually killed you
	var starve := 0.0
	var rad_dmg := 0.0
	var air_dmg := 0.0
	if food <= 0.0:
		starve += h * 6.0
	if hydration <= 0.0:
		starve += h * 12.0
	if energy <= 0.0:
		starve += h * 1.0
	if radiation > 250.0:
		rad_dmg += h * (radiation - 250.0) * 0.012
	if radiation > 1000.0:
		rad_dmg += h * 30.0
	radiation = maxf(radiation - h * 0.35, 0.0)

	if context == "bunker" or sleeping:
		_bunker_step(h)
		if air_quality < 35.0:
			air_dmg += h * (35.0 - air_quality) * 0.18
	var dmg := starve + rad_dmg + air_dmg
	if food > 40.0 and hydration > 40.0 and radiation < 200.0 and dmg <= 0.0:
		var regen := (3.0 * mul("sleep_heal") * (1.0 + comfort() / 100.0)) if sleeping else 1.2
		health = minf(health + h * regen, 100.0)
	if dmg > 0.0:
		var reason := "starvation"
		if rad_dmg >= starve and rad_dmg >= air_dmg:
			reason = "radiation"
		elif air_dmg > starve:
			reason = "air"
		damage(dmg, reason)


func _bunker_step(h: float) -> void:
	var ps := power_state()
	if ps == "gen":
		fuel = maxf(fuel - h * fuel_rate(), 0.0)
		battery = minf(battery + h * 12.0, battery_max)
		air_filter = maxf(air_filter - h * 4.0 / 24.0 * mul("filter_wear"), 0.0)
		water = minf(water + h * 0.25 * building_count("water_collector"), WATER_MAX)
		if fuel <= 0.0:
			notify.emit("Generatorul s-a oprit: nu mai e combustibil!", "danger")
			Audio.sfx("power_down", -2.0)
	elif ps == "battery":
		battery = maxf(battery - h * 6.0 * 100.0 / battery_max, 0.0)
		air_filter = maxf(air_filter - h * 2.0 / 24.0 * mul("filter_wear"), 0.0)
	# passive sources (no power needed)
	water = minf(water + h * addv("water_day") / 24.0, WATER_MAX)
	var hour := minute / 60.0
	if addv("solar") > 0.0 and hour > 6.5 and hour < 19.5:
		battery = minf(battery + h * addv("solar"), battery_max)
	var target := 0.0
	match ps:
		"gen": target = 40.0 + air_filter * 0.6
		"battery": target = 25.0 + air_filter * 0.35
		_: target = 0.0
	var rate := 0.6 if target > air_quality else 0.08
	air_quality = lerpf(air_quality, target, minf(h * rate, 1.0))
	if air_filter < 20.0:
		radiation += h * (20.0 - air_filter) * 0.02 * surface_rad_mult()
	_crops_step(h, ps == "gen")


func _crops_step(h: float, gen: bool) -> void:
	for key in planters:
		var p: Dictionary = planters[key]
		var crop: String = p.get("crop", "")
		if crop == "" or p.get("dead", false):
			continue
		var info: Dictionary = ItemDB.CROPS.get(crop, {})
		if info.is_empty():
			continue
		var lit: bool = (not info.light) or (gen and bool(p.get("lit", false)))
		var wet := float(p.get("water", 0.0)) > 0.0
		if wet:
			p["water"] = maxf(float(p.get("water", 0.0)) - h * 100.0 / 30.0 * mul("crop_water"), 0.0)
			p["neglect"] = 0.0
		else:
			p["neglect"] = float(p.get("neglect", 0.0)) + h
			if float(p["neglect"]) > 24.0:
				p["dead"] = true
				notify.emit("O cultură de %s s-a uscat." % info.name.to_lower(), "danger")
				continue
		if wet and lit and float(p.get("growth", 0.0)) < 1.0:
			p["growth"] = minf(float(p.get("growth", 0.0)) + h / float(info.hours) * mul("growth"), 1.0)
			if float(p["growth"]) >= 1.0 and not _ripe_notified.has(key):
				_ripe_notified[key] = true
				notify.emit("%s sunt gata de recoltat!" % info.name, "good")


func damage(amount: float, reason := "") -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		dead = true
		running = false
		died.emit(reason)


## A broadcast is on air once its day has come (or, for answers, once its flag is set).
func _radio_due(msg: Dictionary) -> bool:
	if radio_heard.has(msg.id):
		return false
	if msg.has("req_flag"):
		return bool(flags.get(msg.req_flag, false))
	return int(msg.day) <= day


func _check_radio() -> void:
	for msg in ItemDB.RADIO:
		if _radio_due(msg):
			notify.emit("Radioul prinde un semnal nou...", "radio")
			return


func pending_radio() -> Array:
	var res: Array = []
	for msg in ItemDB.RADIO:
		if _radio_due(msg):
			res.append(msg)
	return res


func mark_radio_heard(msg: Dictionary) -> void:
	if not radio_heard.has(msg.id):
		radio_heard.append(msg.id)
	if msg.has("unlock") and not locations.has(msg.unlock):
		locations.append(msg.unlock)
		notify.emit("Locație nouă: %s" % ItemDB.LOCATIONS[msg.unlock].name, "good")
	if msg.id == "r7" and not flags.has("corbii"):
		flags["corbii"] = "threat"
		flags["corbii_deadline"] = day + 3
		notify.emit("Corbii cer provizii. Ai timp până în ziua %d (lada de lângă ecluză)." % (day + 3), "danger")


# --------------------------------------------------------------------------
# The Corbii: pay, or hold the door
# --------------------------------------------------------------------------

## What stands between the raiders and the stash: steel bars, alarm, sandbags, armoury.
func corbii_defense() -> float:
	return addv("defense") + minf(building_count("sandbags"), 4) * 0.5 + (1.0 if has_up("armory") else 0.0)


## Called every new day: the warning the night before, the raid when the deadline passes.
func corbii_tick() -> void:
	if String(flags.get("corbii", "")) != "threat":
		return
	var dl := int(flags.get("corbii_deadline", 99))
	if day == dl - 1 and has_up("alarm"):
		notify.emit("Senzorii de la intrare prind mișcare noaptea. Corbii dau târcoale.", "danger")
	if day >= dl:
		_corbii_raid()


func _corbii_raid() -> void:
	var defense := corbii_defense()
	if Game.args.has("trace"):
		print("[corbii] raid day=%d defense=%.1f stash=%d" % [day, defense, stash.size()])
	if defense >= 2.0:
		flags["corbii"] = "repelled"
		flags["corbii_repelled"] = true
		add("ammo_9mm", 12, true, true)
		add("bandage", 1, true, true)
		notify.emit("Noaptea, Corbii au încercat să spargă ușa. Barele au ținut. Au lăsat sânge, o cutie de cartușe și un bandaj.", "good")
		return
	flags["corbii"] = "raided"
	flags["corbii_raided"] = true
	var frac := clampf(0.45 - 0.12 * defense, 0.15, 0.45)
	var lost := 0
	for id in stash.keys():
		var it := ItemDB.item(id)
		if it.get("cat", "") == "weapon" or id in ["gas_mask", "hazmat_suit", "geiger", "flashlight", "shovel"]:
			continue
		var n := ceili(stash_count(id) * frac)
		if n > 0:
			stash[id] = stash_count(id) - n
			if stash_count(id) <= 0:
				stash.erase(id)
			lost += n
	fuel = maxf(fuel - fuel * 0.3, 0.0)
	inventory_changed.emit()
	notify.emit("Noaptea, Corbii au forțat ușa. Lipsesc %d obiecte din depozit și o treime din motorină.%s" % [lost, "" if defense > 0.0 else " Bare de oțel la ușă i-ar fi oprit."], "danger")


func available_locations() -> Array:
	var res: Array = []
	for id in ItemDB.LOCATIONS:
		var loc: Dictionary = ItemDB.LOCATIONS[id]
		var unlocked := locations.has(id) or (not _radio_gated(id) and day >= int(loc.day))
		if loc.has("req_up"):
			unlocked = has_up(loc.req_up)
		if unlocked:
			res.append(id)
	return res


func _radio_gated(loc_id: String) -> bool:
	for msg in ItemDB.RADIO:
		if msg.get("unlock", "") == loc_id:
			return true
	return false
