class_name Building
extends Node3D
## Enterable building for the surface maps, generated from a floor-plan template.
##
## Kinds: house (village house, 2–4 rooms, tin gable roof), ruin (burnt-out house),
## apartment (3-storey block, ground floor enterable), shop, garage, and the location
## landmarks: supermarket, hospital, police, factory, metro, barracks, depot, hq.
## Local frame: footprint centred on the origin, floor at y = 0, entrance on the +Z side.
## Rooms are rows of cells (front row first); every room is reachable through doorways.
## Walls, floors, roofs and the procedural furniture are merged per material (BoxBatch);
## loot sits only in furniture containers (fridges, cupboards, wardrobes, drawers, bags...).

const T := 0.24
const TI := 0.12
const STORY := 3.0
const FLOOR_Y := 0.04
const DOOR_W := 1.05
const DOOR_H := 2.15
const SILL := 0.9
const WIN_TOP := 2.05

## Furniture catalogue. w = along the wall, d = depth, h = height; tall = keeps clear of
## windows; loot = container kind (ItemDB.LOOT_KINDS); center = stands in the room middle;
## yaw = model front correction (models whose front is +X).
const FURN := {
	"counter": {"w": 1.8, "d": 0.6, "h": 0.92, "loot": "cupboard", "title": "Dulap de bucătărie"},
	"stove": {"w": 0.6, "d": 0.6, "h": 0.9},
	"fridge": {"model": "fridge_old", "tall": true, "loot": "fridge", "title": "Frigider"},
	"pantry": {"w": 0.8, "d": 0.5, "h": 2.0, "tall": true, "loot": "pantry", "title": "Bufet"},
	"wardrobe": {"model": "wardrobe_old", "w": 1.2, "d": 0.6, "h": 2.0, "tall": true, "loot": "wardrobe", "title": "Șifonier"},
	"hall_cabinet": {"w": 0.9, "d": 0.4, "h": 1.9, "tall": true, "loot": "wardrobe", "title": "Cuier cu dulap"},
	"nightstand": {"w": 0.45, "d": 0.4, "h": 0.55, "loot": "drawer", "title": "Noptieră"},
	"dresser": {"w": 1.0, "d": 0.48, "h": 0.85, "loot": "drawer", "title": "Comodă"},
	"bed": {"model": "bed_old", "long": "z", "w": 1.5, "d": 2.05, "h": 0.55},
	"hbed": {"w": 0.95, "d": 2.05, "h": 0.6},
	"bookshelf": {"w": 0.9, "d": 0.34, "h": 1.9, "tall": true, "loot": "shelf", "title": "Bibliotecă"},
	"tv": {"w": 0.9, "d": 0.45, "h": 0.5},
	"sofa": {"model": "sofa_old"},
	"soba": {"w": 0.95, "d": 0.7, "h": 1.75, "tall": true},
	"desk": {"w": 1.2, "d": 0.62, "h": 0.76, "loot": "drawer", "title": "Birou"},
	"bathtub": {"model": "bathtub_old", "long": "x", "w": 1.6, "d": 0.72, "h": 0.55},
	"sink": {"model": "sink_old", "w": 0.55, "d": 0.45, "h": 0.85},
	"toilet": {"w": 0.45, "d": 0.65, "h": 0.8},
	"medcab": {"w": 0.4, "d": 0.16, "h": 0.5, "mount": 1.35, "loot": "medicine", "title": "Dulăpior cu medicamente"},
	"bag": {"w": 0.65, "d": 0.4, "h": 0.32, "loot": "bag", "title": "Geantă"},
	"backpack": {"w": 0.38, "d": 0.3, "h": 0.5, "loot": "bag", "title": "Rucsac"},
	"mshelf": {"model": "metal_shelf", "tall": true, "loot": "shelf", "title": "Raft metalic"},
	"tshelf": {"model": "metal_shelf", "tall": true, "loot": "tools", "title": "Raft cu scule"},
	"medshelf": {"model": "metal_shelf", "tall": true, "loot": "medicine", "title": "Raft cu medicamente"},
	"locker": {"model": "locker", "tall": true, "loot": "locker", "title": "Dulap metalic"},
	"workbench": {"model": "workbench", "yaw": PI * 0.5, "loot": "tools", "title": "Banc de lucru"},
	"crate": {"model": "wooden_crate", "loot": "crate", "title": "Ladă"},
	"mcrate": {"model": "military_crate", "loot": "crate", "title": "Ladă militară"},
	"barrel": {"model": "oil_barrel"},
	"jerry": {"w": 0.62, "d": 0.35, "h": 0.5, "loot": "crate", "title": "Canistre"},
	"bunk": {"model": "bunk_bed"},
	"counter_shop": {"w": 1.8, "d": 0.7, "h": 1.0, "loot": "drawer", "title": "Tejghea"},
	"display_fridge": {"w": 0.9, "d": 0.7, "h": 1.9, "tall": true, "loot": "fridge", "title": "Vitrină frigorifică"},
	"bench_wall": {"model": "bench"},
	"table": {"model": "table_wood", "long": "x", "w": 1.2, "d": 0.8, "h": 0.76, "center": true},
	"lathe": {"w": 2.2, "d": 0.9, "h": 1.3},
}

## What goes into each room type, in placement order (ids of FURN).
const ROOMS := {
	"kitchen": ["counter", "fridge", "stove", "pantry", "table", "bag"],
	"hall": ["hall_cabinet", "dresser", "backpack"],
	"bedroom": ["bed", "wardrobe", "nightstand", "dresser", "bag"],
	"living": ["sofa", "tv", "bookshelf", "soba", "table", "backpack"],
	"bath": ["bathtub", "sink", "toilet", "medcab"],
	"storage": ["mshelf", "mshelf", "crate", "jerry", "barrel"],
	"office": ["desk", "locker", "mshelf", "medcab"],
	"shop": ["display_fridge", "mshelf", "mshelf", "counter_shop", "display_fridge"],
	"garage": ["workbench", "tshelf", "barrel", "jerry", "crate"],
	"ward": ["hbed", "hbed", "hbed", "nightstand", "medcab", "medshelf"],
	"reception": ["counter_shop", "bench_wall", "bench_wall", "mshelf"],
	"pharmacy": ["medshelf", "medshelf", "counter_shop", "medcab"],
	"storage_med": ["medshelf", "medshelf", "crate", "crate"],
	"lobby": ["counter_shop", "bench_wall", "locker"],
	"lockers": ["locker", "locker", "locker", "bench_wall"],
	"armory": ["mcrate", "mcrate", "locker", "locker", "mshelf"],
	"cells": ["bench_wall", "bench_wall"],
	"workshop": ["workbench", "workbench", "tshelf", "tshelf", "lathe", "barrel", "barrel", "crate", "crate"],
	"metro": ["counter_shop", "bench_wall", "bench_wall", "bench_wall", "locker"],
	"dorm": ["bunk", "bunk", "bunk", "locker", "locker", "backpack"],
	"depot": ["mcrate", "mcrate", "mcrate", "mshelf", "mshelf", "barrel", "jerry"],
	"market": ["display_fridge", "display_fridge", "display_fridge", "mshelf", "mshelf"],
	"stair": [],
}

var kind := "house"
## x = frontage (along the street), y = depth
var size := Vector2(9.0, 7.0)
var floors := 1
var height := STORY
var roof := "gable"
var sign_text := ""
var sign_color := Color(0.85, 0.85, 0.8)
var damaged := false
## pre-war building (intro): glazed windows, closed doors, nothing broken
var intact := false
## false = shell only (no furniture, no containers) for buildings seen from the street
var furnish := true
var rng: RandomNumberGenerator
## (kind: String) -> Dictionary of items for a new container
var loot: Callable
## unique per location + building, prefixes container keys (search state persists)
var key_prefix := "b"
var respawn_days := 6
## Materials: ext, int, trim, roof, plinth, floor_wood, floor_tile, floor_concrete,
## wood, wood_dark, metal, white, dark, fabric_a, fabric_b, glass
var mats := {}
var containers: Array[LootContainer] = []
var rooms: Array = []  # {rect: Rect2, type: String}
## local x of the street door (fences put their gate in front of it)
var entrance_x := 0.0

var _links: Array = []  # [room i, room j]
var _entry := 0
var _ops: Array = []  # openings {c: Vector2 (wall centre line), w, y0, y1, door: bool, ext: bool, along_x: bool}
var _placed: Array[Rect2] = []
var _keep: Array[Rect2] = []
var _b := BoxBatch.new()
## interior batch: furniture, debris (no shadows, hidden from afar)
var _f := BoxBatch.new()
const INTERIOR_RANGE := 45.0
var _n := 0
static var _size_cache := {}


func build() -> void:
	_plan()
	_place_openings()
	_build_floor()
	_build_walls()
	_build_top()
	if furnish:
		for i in rooms.size():
			_furnish(i)
	if damaged:
		_damage()
	_b.commit(self)
	_f.commit(self, false, INTERIOR_RANGE)


# --------------------------------------------------------------------------
# Floor plans
# --------------------------------------------------------------------------

## rows: [[depth, [[width, type], ...]], ...] front (+Z) to back; widths are rescaled to fit.
func _grid(rows: Array, entry: int) -> void:
	var total_d := 0.0
	for r in rows:
		total_d += float(r[0])
	var z := size.y * 0.5
	for ri in rows.size():
		var r: Array = rows[ri]
		var d: float = float(r[0]) / total_d * size.y
		var total_w := 0.0
		for c in r[1]:
			total_w += float(c[0])
		var x := -size.x * 0.5
		for c in r[1]:
			var w: float = float(c[0]) / total_w * size.x
			rooms.append({"rect": Rect2(x, z - d, w, d), "type": c[1], "row": ri})
			x += w
		z -= d
	_entry = entry
	# front row is chained; every other room opens into the room in front of it
	for i in rooms.size():
		var ri: Rect2 = rooms[i].rect
		if rooms[i].row == 0:
			if i + 1 < rooms.size() and rooms[i + 1].row == 0:
				_links.append([i, i + 1])
			continue
		var best := -1
		var best_o := 0.0
		for j in rooms.size():
			if rooms[j].row != rooms[i].row - 1:
				continue
			var rj: Rect2 = rooms[j].rect
			var o := minf(ri.end.x, rj.end.x) - maxf(ri.position.x, rj.position.x)
			if o > best_o:
				best_o = o
				best = j
		if best >= 0:
			_links.append([best, i])


func _plan() -> void:
	var r := rng
	match kind:
		"house", "ruin":
			var wl := r.randf_range(0.4, 0.5)
			if size.x < 8.6:
				_grid([[0.45, [[wl, "kitchen"], [1.0 - wl, "hall"]]], [0.55, [[1.0, "bedroom"]]]], 1)
			else:
				var wb := r.randf_range(0.42, 0.55)
				_grid([[0.45, [[wl, "kitchen"], [1.0 - wl, "hall"]]], [0.55, [[wb, "bedroom"], [1.0 - wb, "living"]]]], 1)
		"apartment":
			_grid([[0.56, [[7.4, "bedroom" if r.randf() < 0.5 else "living"], [3.2, "hall"], [7.4, "living"]]],
				[0.44, [[4.9, "kitchen"], [2.5, "bath"], [3.2, "stair"], [2.5, "bath"], [4.9, "kitchen"]]]], 1)
		"shop":
			_grid([[0.66, [[1.0, "shop"]]], [0.34, [[0.6, "storage"], [0.4, "office"]]]], 0)
		"garage":
			_grid([[1.0, [[1.0, "garage"]]]], 0)
		"supermarket":
			_grid([[0.7, [[1.0, "market"]]], [0.3, [[0.5, "storage"], [0.2, "office"], [0.3, "storage"]]]], 0)
		"hospital":
			_grid([[0.5, [[1, "ward"], [1, "office"], [1, "reception"], [1, "pharmacy"], [1, "ward"]]],
				[0.5, [[1, "ward"], [1, "storage_med"], [1, "bath"], [1, "storage_med"], [1, "ward"]]]], 2)
		"admin":
			_grid([[0.5, [[1, "office"], [0.8, "lobby"], [1, "office"]]], [0.5, [[1, "office"], [0.8, "office"], [1, "office"]]]], 1)
		"police", "hq":
			_grid([[0.5, [[1, "office"], [1, "lobby"], [1, "office"]]], [0.5, [[1, "lockers"], [1, "cells"], [1, "armory"]]]], 1)
		"factory":
			_grid([[0.72, [[1.0, "workshop"]]], [0.28, [[0.3, "office"], [0.4, "storage"], [0.3, "lockers"]]]], 0)
		"metro":
			_grid([[1.0, [[1.0, "metro"]]]], 0)
		"barracks":
			_grid([[1.0, [[1.0, "dorm"], [0.9, "lobby"], [1.0, "dorm"]]]], 1)
		"depot":
			_grid([[0.75, [[1.0, "depot"]]], [0.25, [[0.5, "armory"], [0.5, "office"]]]], 0)
		_:
			_grid([[1.0, [[1.0, "storage"]]]], 0)


# --------------------------------------------------------------------------
# Openings (doors and windows)
# --------------------------------------------------------------------------

func _place_openings() -> void:
	# interior doors on the shared edge of linked rooms
	for l in _links:
		var a: Rect2 = rooms[l[0]].rect
		var bb: Rect2 = rooms[l[1]].rect
		if absf(a.position.y - bb.end.y) < 0.01 or absf(a.end.y - bb.position.y) < 0.01:
			var zz := a.position.y if absf(a.position.y - bb.end.y) < 0.01 else a.end.y
			var x0 := maxf(a.position.x, bb.position.x) + 0.7
			var x1 := minf(a.end.x, bb.end.x) - 0.7
			if x1 > x0:
				_ops.append({"c": Vector2(rng.randf_range(x0, x1) if x1 - x0 > 0.4 else (x0 + x1) * 0.5, zz), "w": DOOR_W - 0.1, "y0": 0.0, "y1": DOOR_H, "door": true, "ext": false, "along_x": true})
		else:
			var xx := a.end.x if absf(a.end.x - bb.position.x) < 0.01 else a.position.x
			var z0 := maxf(a.position.y, bb.position.y) + 0.7
			var z1 := minf(a.end.y, bb.end.y) - 0.7
			if z1 > z0:
				_ops.append({"c": Vector2(xx, rng.randf_range(z0, z1) if z1 - z0 > 0.4 else (z0 + z1) * 0.5), "w": DOOR_W - 0.1, "y0": 0.0, "y1": DOOR_H, "door": true, "ext": false, "along_x": false})
	# entrance(s) on the street side
	var er: Rect2 = rooms[_entry].rect
	var fz := size.y * 0.5
	match kind:
		"garage":
			_ops.append({"c": Vector2(0, fz), "w": minf(2.8, size.x - 1.2), "y0": 0.0, "y1": 2.5, "door": true, "ext": true, "along_x": true, "big": true})
		"factory":
			_ops.append({"c": Vector2(-size.x * 0.18, fz), "w": 4.0, "y0": 0.0, "y1": 4.2, "door": true, "ext": true, "along_x": true, "big": true})
			_ops.append({"c": Vector2(size.x * 0.25, fz), "w": DOOR_W, "y0": 0.0, "y1": DOOR_H, "door": true, "ext": true, "along_x": true})
		"supermarket", "metro":
			for x in [-2.2, 2.2] if kind == "supermarket" else [0.0]:
				_ops.append({"c": Vector2(x, fz), "w": 2.0, "y0": 0.0, "y1": 2.4, "door": true, "ext": true, "along_x": true, "glass": true})
		"depot":
			_ops.append({"c": Vector2(0, fz), "w": 3.6, "y0": 0.0, "y1": 3.4, "door": true, "ext": true, "along_x": true, "big": true})
		_:
			var cx := clampf(er.get_center().x + rng.randf_range(-0.5, 0.5), er.position.x + 0.8, er.end.x - 0.8)
			_ops.append({"c": Vector2(cx, fz), "w": DOOR_W, "y0": 0.0, "y1": DOOR_H, "door": true, "ext": true, "along_x": true})
	for o in _ops:
		if o.ext and o.door:
			entrance_x = (o.c as Vector2).x
			break
	# village houses often have a back door to the yard
	if kind in ["house", "ruin"] and rng.randf() < 0.45:
		for i in rooms.size():
			var rr: Rect2 = rooms[i].rect
			if absf(rr.position.y + size.y * 0.5) < 0.01 and rooms[i].type != "bath":
				_ops.append({"c": Vector2(rr.get_center().x, -size.y * 0.5), "w": DOOR_W - 0.1, "y0": 0.0, "y1": DOOR_H, "door": true, "ext": true, "along_x": true})
				break
	# windows on every exterior wall stretch of each room
	for i in rooms.size():
		var rt: String = rooms[i].type
		var rr: Rect2 = rooms[i].rect
		for side in _ext_sides(rr):
			_windows_on(side, rt)


## Exterior edges of a room: [start, end, along_x] on the footprint boundary.
func _ext_sides(r: Rect2) -> Array:
	var res: Array = []
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	if absf(r.end.y - hz) < 0.01:
		res.append([Vector2(r.position.x, hz), Vector2(r.end.x, hz), true])
	if absf(r.position.y + hz) < 0.01:
		res.append([Vector2(r.position.x, -hz), Vector2(r.end.x, -hz), true])
	if absf(r.position.x + hx) < 0.01:
		res.append([Vector2(-hx, r.position.y), Vector2(-hx, r.end.y), false])
	if absf(r.end.x - hx) < 0.01:
		res.append([Vector2(hx, r.position.y), Vector2(hx, r.end.y), false])
	return res


func _windows_on(side: Array, room_type: String) -> void:
	var a: Vector2 = side[0]
	var b: Vector2 = side[1]
	var along_x: bool = side[2]
	var length := a.distance_to(b)
	var w := 1.1
	var y0 := SILL
	var y1 := WIN_TOP
	var spacing := 2.9
	match room_type:
		"storage", "storage_med", "stair", "cells", "lockers", "armory", "garage", "depot":
			w = 0.7
			y0 = 1.55
			y1 = 2.1
			spacing = 4.5
		"bath":
			w = 0.6
			y0 = 1.5
			y1 = 2.05
		"shop", "market":
			if along_x and a.y > 0.0:
				w = 2.2
				y0 = 0.5
				y1 = 2.45
				spacing = 3.0
		"workshop", "metro":
			w = 2.0
			y0 = 2.2
			y1 = minf(height - 0.6, 4.6)
			spacing = 3.6
	var n := int((length - 1.2) / spacing) + 1
	if length < w + 1.0:
		return
	n = clampi(n, 1, 12)
	for k in n:
		var t := (k + 0.5) / n
		var c := a.lerp(b, t)
		var clash := false
		for o in _ops:
			if o.ext and (o.c as Vector2).distance_to(c) < float(o.w) * 0.5 + w * 0.5 + 0.35:
				clash = true
				break
		if not clash:
			_ops.append({"c": c, "w": w, "y0": y0, "y1": y1, "door": false, "ext": true, "along_x": along_x,
				"boards": kind in ["house", "ruin", "garage"] and rng.randf() < 0.3})


# --------------------------------------------------------------------------
# Shell
# --------------------------------------------------------------------------

func _floor_mat(t: String) -> Material:
	match t:
		"kitchen", "bath", "market", "shop":
			return mats.floor_tile
		"ward", "pharmacy", "reception", "lobby", "storage_med", "office", "metro", "cells":
			return mats.get("floor_lino", mats.floor_tile)
		"bedroom", "living", "hall", "dorm":
			if kind == "hospital":
				return mats.get("floor_lino", mats.floor_tile)
			return mats.get("floor_parquet", mats.floor_wood) if kind == "apartment" else mats.floor_wood
	return mats.floor_concrete


func _build_floor() -> void:
	# foundation / plinth (hides uneven ground around the pad)
	_b.box(mats.plinth, Vector3(0, -0.45, 0), Vector3(size.x + 0.3, 0.9, size.y + 0.3))
	_b.collider(Transform3D(Basis(), Vector3(0, FLOOR_Y - 0.15, 0)), Vector3(size.x, 0.3, size.y))
	for rm in rooms:
		var r: Rect2 = rm.rect
		_b.box(_floor_mat(rm.type), Vector3(r.get_center().x, FLOOR_Y - 0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y))


func _ops_on(along_x: bool, coord: float, ext: bool) -> Array:
	var res: Array = []
	for o in _ops:
		if o.along_x == along_x and o.ext == ext and absf((o.c.y if along_x else o.c.x) - coord) < 0.05:
			res.append(o)
	return res


func _build_walls() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var walls := [
		[Vector2(-hx - T * 0.5, hz), Vector2(hx + T * 0.5, hz), true, Vector2(0, 1)],
		[Vector2(-hx - T * 0.5, -hz), Vector2(hx + T * 0.5, -hz), true, Vector2(0, -1)],
		[Vector2(-hx, -hz + T * 0.5), Vector2(-hx, hz - T * 0.5), false, Vector2(-1, 0)],
		[Vector2(hx, -hz + T * 0.5), Vector2(hx, hz - T * 0.5), false, Vector2(1, 0)],
	]
	for w in walls:
		var along_x: bool = w[2]
		var ops := _ops_on(along_x, (w[0] as Vector2).y if along_x else (w[0] as Vector2).x, true)
		var hgt := height
		if kind == "ruin":
			hgt = height * rng.randf_range(0.55, 1.0)
		_wall(w[0], w[1], 0.0, hgt, T, ops, w[3], true)
		for o in ops:
			_frame(o, w[3])
		# upper storeys: solid with dummy windows
		for f in range(1, floors):
			var fy := height + (f - 1) * STORY
			_wall(w[0], w[1], fy, STORY, T, [], w[3], false)
			_fake_windows(w[0], w[1], fy, w[3])
			_b.box(mats.trim, Vector3(((w[0] + w[1]) * 0.5).x, fy, ((w[0] + w[1]) * 0.5).y) + Vector3(w[3].x, 0, w[3].y) * (T * 0.5 + 0.03),
				Vector3(w[0].distance_to(w[1]) + 0.1 if along_x else 0.08, 0.14, 0.08 if along_x else w[0].distance_to(w[1]) + 0.1))
	# partitions between linked or neighbouring rooms
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			_partition(rooms[i].rect, rooms[j].rect)


func _partition(a: Rect2, bb: Rect2) -> void:
	var h := height if kind != "ruin" else height * 0.8
	if absf(a.position.y - bb.end.y) < 0.01 or absf(a.end.y - bb.position.y) < 0.01:
		var zz := a.position.y if absf(a.position.y - bb.end.y) < 0.01 else a.end.y
		var x0 := maxf(a.position.x, bb.position.x)
		var x1 := minf(a.end.x, bb.end.x)
		if x1 - x0 > 0.3:
			_wall(Vector2(x0, zz), Vector2(x1, zz), 0.0, h, TI, _ops_on(true, zz, false).filter(func(o) -> bool: return o.c.x > x0 and o.c.x < x1), Vector2.ZERO, true)
	elif absf(a.end.x - bb.position.x) < 0.01 or absf(a.position.x - bb.end.x) < 0.01:
		var xx := a.end.x if absf(a.end.x - bb.position.x) < 0.01 else a.position.x
		var z0 := maxf(a.position.y, bb.position.y)
		var z1 := minf(a.end.y, bb.end.y)
		if z1 - z0 > 0.3:
			_wall(Vector2(xx, z0), Vector2(xx, z1), 0.0, h, TI, _ops_on(false, xx, false).filter(func(o) -> bool: return o.c.y > z0 and o.c.y < z1), Vector2.ZERO, true)


## Straight wall from a to b (centre line) with openings cut out. outward != 0: exterior
## wall (outer half in the facade material, inner half plastered).
func _wall(a: Vector2, bb: Vector2, y0: float, h: float, thick: float, ops: Array, outward: Vector2, collide: bool) -> void:
	var dir := (bb - a).normalized()
	var length := a.distance_to(bb)
	var cuts: Array = []
	for o in ops:
		var t: float = (o.c - a).dot(dir)
		cuts.append([t - float(o.w) * 0.5, t + float(o.w) * 0.5, float(o.y0), minf(float(o.y1), h)])
	cuts.sort_custom(func(x, y) -> bool: return x[0] < y[0])
	var t := 0.0
	for c in cuts:
		if c[0] > t:
			_piece(a, dir, t, c[0], y0, y0 + h, thick, outward, collide)
		if c[2] > 0.001:
			_piece(a, dir, c[0], c[1], y0, y0 + c[2], thick, outward, collide)
		if c[3] < h - 0.001:
			_piece(a, dir, c[0], c[1], y0 + c[3], y0 + h, thick, outward, collide)
		t = maxf(t, c[1])
	if t < length:
		_piece(a, dir, t, length, y0, y0 + h, thick, outward, collide)


func _piece(a: Vector2, dir: Vector2, t0: float, t1: float, ya: float, yb: float, thick: float, outward: Vector2, collide: bool) -> void:
	if t1 - t0 < 0.01 or yb - ya < 0.01:
		return
	var mid := a + dir * ((t0 + t1) * 0.5)
	var length := t1 - t0
	var along_x := absf(dir.x) > 0.5
	var c := Vector3(mid.x, (ya + yb) * 0.5, mid.y)
	if outward == Vector2.ZERO:
		_b.box(mats.int, c, Vector3(length if along_x else thick, yb - ya, thick if along_x else length), 0.0, collide)
		return
	var o3 := Vector3(outward.x, 0, outward.y)
	var half := thick * 0.5
	var sz := Vector3(length if along_x else half, yb - ya, half if along_x else length)
	_b.box(mats.ext, c + o3 * half * 0.5, sz)
	_b.box(mats.int, c - o3 * half * 0.5, sz)
	if collide:
		_b.collider(Transform3D(Basis(), c), Vector3(length if along_x else thick, yb - ya, thick if along_x else length))


## Frame, sill, boards / door leaf for an exterior opening.
func _frame(o: Dictionary, outward: Vector2) -> void:
	var along_x: bool = o.along_x
	var c: Vector2 = o.c
	var w: float = o.w
	var o3 := Vector3(outward.x, 0, outward.y)
	var face := Vector3(c.x, 0, c.y) + o3 * (T * 0.5 + 0.02)
	var side := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var y0: float = o.y0
	var y1: float = o.y1
	var fw := 0.07
	var dims := func(len_side: float, hgt: float) -> Vector3:
		return Vector3(len_side, hgt, 0.06) if along_x else Vector3(0.06, hgt, len_side)
	# jambs + head
	for s in [-1.0, 1.0]:
		_b.box(mats.trim, face + side * s * (w * 0.5 + fw * 0.5) + Vector3(0, (y0 + y1) * 0.5, 0), dims.call(fw, y1 - y0 + fw))
	_b.box(mats.trim, face + Vector3(0, y1 + fw * 0.5, 0), dims.call(w + fw * 2.0, fw))
	if not o.door:
		_b.box(mats.trim, face + o3 * 0.04 + Vector3(0, y0 - 0.03, 0), dims.call(w + 0.16, 0.06) + o3.abs() * 0.08)
		if intact:
			# glazing + a mullion
			var mid := Vector3(c.x, (y0 + y1) * 0.5, c.y)
			_b.box(mats.glass, mid, dims.call(w, y1 - y0) - o3.abs() * 0.03, 0.0, true)
			_b.box(mats.trim, mid + o3 * 0.02, dims.call(0.05, y1 - y0))
			return
		if o.get("boards", false):
			for k in 3:
				var yy := lerpf(y0 + 0.2, y1 - 0.2, k / 2.0)
				var tilt := rng.randf_range(-0.25, 0.25)
				var xf := Transform3D(Basis(o3, tilt), face + o3 * 0.05 + Vector3(0, yy, 0))
				var bs := Vector3(w + 0.3, 0.12, 0.025) if along_x else Vector3(0.025, 0.12, w + 0.3)
				_b.box_xf(mats.wood, xf, bs)
		var cin := Vector3(c.x, 0, c.y) - o3 * (T * 0.5 + 0.06)
		if kind in ["house", "apartment", "hospital", "police"] and not o.get("boards", false):
			# curtain rod with two panels drawn aside (one torn down now and then)
			_f.cylinder(mats.metal, cin + Vector3(0, y1 + 0.12, 0) - side * (w * 0.5 + 0.2), cin + Vector3(0, y1 + 0.12, 0) + side * (w * 0.5 + 0.2), 0.012, 6)
			var cm: Material = mats.fabric_b if rng.randf() < 0.5 else mats.fabric_a
			for s in [-1.0, 1.0]:
				if rng.randf() < 0.2:
					_f.box(cm, cin + side * (s * w * 0.45) - o3 * 0.3 + Vector3(0, 0.1, 0), dims.call(0.5, 0.2) + o3.abs() * 0.5, rng.randf() * 0.5)
					continue
				_f.box(cm, cin + side * (s * (w * 0.5 - 0.12)) - o3 * 0.1 + Vector3(0, (y1 + 0.1 + 0.3) * 0.5, 0), dims.call(w * 0.28, y1 - 0.2) + o3.abs() * 0.16)
		if kind in ["house", "apartment", "hospital", "police"] and not o.get("big", false):
			# cast-iron radiator under the sill
			var rc := cin - o3 * 0.04 + Vector3(0, 0.42, 0)
			var ribs := maxi(4, int(w / 0.14))
			for k in ribs:
				var off := (k + 0.5) / ribs - 0.5
				_f.box(_xmat("radiator", Color(0.82, 0.8, 0.74), 0.55, 0.2), rc + side * (off * w * 0.85), dims.call(0.06, 0.55) + o3.abs() * 0.12)
			_f.cylinder(_xmat("radiator", Color(0.82, 0.8, 0.74), 0.55, 0.2), rc - side * (w * 0.45) + Vector3(0, 0.3, 0) - o3 * 0.03, rc + side * (w * 0.45) + Vector3(0, 0.3, 0) - o3 * 0.03, 0.02, 6)
		return
	if not o.get("big", false) and not o.get("glass", false):
		# light switch beside the door, inside
		var sw := Vector3(c.x, 1.1, c.y) - o3 * (T * 0.5 + 0.006) + side * (w * 0.5 + 0.24)
		_f.box(_xmat("switch", Color(0.9, 0.9, 0.86), 0.5), sw, dims.call(0.08, 0.08) + o3.abs() * 0.012)
	if intact:
		# closed door (glass for shop fronts)
		var mid := Vector3(c.x, (y0 + y1) * 0.5, c.y)
		_b.box(mats.glass if o.get("glass", false) else mats.wood_dark, mid, dims.call(w, y1 - y0) - o3.abs() * 0.0, 0.0, true)
		_b.box(mats.metal, mid + o3 * 0.05 + side * (w * 0.35) - Vector3(0, 0.1, 0), dims.call(0.04, 0.2) + o3.abs() * 0.04)
		return
	if o.get("big", false):
		# rolled-up shutter box above wide doors
		_b.box(mats.metal, face + o3 * 0.12 + Vector3(0, y1 + 0.25, 0), dims.call(w + 0.3, 0.4) + o3.abs() * 0.2)
		return
	if o.get("glass", false):
		return
	# door leaf: ajar inside, fallen, or gone
	var roll := rng.randf()
	var inward := -o3
	var hinge := Vector3(c.x, 0, c.y) + side * (-w * 0.5 + 0.03) + inward * (T * 0.5)
	if roll < 0.6:
		# swung open into the room, 70..100 degrees
		var ang := rng.randf_range(1.2, 1.75)
		var ldir := (side * cos(ang) + inward * sin(ang)).normalized()
		var basis := Basis(ldir, Vector3.UP, ldir.cross(Vector3.UP))
		var center := hinge + ldir * (w * 0.5) + Vector3(0, DOOR_H * 0.5, 0)
		_b.box_xf(mats.wood_dark, Transform3D(basis, center), Vector3(w - 0.05, DOOR_H - 0.05, 0.045))
	elif roll < 0.8:
		var center := Vector3(c.x, 0.06, c.y) + inward * 1.3
		_b.box(mats.wood_dark, center, Vector3(w - 0.05, 0.045, DOOR_H - 0.1) if along_x else Vector3(DOOR_H - 0.1, 0.045, w - 0.05), rng.randf_range(-0.3, 0.3))


func _fake_windows(a: Vector2, bb: Vector2, y0: float, outward: Vector2) -> void:
	var length := a.distance_to(bb)
	var along_x := absf(a.y - bb.y) < 0.01
	var n := int(length / 3.0)
	if n < 1:
		return
	var o3 := Vector3(outward.x, 0, outward.y)
	for k in n:
		var c := a.lerp(bb, (k + 0.5) / n)
		var face := Vector3(c.x, y0 + 1.5, c.y) + o3 * (T * 0.5)
		var w := 1.2
		var dim := Vector3(w, 1.2, 0.04) if along_x else Vector3(0.04, 1.2, w)
		_b.box(mats.glass, face + o3 * 0.005, dim)
		var fr := Vector3(w + 0.14, 0.07, 0.06) if along_x else Vector3(0.06, 0.07, w + 0.14)
		_b.box(mats.trim, face + o3 * 0.02 + Vector3(0, 0.63, 0), fr)
		_b.box(mats.trim, face + o3 * 0.04 + Vector3(0, -0.63, 0), fr + o3.abs() * 0.06)
		if kind == "apartment" and absf(outward.y - 1.0) < 0.01 and k % 2 == 0:
			# balcony slab + rail on the street side
			var bal := Vector3(c.x, y0 + 0.05, c.y) + o3 * (T * 0.5 + 0.55)
			_b.box(mats.plinth, bal, Vector3(2.4, 0.14, 1.1))
			_b.box(mats.metal, bal + o3 * 0.52 + Vector3(0, 0.55, 0), Vector3(2.4, 0.9, 0.04))


## Ceilings, roof, parapet, chimney, sign.
func _build_top() -> void:
	var top := height + (floors - 1) * STORY
	if kind != "ruin":
		_b.box(mats.int, Vector3(0, height - 0.07, 0), Vector3(size.x - T, 0.14, size.y - T))
	if kind == "ruin":
		return
	if roof == "gable":
		var pitch := deg_to_rad(28.0)
		var over := 0.45
		var s := size.y * 0.5 + over
		var rise := s * tan(pitch)
		var slope_len := s / cos(pitch)
		var drop := over * tan(pitch)
		var gap_from := 99
		if damaged:
			gap_from = rng.randi_range(0, 2)
		for side in [1.0, -1.0]:
			for seg in 3:
				var seg_w := (size.x + 0.8) / 3.0
				var x := -(size.x + 0.8) * 0.5 + seg_w * (seg + 0.5)
				var center := Vector3(x, top + rise * 0.5 - drop + 0.04, side * s * 0.5)
				if seg == gap_from and side > 0.0:
					# collapsed patch: bare rafters
					for k in 4:
						var rx := x - seg_w * 0.4 + seg_w * 0.8 * k / 3.0
						_b.box_xf(mats.wood_dark, Transform3D(Basis(Vector3.RIGHT, pitch * side), Vector3(rx, top + rise * 0.5 - drop, side * s * 0.5)), Vector3(0.08, 0.1, slope_len))
					continue
				_b.box_xf(mats.roof, Transform3D(Basis(Vector3.RIGHT, pitch * side), center), Vector3(seg_w + 0.01, 0.06, slope_len))
		var ridge := top + size.y * 0.5 * tan(pitch)
		for gx in [-size.x * 0.5, size.x * 0.5]:
			_b.tri(mats.ext, Vector3(gx, top, size.y * 0.5), Vector3(gx, top, -size.y * 0.5), Vector3(gx, ridge, 0))
		_b.box(mats.roof, Vector3(0, ridge + 0.06, 0), Vector3(size.x + 0.8, 0.08, 0.16))
		# brick chimney
		var cx := rng.randf_range(-size.x * 0.3, size.x * 0.3)
		_b.box(mats.chimney, Vector3(cx, ridge + 0.1, -0.6), Vector3(0.45, 1.6, 0.45))
	else:
		_b.box(mats.roof, Vector3(0, top + 0.12, 0), Vector3(size.x + 0.2, 0.24, size.y + 0.2))
		for e in [[Vector3(0, 0, size.y * 0.5), Vector3(size.x + 0.2, 0.6, 0.18)], [Vector3(0, 0, -size.y * 0.5), Vector3(size.x + 0.2, 0.6, 0.18)],
				[Vector3(size.x * 0.5, 0, 0), Vector3(0.18, 0.6, size.y)], [Vector3(-size.x * 0.5, 0, 0), Vector3(0.18, 0.6, size.y)]]:
			_b.box(mats.ext, e[0] + Vector3(0, top + 0.5, 0), e[1])
		if kind in ["apartment", "hospital", "supermarket", "factory"]:
			_b.box(mats.metal, Vector3(size.x * 0.25, top + 0.8, -size.y * 0.2), Vector3(1.6, 1.1, 1.2))
	if sign_text != "":
		var l := Label3D.new()
		l.text = sign_text
		l.font = Assets.font("heading")
		l.font_size = 96
		l.pixel_size = 0.012 if sign_text.length() > 8 else 0.02
		l.modulate = sign_color
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.7)
		l.position = Vector3(0, minf(height, STORY) + (0.55 if floors == 1 else 0.4), size.y * 0.5 + T * 0.5 + 0.05)
		add_child(l)


# --------------------------------------------------------------------------
# Furnishing
# --------------------------------------------------------------------------

## Interior rect of a room (inside the wall faces).
func _inner(r: Rect2) -> Rect2:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var l := (T if absf(r.position.x + hx) < 0.01 else TI) * 0.5
	var rt := (T if absf(r.end.x - hx) < 0.01 else TI) * 0.5
	var bk := (T if absf(r.position.y + hz) < 0.01 else TI) * 0.5
	var fr := (T if absf(r.end.y - hz) < 0.01 else TI) * 0.5
	return Rect2(r.position.x + l, r.position.y + bk, r.size.x - l - rt, r.size.y - bk - fr)


func _furnish(i: int) -> void:
	var rm: Dictionary = rooms[i]
	var r := _inner(rm.rect)
	_keep.clear()
	for o in _ops:
		if not o.door:
			continue
		var c: Vector2 = o.c
		var w: float = float(o.w) + 0.5
		_keep.append(Rect2(c.x - w * 0.5, c.y - 1.15, w, 2.3) if o.along_x else Rect2(c.x - 1.15, c.y - w * 0.5, 2.3, w))
	match rm.type:
		"market":
			_market(r)
		"stair":
			_stairs(r)
		"cells":
			_cell_bars(r)
	_dress_room(i)
	_grime(i)
	var list: Array = ROOMS.get(rm.type, [])
	for id in list:
		if kind == "ruin" and rng.randf() < 0.45:
			continue
		if id in ["bag", "backpack"] and rng.randf() < 0.45:
			continue
		var spec: Dictionary = FURN[id]
		if spec.get("center", false):
			_place_center(id, spec, r)
		else:
			_place_wall(id, spec, r)
	if kind == "ruin" or (damaged and rng.randf() < 0.4):
		debris(_f, rng, Vector3(r.get_center().x + rng.randf_range(-0.8, 0.8), FLOOR_Y, r.get_center().y + rng.randf_range(-0.8, 0.8)), 0.9, [mats.int, mats.plinth, mats.chimney], 16)


## A catalogue entry uses its 3D model when the model exists, the box version otherwise
## (entries with both are the ones whose models come from the asset pipeline on demand).
func _has_model(spec: Dictionary) -> bool:
	return spec.has("model") and Assets.has_model(spec.model)


## Yaw that lays the model's long axis along the entry's "long" axis ("x" = along the
## wall, "z" = into the room), plus the entry's own yaw.
func _model_yaw(spec: Dictionary) -> float:
	var yaw := float(spec.get("yaw", 0.0))
	if spec.has("long") and _size_cache.has(spec.model):
		var raw: Vector3 = _size_cache[spec.model]
		var long_x := raw.x >= raw.z
		if (spec.long == "z" and long_x) or (spec.long == "x" and not long_x):
			yaw += PI * 0.5
	return yaw


func _spec_size(id: String, spec: Dictionary) -> Vector3:
	if _has_model(spec):
		if not _size_cache.has(spec.model):
			var m := Assets.model(spec.model)
			_size_cache[spec.model] = Assets.model_aabb(m).size
			m.free()
		var sz: Vector3 = _size_cache[spec.model]
		if absf(fmod(_model_yaw(spec), PI)) > 0.1:
			sz = Vector3(sz.z, sz.y, sz.x)
		return sz
	return Vector3(spec.w, spec.h, spec.d)


func _free(foot: Rect2, r: Rect2) -> bool:
	if not r.grow(0.01).encloses(foot):
		return false
	for p in _placed:
		if p.intersects(foot):
			return false
	for k in _keep:
		if k.intersects(foot):
			return false
	return true


func _place_wall(id: String, spec: Dictionary, r: Rect2) -> void:
	var sz := _spec_size(id, spec)
	var w := sz.x
	var d := sz.z
	var walls := [
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), r.size.x, Vector2(0, -1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 0), r.size.x, Vector2(0, 1)],
		[Vector2(r.position.x, r.position.y), Vector2(0, 1), r.size.y, Vector2(1, 0)],
		[Vector2(r.end.x, r.end.y), Vector2(0, -1), r.size.y, Vector2(-1, 0)],
	]
	var order := [0, 1, 2, 3]
	for k in 4:
		var j := rng.randi_range(k, 3)
		var tmp = order[k]
		order[k] = order[j]
		order[j] = tmp
	var mount: float = float(spec.get("mount", 0.0))
	for wi in order:
		var wl: Array = walls[wi]
		var o: Vector2 = wl[0]
		var dir: Vector2 = wl[1]
		var length: float = wl[2]
		var inward: Vector2 = wl[3]
		if length < w + 0.04:
			continue
		var cands: Array = [0.03, length - w - 0.03]
		for k in 6:
			cands.append(rng.randf_range(0.03, length - w - 0.03))
		for t0 in cands:
			var mid: Vector2 = o + dir * (t0 + w * 0.5) + inward * (d * 0.5 + 0.02)
			var foot := Rect2(mid - Vector2(absf(dir.x) * w + absf(inward.x) * d, absf(dir.y) * w + absf(inward.y) * d) * 0.5,
				Vector2(absf(dir.x) * w + absf(inward.x) * d, absf(dir.y) * w + absf(inward.y) * d))
			if mount > 0.0:
				if not _wall_clear(o, dir, inward, t0, w, mount, mount + sz.y):
					continue
			else:
				if not _free(foot, r):
					continue
				if (spec.get("tall", false) or sz.y > SILL) and not _wall_clear(o, dir, inward, t0, w, 0.0, sz.y):
					continue
				_placed.append(foot.grow(0.04))
			var yaw := atan2(inward.x, inward.y)
			_spawn(id, spec, Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, FLOOR_Y + mount, mid.y)), sz)
			return


## True when no opening on this wall overlaps [t0, t0 + w] between heights y0..y1.
func _wall_clear(o: Vector2, dir: Vector2, inward: Vector2, t0: float, w: float, y0: float, y1: float) -> bool:
	for op in _ops:
		var c: Vector2 = op.c
		var rel := c - o
		if absf(rel.dot(inward)) > T:
			continue
		var t := rel.dot(dir)
		if t + float(op.w) * 0.5 + 0.1 > t0 and t - float(op.w) * 0.5 - 0.1 < t0 + w and float(op.y0) < y1 and float(op.y1) > y0:
			return false
	return true


func _place_center(id: String, spec: Dictionary, r: Rect2) -> void:
	var sz := _spec_size(id, spec)
	for k in 8:
		var c := r.get_center() + Vector2(rng.randf_range(-r.size.x * 0.15, r.size.x * 0.15), rng.randf_range(-r.size.y * 0.15, r.size.y * 0.15))
		var yaw := 0.0 if r.size.x >= r.size.y else PI * 0.5
		var span := Vector2(sz.x, sz.z) if yaw == 0.0 else Vector2(sz.z, sz.x)
		var foot := Rect2(c - span * 0.5 - Vector2(0.55, 0.55), span + Vector2(1.1, 1.1))
		if _free(foot, r):
			_placed.append(foot)
			_spawn(id, spec, Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, FLOOR_Y, c.y)), sz)
			return


## Builds piece `id` at xf (local +Z = front, origin = footprint centre on the floor).
## Procedural furniture goes into the interior batch (no shadows, hidden past 45 m).
func _spawn(id: String, spec: Dictionary, xf: Transform3D, sz: Vector3) -> void:
	if _has_model(spec):
		var mxf := xf * Transform3D(Basis(Vector3.UP, _model_yaw(spec)), Vector3.ZERO)
		_interior(Geo.prop(self, spec.model, mxf.origin, mxf.basis.get_euler().y))
		if spec.has("loot"):
			_container(xf, sz, spec.loot, spec.title)
		if id == "table":
			for s in [-1.0, 1.0]:
				if rng.randf() < 0.8:
					_interior(Geo.prop(self, "chair", (xf * Transform3D(Basis(), Vector3(s * (sz.x * 0.5 + 0.25), 0, rng.randf_range(-0.15, 0.15)))).origin,
						xf.basis.get_euler().y - s * PI * 0.5 + rng.randf_range(-0.4, 0.4)))
		return
	var g := func(mat: Material, c: Vector3, s: Vector3) -> void:
		_f.box_xf(mat, xf * Transform3D(Basis(), c), s)
	var solid := func(c: Vector3, s: Vector3) -> void:
		_f.collider(xf * Transform3D(Basis(), c), s)
	match id:
		"counter":
			g.call(mats.wood, Vector3(0, 0.43, 0), Vector3(sz.x, 0.86, sz.z - 0.04))
			g.call(mats.dark, Vector3(0, 0.885, 0.01), Vector3(sz.x + 0.02, 0.04, sz.z + 0.02))
			for k in 3:
				g.call(mats.wood_dark, Vector3(-sz.x * 0.5 + sz.x * (k + 0.5) / 3.0, 0.45, sz.z * 0.5 - 0.01), Vector3(sz.x / 3.0 - 0.04, 0.7, 0.02))
			g.call(mats.metal, Vector3(sz.x * 0.25, 0.91, 0.02), Vector3(0.5, 0.03, 0.38))
			g.call(mats.white, Vector3(0, 1.45, -sz.z * 0.5 + 0.17), Vector3(sz.x, 0.65, 0.34))
		"stove":
			g.call(mats.white, Vector3(0, 0.44, 0), Vector3(sz.x, 0.88, sz.z))
			g.call(mats.dark, Vector3(0, 0.4, sz.z * 0.5), Vector3(sz.x - 0.1, 0.4, 0.02))
			for k in 4:
				g.call(mats.dark, Vector3(-0.13 + 0.26 * (k % 2), 0.89, -0.12 + 0.24 * (k / 2)), Vector3(0.16, 0.02, 0.16))
			solid.call(Vector3(0, 0.45, 0), sz)
		"fridge", "display_fridge":
			g.call(mats.white, Vector3(0, sz.y * 0.5, 0), sz)
			g.call(mats.dark, Vector3(0, sz.y * 0.62, sz.z * 0.5 + 0.005), Vector3(sz.x - 0.02, 0.012, 0.01))
			g.call(mats.metal, Vector3(sz.x * 0.38, sz.y * 0.5, sz.z * 0.5 + 0.03), Vector3(0.03, 0.35, 0.04))
			if id == "display_fridge":
				g.call(mats.glass, Vector3(0, sz.y * 0.52, sz.z * 0.5 + 0.01), Vector3(sz.x - 0.12, sz.y * 0.7, 0.02))
		"pantry", "wardrobe", "hall_cabinet":
			g.call(mats.wood, Vector3(0, sz.y * 0.5, 0), sz)
			g.call(mats.wood_dark, Vector3(0, sz.y * 0.5, sz.z * 0.5 + 0.005), Vector3(0.015, sz.y - 0.1, 0.01))
			for s in [-1.0, 1.0]:
				g.call(mats.metal, Vector3(s * 0.06, sz.y * 0.52, sz.z * 0.5 + 0.02), Vector3(0.02, 0.14, 0.03))
			g.call(mats.wood_dark, Vector3(0, sz.y + 0.02, 0), Vector3(sz.x + 0.06, 0.04, sz.z + 0.04))
		"nightstand", "dresser":
			g.call(mats.wood, Vector3(0, sz.y * 0.5, 0), sz)
			var rows := 1 if id == "nightstand" else 3
			for k in rows:
				g.call(mats.wood_dark, Vector3(0, sz.y * (k + 0.5) / rows, sz.z * 0.5 + 0.005), Vector3(sz.x - 0.06, sz.y / rows - 0.05, 0.012))
		"desk":
			g.call(mats.wood, Vector3(0, sz.y - 0.02, 0), Vector3(sz.x, 0.04, sz.z))
			g.call(mats.wood, Vector3(-sz.x * 0.5 + 0.23, sz.y * 0.5, 0), Vector3(0.45, sz.y - 0.04, sz.z))
			g.call(mats.wood_dark, Vector3(sz.x * 0.5 - 0.03, sz.y * 0.5, 0), Vector3(0.04, sz.y, sz.z))
			for k in 3:
				g.call(mats.wood_dark, Vector3(-sz.x * 0.5 + 0.23, sz.y * (k + 0.5) / 3.0, sz.z * 0.5 + 0.005), Vector3(0.39, sz.y / 3.0 - 0.05, 0.012))
			if rng.randf() < 0.5:
				_interior(Geo.prop(self, "crt_computer", (xf * Transform3D(Basis(), Vector3(sz.x * 0.15, sz.y, -0.05))).origin, xf.basis.get_euler().y, "none", 0.9))
		"bed":
			g.call(mats.wood_dark, Vector3(0, 0.2, 0), Vector3(sz.x, 0.25, sz.z))
			g.call(mats.white, Vector3(0, 0.38, 0.03), Vector3(sz.x - 0.08, 0.14, sz.z - 0.1))
			g.call(mats.fabric_a, Vector3(0, 0.46, 0.25), Vector3(sz.x - 0.02, 0.05, sz.z * 0.7))
			g.call(mats.white, Vector3(0, 0.5, -sz.z * 0.5 + 0.28), Vector3(sz.x - 0.3, 0.1, 0.35))
			g.call(mats.wood_dark, Vector3(0, 0.55, -sz.z * 0.5 + 0.03), Vector3(sz.x, 1.0, 0.06))
			solid.call(Vector3(0, 0.27, 0), Vector3(sz.x, 0.54, sz.z))
		"hbed":
			g.call(mats.metal, Vector3(0, 0.3, 0), Vector3(sz.x, 0.08, sz.z))
			for s in [-1.0, 1.0]:
				g.call(mats.metal, Vector3(0, 0.45 if s < 0 else 0.3, s * (sz.z * 0.5 - 0.03)), Vector3(sz.x, 0.9 if s < 0 else 0.6, 0.04))
			g.call(mats.white, Vector3(0, 0.4, 0.02), Vector3(sz.x - 0.06, 0.12, sz.z - 0.12))
			g.call(mats.fabric_b, Vector3(0, 0.47, 0.25), Vector3(sz.x - 0.04, 0.03, sz.z * 0.55))
			solid.call(Vector3(0, 0.3, 0), Vector3(sz.x, 0.6, sz.z))
		"bookshelf":
			g.call(mats.wood_dark, Vector3(0, sz.y * 0.5, -sz.z * 0.5 + 0.01), Vector3(sz.x, sz.y, 0.02))
			for s in [-1.0, 1.0]:
				g.call(mats.wood_dark, Vector3(s * (sz.x * 0.5 - 0.01), sz.y * 0.5, 0), Vector3(0.02, sz.y, sz.z))
			for k in 5:
				var y := 0.05 + k * 0.45
				g.call(mats.wood_dark, Vector3(0, y, 0), Vector3(sz.x, 0.02, sz.z))
				if k < 4:
					var x := -sz.x * 0.5 + 0.05
					while x < sz.x * 0.5 - 0.12:
						var bw := rng.randf_range(0.03, 0.07)
						var bh := rng.randf_range(0.2, 0.3)
						if rng.randf() < 0.75:
							g.call(mats.fabric_a if rng.randf() < 0.5 else mats.fabric_b, Vector3(x + bw * 0.5, y + 0.01 + bh * 0.5, 0.02), Vector3(bw, bh, 0.22))
						x += bw + 0.005
		"mshelf", "tshelf", "medshelf":
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					g.call(mats.metal, Vector3(sx * (sz.x * 0.5 - 0.02), sz.y * 0.5, sz2 * (sz.z * 0.5 - 0.02)), Vector3(0.035, sz.y, 0.035))
			for k in 5:
				var y := 0.08 + k * 0.44
				g.call(mats.metal, Vector3(0, y, 0), Vector3(sz.x, 0.025, sz.z))
				if k < 4:
					for j in rng.randi_range(1, 4):
						var bw := rng.randf_range(0.12, 0.28)
						var bh := rng.randf_range(0.1, 0.3)
						var m: Material = [mats.wood, mats.white, mats.fabric_a, mats.dark, mats.fabric_b][rng.randi() % 5]
						g.call(m, Vector3(rng.randf_range(-sz.x * 0.5 + bw, sz.x * 0.5 - bw), y + 0.012 + bh * 0.5, rng.randf_range(-0.06, 0.06)), Vector3(bw, bh, rng.randf_range(0.15, 0.3)))
		"locker":
			g.call(mats.locker, Vector3(0, sz.y * 0.5, 0), sz)
			for k in 2:
				g.call(mats.dark, Vector3(-sz.x / 6.0 + k * sz.x / 3.0, sz.y * 0.5, sz.z * 0.5 + 0.004), Vector3(0.01, sz.y - 0.08, 0.01))
			for k in 3:
				var dx := -sz.x / 3.0 + k * sz.x / 3.0
				for v in 3:
					g.call(mats.dark, Vector3(dx, sz.y - 0.18 - v * 0.05, sz.z * 0.5 + 0.004), Vector3(0.16, 0.012, 0.01))
				g.call(mats.metal, Vector3(dx + 0.1, sz.y * 0.5, sz.z * 0.5 + 0.02), Vector3(0.025, 0.1, 0.03))
		"workbench":
			g.call(mats.wood_dark, Vector3(0, 0.87, 0), Vector3(sz.x, 0.06, sz.z))
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					g.call(mats.metal, Vector3(sx * (sz.x * 0.5 - 0.05), 0.42, sz2 * (sz.z * 0.5 - 0.05)), Vector3(0.06, 0.84, 0.06))
			g.call(mats.wood, Vector3(0, 0.2, 0), Vector3(sz.x - 0.1, 0.03, sz.z - 0.1))
			g.call(mats.wood, Vector3(0, 1.35, -sz.z * 0.5 + 0.02), Vector3(sz.x, 0.8, 0.03))
			for k in 6:
				g.call(mats.metal if k % 2 == 0 else mats.dark, Vector3(-sz.x * 0.4 + k * sz.x * 0.16, 1.35 + rng.randf_range(-0.15, 0.15), -sz.z * 0.5 + 0.06), Vector3(0.04, rng.randf_range(0.18, 0.4), 0.03))
			g.call(mats.dark, Vector3(sz.x * 0.4, 0.97, sz.z * 0.35), Vector3(0.16, 0.14, 0.2))
			for j in rng.randi_range(1, 3):
				g.call(mats.fabric_b, Vector3(rng.randf_range(-sz.x * 0.4, sz.x * 0.2), 0.95, rng.randf_range(-0.1, 0.15)), Vector3(rng.randf_range(0.15, 0.3), 0.1, 0.15))
		"crate":
			g.call(mats.wood, Vector3(0, sz.y * 0.5, 0), sz)
			for k in 3:
				g.call(mats.wood_dark, Vector3(0, 0.08 + k * (sz.y - 0.16) * 0.5, sz.z * 0.5 + 0.006), Vector3(sz.x, 0.06, 0.012))
				g.call(mats.wood_dark, Vector3(0, 0.08 + k * (sz.y - 0.16) * 0.5, -sz.z * 0.5 - 0.006), Vector3(sz.x, 0.06, 0.012))
		"mcrate":
			g.call(mats.olive, Vector3(0, sz.y * 0.5, 0), sz)
			for s in [-1.0, 1.0]:
				g.call(mats.dark, Vector3(s * sz.x * 0.3, sz.y * 0.5, 0), Vector3(0.05, sz.y + 0.01, sz.z + 0.01))
			g.call(mats.dark, Vector3(0, sz.y * 0.5, sz.z * 0.5 + 0.006), Vector3(0.12, 0.06, 0.012))
		"jerry":
			for k in 2:
				var cm: Material = mats.red if k == 0 else mats.olive
				g.call(cm, Vector3(-0.15 + k * 0.3, 0.22, 0), Vector3(0.17, 0.44, 0.33))
				g.call(cm, Vector3(-0.15 + k * 0.3, 0.47, -0.06), Vector3(0.05, 0.06, 0.16))
		"sofa":
			g.call(mats.fabric_a, Vector3(0, 0.2, 0.02), Vector3(sz.x, 0.25, sz.z - 0.04))
			for s in [-1.0, 1.0]:
				g.call(mats.fabric_a, Vector3(s * sz.x * 0.25, 0.39, 0.06), Vector3(sz.x * 0.5 - 0.22, 0.14, sz.z - 0.28))
				g.call(mats.fabric_a, Vector3(s * (sz.x * 0.5 - 0.09), 0.36, 0.0), Vector3(0.18, 0.5, sz.z))
			g.call(mats.fabric_a, Vector3(0, 0.6, -sz.z * 0.5 + 0.1), Vector3(sz.x, 0.55, 0.2))
			g.call(mats.wood_dark, Vector3(0, 0.04, 0), Vector3(sz.x - 0.1, 0.08, sz.z - 0.1))
			solid.call(Vector3(0, 0.3, 0), Vector3(sz.x, 0.6, sz.z))
		"gondola":
			g.call(mats.white, Vector3(0, 0.06, 0), Vector3(sz.x, 0.12, sz.z))
			g.call(mats.metal, Vector3(0, sz.y * 0.5, 0), Vector3(0.04, sz.y, sz.z))
			for s in [-1.0, 1.0]:
				for k in 4:
					var y := 0.3 + k * 0.38
					g.call(mats.white, Vector3(s * sz.x * 0.25, y, 0), Vector3(sz.x * 0.5 - 0.04, 0.02, sz.z))
					var zz := -sz.z * 0.5 + 0.1
					while zz < sz.z * 0.5 - 0.15:
						var pw := rng.randf_range(0.1, 0.2)
						if rng.randf() < 0.55:
							_product(xf, Vector3(s * sz.x * 0.25 + rng.randf_range(-0.12, 0.12), y + 0.01, zz + pw * 0.5), pw)
						zz += pw
			# what the scavengers knocked down
			for k in rng.randi_range(2, 6):
				_product(xf, Vector3(rng.randf_range(-sz.x * 0.9, sz.x * 0.9), FLOOR_Y, rng.randf_range(-sz.z * 0.5, sz.z * 0.5)), 0.14, true)
		"tv":
			g.call(mats.wood_dark, Vector3(0, 0.25, 0), sz)
			_interior(Geo.prop(self, "crt_computer", (xf * Transform3D(Basis(), Vector3(0, 0.5, 0))).origin, xf.basis.get_euler().y, "none"))
			solid.call(Vector3(0, 0.25, 0), sz)
		"soba":
			g.call(mats.white, Vector3(0, sz.y * 0.5, 0), sz)
			g.call(mats.dark, Vector3(0, 0.55, sz.z * 0.5 + 0.005), Vector3(0.36, 0.3, 0.01))
			g.call(mats.white, Vector3(0, sz.y + 0.04, 0), Vector3(sz.x + 0.06, 0.08, sz.z + 0.06))
			solid.call(Vector3(0, sz.y * 0.5, 0), sz)
		"bathtub":
			g.call(mats.white, Vector3(0, sz.y * 0.5, 0), sz)
			g.call(mats.metal, Vector3(0, sz.y + 0.002, 0), Vector3(sz.x - 0.12, 0.004, sz.z - 0.12))
			solid.call(Vector3(0, sz.y * 0.5, 0), sz)
		"sink":
			g.call(mats.white, Vector3(0, 0.4, -0.05), Vector3(0.18, 0.8, 0.18))
			g.call(mats.white, Vector3(0, 0.82, 0), Vector3(sz.x, 0.12, sz.z))
			g.call(mats.glass, Vector3(0, 1.45, -sz.z * 0.5 + 0.01), Vector3(0.45, 0.55, 0.02))
			solid.call(Vector3(0, 0.45, 0), Vector3(sz.x, 0.9, sz.z))
		"toilet":
			g.call(mats.white, Vector3(0, 0.2, 0.05), Vector3(0.36, 0.4, 0.5))
			g.call(mats.white, Vector3(0, 0.6, -sz.z * 0.5 + 0.1), Vector3(0.42, 0.4, 0.18))
			solid.call(Vector3(0, 0.4, 0), Vector3(0.42, 0.8, sz.z))
		"medcab":
			g.call(mats.white, Vector3(0, sz.y * 0.5, 0), sz)
			g.call(mats.glass, Vector3(0, sz.y * 0.5, sz.z * 0.5 + 0.004), Vector3(sz.x - 0.06, sz.y - 0.06, 0.01))
			g.call(mats.red, Vector3(0, sz.y * 0.75, sz.z * 0.5 + 0.01), Vector3(0.08, 0.025, 0.01))
			g.call(mats.red, Vector3(0, sz.y * 0.75, sz.z * 0.5 + 0.01), Vector3(0.025, 0.08, 0.01))
		"bag":
			var bag := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.16
			cap.height = sz.x
			cap.radial_segments = 10
			cap.rings = 3
			bag.mesh = cap
			bag.material_override = mats.fabric_b if rng.randf() < 0.5 else mats.dark
			add_child(bag)
			bag.transform = xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.16, 0))
			_interior(bag)
			g.call(mats.dark, Vector3(0, 0.32, 0), Vector3(0.22, 0.03, 0.05))
		"backpack":
			g.call(mats.fabric_b, Vector3(0, 0.22, 0), Vector3(0.34, 0.44, 0.2))
			g.call(mats.fabric_a, Vector3(0, 0.4, 0.05), Vector3(0.35, 0.12, 0.2))
			g.call(mats.dark, Vector3(0, 0.15, 0.12), Vector3(0.26, 0.18, 0.06))
		"counter_shop":
			g.call(mats.wood, Vector3(0, sz.y * 0.5, 0), sz)
			g.call(mats.dark, Vector3(0, sz.y + 0.02, 0), Vector3(sz.x + 0.04, 0.04, sz.z + 0.04))
			if rng.randf() < 0.6:
				_interior(Geo.prop(self, "crt_computer", (xf * Transform3D(Basis(), Vector3(-sz.x * 0.25, sz.y + 0.04, 0))).origin, xf.basis.get_euler().y + PI, "none", 0.8))
		"table":
			g.call(mats.wood, Vector3(0, sz.y - 0.025, 0), Vector3(sz.x, 0.05, sz.z))
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					g.call(mats.wood_dark, Vector3(sx * (sz.x * 0.5 - 0.06), sz.y * 0.5, sz2 * (sz.z * 0.5 - 0.06)), Vector3(0.05, sz.y, 0.05))
			solid.call(Vector3(0, sz.y * 0.5, 0), sz)
			for s in [-1.0, 1.0]:
				if rng.randf() < 0.8:
					_interior(Geo.prop(self, "chair", (xf * Transform3D(Basis(), Vector3(s * (sz.x * 0.5 + 0.25), 0, rng.randf_range(-0.15, 0.15)))).origin,
						xf.basis.get_euler().y - s * PI * 0.5 + rng.randf_range(-0.4, 0.4)))
		"lathe":
			g.call(mats.metal, Vector3(0, 0.45, 0), Vector3(sz.x, 0.9, sz.z * 0.7))
			g.call(mats.dark, Vector3(-sz.x * 0.3, 1.05, 0), Vector3(0.6, 0.4, 0.5))
			g.call(mats.dark, Vector3(0.2, 0.98, 0), Vector3(1.2, 0.12, 0.12))
			solid.call(Vector3(0, 0.6, 0), Vector3(sz.x, 1.2, sz.z))
	if spec.has("loot"):
		var c := _container(xf, sz, spec.loot, spec.title)
		_opening_part(c, id, sz)


## One shop product at `p` (furniture space): a can with a label, a carton, a bottle or a
## bag; `fallen` lays it on its side with a random spin.
func _product(xf: Transform3D, p: Vector3, slot_w: float, fallen := false) -> void:
	var labels := [_xmat("lbl_red", Color(0.55, 0.12, 0.1), 0.5), _xmat("lbl_blue", Color(0.15, 0.25, 0.45), 0.5), _xmat("lbl_yellow", Color(0.7, 0.55, 0.15), 0.5),
		_xmat("lbl_green", Color(0.2, 0.38, 0.2), 0.5), _xmat("lbl_cream", Color(0.75, 0.7, 0.55), 0.6)]
	var lbl: Material = labels[rng.randi() % labels.size()]
	var roll := rng.randf()
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	if fallen:
		spin = Basis.from_euler(Vector3(PI * 0.5, rng.randf() * TAU, 0.0))
	var local := Transform3D(spin, p)
	if roll < 0.4:
		# tin can: metal body, paper label around the middle
		var rr := rng.randf_range(0.034, 0.044)
		var hh := rng.randf_range(0.09, 0.12)
		if fallen:
			local.origin.y += rr
		var a := xf * local * Vector3.ZERO
		var b := xf * local * Vector3(0, hh, 0)
		_f.cylinder(mats.metal, a, b, rr, 10)
		_f.cylinder(lbl, a.lerp(b, 0.12), a.lerp(b, 0.88), rr + 0.003, 10)
	elif roll < 0.7:
		# carton
		var bs := Vector3(minf(slot_w - 0.02, rng.randf_range(0.08, 0.16)), rng.randf_range(0.12, 0.24), rng.randf_range(0.05, 0.1))
		if fallen:
			local.origin.y += bs.z * 0.5
		var cm: Material = lbl if rng.randf() < 0.6 else _xmat("cardboard", Color(0.6, 0.48, 0.32), 0.95)
		_f.box_xf(cm, xf * local * Transform3D(Basis(), Vector3(0, bs.y * 0.5 if not fallen else 0.0, 0)), bs)
	elif roll < 0.9:
		# bottle with a cap
		var hh := rng.randf_range(0.2, 0.3)
		if fallen:
			local.origin.y += 0.03
		var a := xf * local * Vector3.ZERO
		var b := xf * local * Vector3(0, hh, 0)
		var bg := _xmat_alpha("bottle_glass", Color(0.45, 0.55, 0.35, 0.55)) if rng.randf() < 0.6 else _xmat_alpha("bottle_clear", Color(0.75, 0.8, 0.8, 0.4))
		_f.cylinder(bg, a, b, 0.03, 8)
		_f.cylinder(bg, b, xf * local * Vector3(0, hh + 0.05, 0), 0.014, 6)
		_f.cylinder(lbl, xf * local * Vector3(0, hh + 0.05, 0), xf * local * Vector3(0, hh + 0.07, 0), 0.015, 6)
	else:
		# bag of something
		var bs := Vector3(rng.randf_range(0.1, 0.16), rng.randf_range(0.14, 0.2), 0.06)
		if fallen:
			local.origin.y += 0.03
		_f.box_xf(lbl, xf * local * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, bs.y * 0.5 if not fallen else 0.0, 0)), bs)


## Translucent stains: damp along the base of the walls, drips under the windows, mould
## in the ceiling corners of wet rooms and ruins.
static func _xmat_alpha(key: String, col: Color) -> Material:
	if not _xm.has(key):
		var m := Geo.color_mat(col, 0.95)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_BACK
		_xm[key] = m
	return _xm[key]


func _grime(i: int) -> void:
	var rm: Dictionary = rooms[i]
	var t: String = rm.type
	var h := height if kind != "ruin" else height * 0.8
	var damp := _xmat_alpha("damp", Color(0.08, 0.06, 0.04, 0.32))
	var mould := _xmat_alpha("mould", Color(0.06, 0.09, 0.05, 0.4))
	var wet := t in ["bath", "kitchen", "ward", "storage"] or kind == "ruin" or damaged
	for e in _room_edges(i):
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n3 := Vector3(e[2].x, 0, e[2].y)
		var along_x: bool = e[3]
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		# rising damp along the base
		for k in rng.randi_range(1, 3 if wet else 2):
			var sw := rng.randf_range(0.5, 1.6)
			var sh := rng.randf_range(0.15, 0.55 if wet else 0.35)
			var mid := a + dir * rng.randf_range(sw * 0.5, maxf(sw * 0.5, length - sw * 0.5))
			_f.box(damp, Vector3(mid.x, FLOOR_Y + 0.09 + sh * 0.5, mid.y) + n3 * 0.022, Vector3(sw, sh, 0.004) if along_x else Vector3(0.004, sh, sw))
		# mould in the top corners of wet rooms
		if wet and rng.randf() < 0.6:
			var corner := a if rng.randf() < 0.5 else b
			var toward := dir if corner == a else -dir
			for k in 2:
				var mw := rng.randf_range(0.3, 0.7)
				var mh := rng.randf_range(0.2, 0.45)
				var c := corner + toward * (mw * 0.5 + rng.randf_range(0.0, 0.15))
				_f.box(mould, Vector3(c.x, h - 0.22 - mh * 0.5 - k * 0.1, c.y) + n3 * 0.024, Vector3(mw, mh, 0.004) if along_x else Vector3(0.004, mh, mw))
	# drips under the windows of the outer walls
	for side in _ext_sides(rm.rect):
		var along_x: bool = side[2]
		for o in _ops_on(along_x, (side[0] as Vector2).y if along_x else (side[0] as Vector2).x, true):
			if o.door or rng.randf() < 0.4:
				continue
			var c2: Vector2 = o.c
			var inward := (Vector2(rm.rect.get_center()) - c2).normalized()
			var n3 := Vector3(inward.x, 0, inward.y)
			var dw: float = float(o.w) * rng.randf_range(0.5, 0.9)
			var dh := rng.randf_range(0.4, 0.8)
			_f.box(damp, Vector3(c2.x, float(o.y0) - dh * 0.5 - 0.02, c2.y) + n3 * (T * 0.5 + 0.026), Vector3(dw, dh, 0.004) if along_x else Vector3(0.004, dh, dw))


## The part of a container that moves when it is searched: a door leaf, a drawer or a
## lid (separate small meshes, animated by the LootContainer).
func _opening_part(c: LootContainer, id: String, sz: Vector3) -> void:
	var front := sz.z * 0.5 + 0.015
	match id:
		"fridge", "display_fridge":
			_leaf(c, mats.white, Vector3(sz.x - 0.03, sz.y - 0.05, 0.03), Vector3(sz.x * 0.5 - 0.015, sz.y * 0.5, front), -1.0)
		"pantry", "hall_cabinet":
			_leaf(c, mats.wood, Vector3(sz.x - 0.03, sz.y - 0.06, 0.025), Vector3(sz.x * 0.5 - 0.015, sz.y * 0.5, front), -1.0)
		"wardrobe":
			_leaf(c, mats.wood, Vector3(sz.x * 0.5 - 0.02, sz.y - 0.06, 0.025), Vector3(-sz.x * 0.5 + 0.015, sz.y * 0.5, front), 1.0)
			_leaf(c, mats.wood, Vector3(sz.x * 0.5 - 0.02, sz.y - 0.06, 0.025), Vector3(sz.x * 0.5 - 0.015, sz.y * 0.5, front), -1.0)
		"locker":
			_leaf(c, mats.locker, Vector3(sz.x / 3.0 - 0.02, sz.y - 0.08, 0.02), Vector3(-sz.x / 6.0, sz.y * 0.5, front), 1.0)
		"medcab":
			_leaf(c, mats.glass, Vector3(sz.x - 0.04, sz.y - 0.04, 0.012), Vector3(-sz.x * 0.5 + 0.02, sz.y * 0.5, front), 1.0)
		"nightstand", "dresser", "desk", "counter", "counter_shop", "workbench":
			var rows := 1 if id == "nightstand" else 3
			var dh := (sz.y / rows - 0.05) if id in ["nightstand", "dresser"] else 0.16
			var dw := (sz.x - 0.06) if id in ["nightstand", "dresser"] else minf(0.42, sz.x * 0.4)
			var dy := sz.y * (rows - 0.5) / rows if id in ["nightstand", "dresser"] else sz.y - 0.14
			var dx := 0.0 if id in ["nightstand", "dresser", "desk"] else sz.x * 0.25
			if id == "desk":
				dx = -sz.x * 0.5 + 0.23
				dw = 0.39
				dy = sz.y * 5.0 / 6.0
				dh = sz.y / 3.0 - 0.05
			var drawer := Node3D.new()
			c.add_child(drawer)
			drawer.position = Vector3(dx, dy, front)
			_part_mesh(drawer, mats.wood_dark, Vector3(dw, dh, 0.02), Vector3.ZERO)
			_part_mesh(drawer, mats.wood, Vector3(dw - 0.04, dh - 0.03, 0.3), Vector3(0, -0.01, -0.16))
			c.openers.append({"node": drawer, "pos": Vector3(0, 0, 0.3)})
		"crate", "mcrate":
			var hinge := Node3D.new()
			c.add_child(hinge)
			hinge.position = Vector3(0, sz.y + 0.015, -sz.z * 0.5)
			_part_mesh(hinge, mats.wood if id == "crate" else mats.olive, Vector3(sz.x + 0.02, 0.03, sz.z + 0.02), Vector3(0, 0, sz.z * 0.5))
			c.openers.append({"node": hinge, "rot": Vector3(-1.25, 0, 0)})
	if c.searched:
		c.set_open_instant()


func _leaf(c: LootContainer, mat: Material, leaf: Vector3, hinge_pos: Vector3, swing: float) -> void:
	var hinge := Node3D.new()
	c.add_child(hinge)
	hinge.position = hinge_pos
	_part_mesh(hinge, mat, leaf, Vector3(swing * leaf.x * 0.5, 0, 0))
	_part_mesh(hinge, mats.metal, Vector3(0.025, 0.12, 0.03), Vector3(swing * (leaf.x - 0.08), 0, 0.025))
	c.openers.append({"node": hinge, "rot": Vector3(0, swing * 1.55, 0)})


func _part_mesh(parent: Node3D, mat: Material, s: Vector3, off: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = off
	parent.add_child(mi)
	_interior(mi)
	return mi


# --------------------------------------------------------------------------
# Room dressing: the cheap details that make a bare box read as a lived-in room
# (skirting, painted dado / tiles, cornice, ceiling with its lamp, curtains, radiators,
# switches, rugs, pictures, clocks, and the clutter of a place left in a hurry).
# Everything goes into the interior batch: no extra draw calls, hidden beyond 45 m.
# --------------------------------------------------------------------------

static var _xm := {}  # extra materials shared by every building
var _paint: Material


static func _xmat(key: String, col: Color, rough := 0.85, metal := 0.0) -> Material:
	if not _xm.has(key):
		_xm[key] = Geo.color_mat(col, rough, metal)
	return _xm[key]


## Lower-wall finish: tiles in wet rooms, the building's paint colour elsewhere.
func _dado_mat(t: String) -> Material:
	if t in ["kitchen", "bath", "ward", "pharmacy", "storage_med", "market"]:
		return mats.get("tiles_bath", mats.floor_tile)
	if _paint == null:
		var pal := [["paint_green", Color(0.55, 0.64, 0.5)], ["paint_blue", Color(0.5, 0.6, 0.66)], ["paint_ochre", Color(0.7, 0.6, 0.38)],
			["paint_rose", Color(0.7, 0.55, 0.5)], ["paint_grey", Color(0.55, 0.56, 0.52)]]
		var pick: Array = pal[rng.randi() % pal.size()] if kind in ["house", "apartment", "ruin"] else (pal[0] if kind in ["hospital", "police"] else pal[4])
		_paint = _xmat(pick[0], pick[1], 0.9)
	return _paint


## [a, b, inward, along_x, wall centre coordinate] for the four sides of a room.
func _room_edges(i: int) -> Array:
	var rm: Dictionary = rooms[i]
	var r := _inner(rm.rect)
	var rr: Rect2 = rm.rect
	return [
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0, -1), true, rr.end.y],
		[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0, 1), true, rr.position.y],
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(1, 0), false, rr.position.x],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(-1, 0), false, rr.end.x],
	]


## Stretches of an edge between its openings (doors always; windows when `below_y`
## is under their sill): [[t0, t1], ...] as distances from `a`.
func _edge_segments(a: Vector2, b: Vector2, along_x: bool, coord: float, below_y: float) -> Array:
	var cuts: Array = []
	for ext in [true, false]:
		for o in _ops_on(along_x, coord, ext):
			if not o.door and float(o.y0) >= below_y:
				continue
			var cc: float = (o.c as Vector2).x if along_x else (o.c as Vector2).y
			var t := cc - (a.x if along_x else a.y)
			cuts.append([t - float(o.w) * 0.5 - 0.1, t + float(o.w) * 0.5 + 0.1])
	cuts.sort_custom(func(p, q) -> bool: return p[0] < q[0])
	var res: Array = []
	var t0 := 0.0
	var length := a.distance_to(b)
	for cut in cuts:
		if cut[0] > t0 + 0.05:
			res.append([t0, minf(cut[0], length)])
		t0 = maxf(t0, cut[1])
	if length > t0 + 0.05:
		res.append([t0, length])
	return res


func _dress_room(i: int) -> void:
	var rm: Dictionary = rooms[i]
	var t: String = rm.type
	var r := _inner(rm.rect)
	var cx := r.get_center().x
	var cz := r.get_center().y
	var h := height if kind != "ruin" else height * 0.8
	var up := Vector3.UP
	var dado_h := 1.5 if t in ["kitchen", "bath", "ward", "pharmacy", "storage_med", "market"] else 1.08
	var industrial := t in ["storage", "workshop", "garage", "depot", "lockers", "armory", "metro", "cells", "stair"]
	# ceiling (the building top is one slab; this gives each room its own, lower and paler)
	if kind != "ruin":
		_f.box(mats.get("ceiling", _xmat("ceiling", Color(0.8, 0.78, 0.72), 0.95)), Vector3(cx, h - 0.16, cz), Vector3(r.size.x, 0.02, r.size.y))
	# upper-wall finish: wallpaper in homes, painted plaster elsewhere, peeling paint where
	# the place is falling apart (a thin layer in front of the structural wall)
	var upper: Material = mats.get("plaster_int", mats.int)
	if t in ["living", "bedroom", "hall"] and kind in ["house", "apartment", "ruin"]:
		upper = mats.get("wallpaper", upper)
	if (kind == "ruin" or damaged) and rng.randf() < 0.6:
		upper = mats.get("peeling", upper)
	# walls: skirting, dado band, cornice — broken around doors (and windows for the band)
	for e in _room_edges(i):
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var inward: Vector2 = e[2]
		var along_x: bool = e[3]
		var coord: float = e[4]
		var dir := (b - a).normalized()
		var n3 := Vector3(inward.x, 0, inward.y)
		for seg in _edge_segments(a, b, along_x, coord, 0.2):
			var len_s: float = seg[1] - seg[0]
			var mid: Vector2 = a + dir * ((seg[0] + seg[1]) * 0.5)
			var dims := Vector3(len_s, 0.09, 0.025) if along_x else Vector3(0.025, 0.09, len_s)
			_f.box(_xmat("skirting", Color(0.3, 0.22, 0.15), 0.8), Vector3(mid.x, 0.045 + FLOOR_Y, mid.y) + n3 * 0.0125, dims)
		if not industrial:
			var top_y := (h - 0.2) if kind != "ruin" else h
			for seg in _edge_segments(a, b, along_x, coord, 99.0):
				var len_s: float = seg[1] - seg[0]
				var mid: Vector2 = a + dir * ((seg[0] + seg[1]) * 0.5)
				var band := top_y - (FLOOR_Y + dado_h)
				var dims := Vector3(len_s, band, 0.006) if along_x else Vector3(0.006, band, len_s)
				_f.box(upper, Vector3(mid.x, FLOOR_Y + dado_h + band * 0.5, mid.y) + n3 * 0.003, dims)
			for seg in _edge_segments(a, b, along_x, coord, dado_h):
				var len_s: float = seg[1] - seg[0]
				var mid: Vector2 = a + dir * ((seg[0] + seg[1]) * 0.5)
				var dims := Vector3(len_s, dado_h - 0.09, 0.008) if along_x else Vector3(0.008, dado_h - 0.09, len_s)
				_f.box(_dado_mat(t), Vector3(mid.x, FLOOR_Y + 0.09 + (dado_h - 0.09) * 0.5, mid.y) + n3 * 0.004, dims)
				# a dado rail on top of paint
				if dado_h < 1.2:
					var rd := Vector3(len_s, 0.04, 0.03) if along_x else Vector3(0.03, 0.04, len_s)
					_f.box(_xmat("skirting", Color(0.3, 0.22, 0.15), 0.8), Vector3(mid.x, FLOOR_Y + dado_h, mid.y) + n3 * 0.015, rd)
		if kind != "ruin" and not industrial:
			var length := a.distance_to(b)
			var mid := (a + b) * 0.5
			var cd := Vector3(length, 0.07, 0.05) if along_x else Vector3(0.05, 0.07, length)
			_f.box(_xmat("ceiling", Color(0.8, 0.78, 0.72), 0.95), Vector3(mid.x, h - 0.2, mid.y) + n3 * 0.025, cd)
	# the lamp (power is out: dead tubes and bulbs)
	if kind != "ruin":
		if industrial or t in ["shop", "market", "office", "ward", "reception", "pharmacy", "lobby", "storage_med", "dorm"]:
			var long_x := r.size.x >= r.size.y
			var n := maxi(1, int(maxf(r.size.x, r.size.y) / 4.0))
			for k in n:
				var off := ((k + 0.5) / n - 0.5) * maxf(r.size.x, r.size.y) * 0.8
				var p := Vector3(cx, h - 0.2, cz) + (Vector3(off, 0, 0) if long_x else Vector3(0, 0, off))
				_f.box(_xmat("fixture", Color(0.82, 0.82, 0.8), 0.6, 0.3), p, Vector3(1.25, 0.06, 0.18) if long_x else Vector3(0.18, 0.06, 1.25))
				_f.box(_xmat("tube", Color(0.86, 0.88, 0.9), 0.4), p - up * 0.04, Vector3(1.15, 0.03, 0.04) if long_x else Vector3(0.04, 0.03, 1.15))
		else:
			var p := Vector3(cx, h - 0.17, cz)
			_f.cylinder(_xmat("cord", Color(0.12, 0.11, 0.1)), p, p - up * 0.42, 0.006, 5)
			_f.cylinder(_xmat("bulb", Color(0.88, 0.86, 0.8), 0.3), p - up * 0.45, p - up * 0.53, 0.03, 6)
			if rng.randf() < 0.65:
				_f.cylinder(_xmat("shade", Color(0.78, 0.68, 0.5), 0.75), p - up * 0.4, p - up * 0.56, 0.17, 10)
	# rug
	if t in ["living", "bedroom", "hall"] and rng.randf() < 0.75:
		var rs := Vector3(2.0, 0.012, 1.4) if t != "hall" else Vector3(0.8, 0.012, 1.6)
		var rm3: Material = mats.get("rug", _xmat("rug_a", Color(0.42, 0.2, 0.17), 0.95))
		_f.box(rm3, Vector3(cx + rng.randf_range(-0.3, 0.3), FLOOR_Y + 0.006, cz + rng.randf_range(-0.3, 0.3)), rs, rng.randf_range(-0.2, 0.2))
	# pictures and a clock on the walls
	var edges := _room_edges(i)
	if t in ["living", "bedroom", "hall", "office", "reception", "lobby", "kitchen", "ward"]:
		for k in rng.randi_range(1, 2):
			var e: Array = edges[rng.randi() % 4]
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var n3 := Vector3(e[2].x, 0, e[2].y)
			var along_x: bool = e[3]
			var p2 := a.lerp(b, rng.randf_range(0.25, 0.75))
			var wp := Vector3(p2.x, 1.55 + rng.randf_range(-0.1, 0.15), p2.y)
			if (t in ["kitchen", "office", "reception", "lobby", "ward"]) and k == 0:
				# wall clock, stopped
				_f.cylinder(_xmat("clock", Color(0.92, 0.92, 0.88), 0.5), wp + n3 * 0.005, wp + n3 * 0.035, 0.15, 12)
				_f.box(_xmat("cord", Color(0.12, 0.11, 0.1)), wp + n3 * 0.04 + up * 0.04, Vector3(0.012, 0.09, 0.006) if along_x else Vector3(0.006, 0.09, 0.012))
				_f.box(_xmat("cord", Color(0.12, 0.11, 0.1)), wp + n3 * 0.04 + (Vector3(0.03, 0, 0) if along_x else Vector3(0, 0, 0.03)), Vector3(0.07, 0.012, 0.006) if along_x else Vector3(0.006, 0.012, 0.07))
			else:
				var fw := rng.randf_range(0.4, 0.7)
				var fh := fw * rng.randf_range(0.65, 0.85)
				var tilt := rng.randf_range(-0.08, 0.08) if rng.randf() < 0.4 else 0.0
				var fb := Basis(n3, tilt)
				_f.box_xf(_xmat("frame", Color(0.25, 0.18, 0.12), 0.6), Transform3D(fb, wp + n3 * 0.012), Vector3(fw, fh, 0.024) if along_x else Vector3(0.024, fh, fw))
				var art: Material = [_xmat("art_a", Color(0.5, 0.55, 0.45)), _xmat("art_b", Color(0.6, 0.5, 0.35)), _xmat("art_c", Color(0.45, 0.5, 0.6)), mats.white][rng.randi() % 4]
				_f.box_xf(art, Transform3D(fb, wp + n3 * 0.026), Vector3(fw - 0.06, fh - 0.06, 0.006) if along_x else Vector3(0.006, fh - 0.06, fw - 0.06))
	# fallen plaster
	if damaged or kind == "ruin":
		for k in rng.randi_range(2, 4):
			var e: Array = edges[rng.randi() % 4]
			var p2 := (e[0] as Vector2).lerp(e[1], rng.randf_range(0.1, 0.9))
			var n3 := Vector3(e[2].x, 0, e[2].y)
			var pw := rng.randf_range(0.3, 0.9)
			var ph := rng.randf_range(0.25, 0.7)
			_f.box(mats.plinth, Vector3(p2.x, rng.randf_range(0.4, 2.3), p2.y) + n3 * 0.006, Vector3(pw, ph, 0.012) if e[3] else Vector3(0.012, ph, pw))
	# the clutter of a place left in a hurry
	var pos := func() -> Vector3:
		return Vector3(rng.randf_range(r.position.x + 0.45, r.end.x - 0.45), FLOOR_Y, rng.randf_range(r.position.y + 0.45, r.end.y - 0.45))
	if t in ["office", "living", "hall", "reception", "lobby", "pharmacy", "bedroom"]:
		for k in rng.randi_range(3, 9):
			_f.box(_xmat("paper", Color(0.88, 0.86, 0.8), 0.95), pos.call() + up * 0.003, Vector3(0.21, 0.004, 0.3), rng.randf() * TAU)
	if t in ["kitchen", "living", "dorm", "lockers", "metro", "shop"]:
		for k in rng.randi_range(1, 4):
			var p: Vector3 = pos.call()
			if rng.randf() < 0.5:
				_f.cylinder(mats.glass, p, p + up * 0.26, 0.035, 8)
			else:
				var d := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU))
				_f.cylinder(_xmat("bottle", Color(0.25, 0.3, 0.2), 0.3), p + up * 0.035, p + up * 0.035 + d * 0.26, 0.035, 8)
	if t in ["kitchen", "storage", "dorm", "shop", "market", "metro"]:
		for k in rng.randi_range(1, 4):
			var p: Vector3 = pos.call()
			_f.cylinder(mats.metal, p, p + up * 0.11, 0.035, 8)
	if t in ["hall", "storage", "garage", "depot", "shop", "office", "workshop"]:
		for k in rng.randi_range(1, 3):
			var p: Vector3 = pos.call()
			var bs := Vector3(rng.randf_range(0.3, 0.5), rng.randf_range(0.25, 0.4), rng.randf_range(0.3, 0.45))
			_f.box(_xmat("cardboard", Color(0.6, 0.48, 0.32), 0.95), p + up * bs.y * 0.5, bs, rng.randf() * TAU)
			if rng.randf() < 0.4:
				_f.box(_xmat("cardboard", Color(0.58, 0.46, 0.3), 0.95), p + up * (bs.y + 0.15), Vector3(bs.x * 0.8, 0.3, bs.z * 0.8), rng.randf() * TAU)
	if t == "hall":
		for k in 2:
			var p := Vector3(r.position.x + 0.3 + k * 0.14, FLOOR_Y + 0.035, r.position.y + 0.3 + rng.randf_range(0.0, 0.2))
			_f.box(_xmat("shoe", Color(0.15, 0.12, 0.1), 0.6), p, Vector3(0.1, 0.07, 0.27), rng.randf_range(-0.3, 0.3))
	# broken glass inside, under the windows that lost theirs
	if not intact:
		for side in _ext_sides(rm.rect):
			var along_x: bool = side[2]
			for o in _ops_on(along_x, (side[0] as Vector2).y if along_x else (side[0] as Vector2).x, true):
				if o.door:
					continue
				var c2: Vector2 = o.c
				var inward := (Vector2(cx, cz) - c2).normalized()
				for k in rng.randi_range(4, 8):
					var p := Vector3(c2.x, FLOOR_Y + 0.003, c2.y) + Vector3(inward.x, 0, inward.y) * rng.randf_range(0.2, 0.9) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
					_f.box(mats.glass, p, Vector3(rng.randf_range(0.04, 0.12), 0.004, rng.randf_range(0.03, 0.08)), rng.randf() * TAU)
	# a chair knocked over
	if t in ["living", "kitchen", "office", "reception"] and rng.randf() < 0.45:
		var p: Vector3 = pos.call()
		var ch := Geo.prop(self, "chair", p + up * 0.22, rng.randf() * TAU, "none")
		ch.rotation.z = PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
		_interior(ch)


## Interior props: no shadows (they are under a roof) and hidden from afar.
func _interior(n: Node3D) -> Node3D:
	Assets.for_each_geometry(n, func(gi: GeometryInstance3D) -> void:
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.visibility_range_end = INTERIOR_RANGE)
	return n


## A searchable container: an invisible collision box over the furniture (its visual is
## in the interior batch) carrying the loot.
func _container(xf: Transform3D, sz: Vector3, loot_kind: String, title: String) -> LootContainer:
	var c := LootContainer.new()
	add_child(c)
	c.transform = xf
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz.max(Vector3.ONE * 0.1)
	cs.shape = bs
	cs.position.y = sz.y * 0.5
	c.add_child(cs)
	_n += 1
	c.respawn_days = respawn_days
	c.setup("%s_%d" % [key_prefix, _n], title, loot.call(loot_kind) if loot.is_valid() else {}, true)
	c.set_ghost(false)
	containers.append(c)
	return c


## Pile of plaster / brick / concrete chunks (cheap: everything goes into `batch`).
static func debris(batch: BoxBatch, r: RandomNumberGenerator, c: Vector3, radius: float, chunk_mats: Array, n := 16) -> void:
	for k in n:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * radius
		var s := r.randf_range(0.08, 0.38) * (1.0 - d / radius * 0.5)
		var basis := Basis.from_euler(Vector3(r.randf_range(-0.6, 0.6), r.randf() * TAU, r.randf_range(-0.6, 0.6)))
		var p := c + Vector3(cos(a) * d, s * 0.35 + (radius - d) * 0.18 * r.randf(), sin(a) * d)
		batch.box_xf(chunk_mats[r.randi() % chunk_mats.size()], Transform3D(basis, p), Vector3(s * r.randf_range(0.8, 1.8), s * r.randf_range(0.4, 0.9), s))
	for k in 2:
		var basis := Basis.from_euler(Vector3(r.randf_range(-0.35, 0.35), r.randf() * TAU, r.randf_range(-0.35, 0.35)))
		batch.box_xf(chunk_mats[0], Transform3D(basis, c + Vector3(r.randf_range(-0.4, 0.4), 0.12, r.randf_range(-0.4, 0.4))), Vector3(radius * 0.9, 0.1, radius * 0.6))


# --------------------------------------------------------------------------
# Special rooms
# --------------------------------------------------------------------------

## Supermarket floor: shelf islands in rows, checkouts by the entrance (wall fridges and
## shelves come from the room list afterwards).
func _market(r: Rect2) -> void:
	var gs := Vector3(1.0, 1.6, 3.0)
	var cols := int((r.size.x - 4.0) / 3.2)
	for k in cols:
		var x := r.position.x + 2.6 + k * 3.2 + 0.5
		for row in 2:
			var z := r.position.y + 1.4 + row * 4.0 + gs.z * 0.5
			if z + gs.z * 0.5 > r.end.y - 3.4:
				continue
			_placed.append(Rect2(x - gs.x * 0.5 - 0.3, z - gs.z * 0.5 - 0.3, gs.x + 0.6, gs.z + 0.6))
			var xf := Transform3D(Basis(), Vector3(x, FLOOR_Y, z))
			_spawn("gondola", {}, xf, gs)
			_container(xf, gs, "shop", "Raft de magazin")
	# checkouts near the doors
	for k in 2:
		var x := r.position.x + 2.0 + k * 2.6
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, FLOOR_Y, r.end.y - 2.6))
		_placed.append(Rect2(x - 0.5, r.end.y - 3.6, 1.0, 2.0))
		_spawn("counter_shop", FURN.counter_shop, xf, Vector3(1.6, 1.0, 0.7))


## Stairwell: flight of steps up the side wall, blocked by a collapsed landing.
func _stairs(r: Rect2) -> void:
	var steps := 9
	var run := minf(r.size.y - 0.6, 3.2)
	var sw := minf(1.2, r.size.x * 0.45)
	var x := r.end.x - sw * 0.5 - 0.02
	for k in steps:
		var h := (k + 1) * 0.17
		var z := r.end.y - 0.4 - (k + 0.5) * run / steps
		_b.box(mats.floor_concrete, Vector3(x, h * 0.5, z), Vector3(sw, h, run / steps), 0.0, true)
	debris(_f, rng, Vector3(x, steps * 0.17, r.position.y + 0.5), 0.7, [mats.int, mats.plinth, mats.chimney], 14)
	_placed.append(Rect2(x - sw * 0.5, r.position.y, sw, r.size.y))
	# mailboxes on the other wall
	_f.box(mats.metal, Vector3(r.position.x + 0.1, 1.4, r.get_center().y), Vector3(0.18, 0.6, 1.2))


## Police cells: a line of bars across the back of the room with a gap for the door.
func _cell_bars(r: Rect2) -> void:
	var z := r.position.y + 1.9
	var x := r.position.x + 0.05
	while x < r.end.x:
		if absf(x - r.get_center().x) > 0.5:
			_f.box(mats.metal, Vector3(x, 1.15, z), Vector3(0.035, 2.3, 0.035))
		x += 0.16
	_f.box(mats.metal, Vector3(r.get_center().x, 2.25, z), Vector3(r.size.x, 0.06, 0.06))
	var half := r.size.x * 0.5 - 0.5
	_f.collider(Transform3D(Basis(), Vector3(r.position.x + half * 0.5, 1.15, z)), Vector3(half, 2.3, 0.08))
	_f.collider(Transform3D(Basis(), Vector3(r.end.x - half * 0.5, 1.15, z)), Vector3(half, 2.3, 0.08))


## Partial collapse: a debris pile in one of the rooms.
func _damage() -> void:
	var r: Rect2 = _inner(rooms[rng.randi() % rooms.size()].rect)
	debris(_f, rng, Vector3(r.get_center().x, FLOOR_Y, r.get_center().y), 1.1, [mats.int, mats.plinth, mats.chimney, mats.wood_dark], 22)
