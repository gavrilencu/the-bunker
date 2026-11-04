extends LevelBase
## Surface location for a looting run.
##
## The map is a heightfield valley (Terrain): rolling ash ground, bomb craters, hills
## rising past the playable area, asphalt roads and flattened pads under the ruins.
## The player comes out of exit 4 of the civil-defence shelter network (BunkerPortal,
## cut into the hill at the south edge) and leaves the same way.

const SIZE := 95.0
const CARRY := 25.0
const PORTAL_Z := SIZE * 0.5 - 0.5

var loc_id := "factory"
var loc: Dictionary
var rng := RandomNumberGenerator.new()
var terrain: Terrain
var portal: BunkerPortal
var hotspots: Array = []  # [pos, radius, mult]
var exit_pos := Vector3.ZERO
var start_weight := 0.0
var _geiger_t := 0.0
var _dose_rate := 0.0
var _choke_warned := false
var _leaving := false
var enemies: Array[Enemy] = []
## radiation added this frame by hazmat zombies (mSv/s)
var extra_rad := 0.0
const ENEMY_MIX := {
	"factory": ["mutant", "mutant", "dog"], "market": ["mutant", "bandit", "mutant"],
	"hospital": ["hazmat", "mutant", "hazmat"], "police": ["bandit", "bandit", "mutant"],
	"military": ["bandit", "hazmat", "dog", "bandit"],
	"metro": ["mutant", "dog", "bandit"],
}
## Town plan: the main street crosses the valley east-west, a north-south street runs from
## it to the north edge and a back street crosses that one. Plots line both sides of the
## east-west streets; every house faces its street, with a yard and a fence.
const MAIN_HW := 3.4
const STREET_HW := 3.0
const CROSS_Z := -16.0
const SIDEWALK := 1.6
const SLOTS := [-39.0, -26.0, -13.0, 13.0, 26.0, 39.0]
## Keep-out in front of the shelter exit (trench + approach).
const PORTAL_CLEAR := Rect2(-6.5, 37.0, 13.0, 11.0)
## Per location: the landmark building and what fills the other plots ("empty" = vacant lot).
const DISTRICTS := {
	"factory": {"landmark": "factory", "mix": ["house", "house", "garage", "house", "ruin", "garage", "house", "empty", "house"]},
	"market": {"landmark": "supermarket", "mix": ["shop", "apartment", "house", "shop", "house", "ruin", "apartment", "empty", "house"]},
	"hospital": {"landmark": "hospital", "mix": ["apartment", "house", "house", "shop", "house", "ruin", "apartment", "empty"]},
	"police": {"landmark": "police", "mix": ["house", "garage", "house", "shop", "house", "ruin", "apartment", "empty", "house"]},
	"metro": {"landmark": "metro", "mix": ["apartment", "shop", "apartment", "shop", "house", "ruin", "apartment", "empty"]},
	"military": {"landmark": "barracks", "mix": ["depot", "hq", "garage", "depot", "empty", "garage", "barracks", "empty"]},
}
const SHOP_SIGNS := ["MAGAZIN", "ALIMENTARA", "PÂINE", "FARMACIE", "PRODUSE", "BAR"]
const LANDMARK_SIGNS := {"supermarket": ["UNIC", Color(0.85, 0.3, 0.25)], "hospital": ["SPITALUL RAIONAL", Color(0.85, 0.85, 0.8)],
	"police": ["POLIȚIA", Color(0.35, 0.5, 0.9)], "factory": ["ELECTROMAȘ", Color(0.85, 0.75, 0.55)],
	"metro": ["M · PIAȚA UNIRII", Color(0.9, 0.25, 0.2)], "barracks": ["UNITATEA MILITARĂ 2214", Color(0.75, 0.8, 0.6)]}
const PLASTER_TEX := ["plaster_white", "plaster_yellow", "plaster_blue", "plaster_worn", "plaster_white"]
const PLASTER := [Color(0.8, 0.86, 0.94), Color(0.95, 0.88, 0.68), Color(0.78, 0.88, 0.75), Color(0.94, 0.93, 0.88), Color(0.9, 0.78, 0.66)]
const INTERIOR := [Color(0.88, 0.85, 0.75), Color(0.74, 0.82, 0.88), Color(0.88, 0.8, 0.7), Color(0.8, 0.88, 0.78), Color(0.86, 0.86, 0.84)]
const TRIM := [Color(0.88, 0.88, 0.85), Color(0.22, 0.4, 0.68), Color(0.28, 0.48, 0.32), Color(0.42, 0.28, 0.18)]
const FABRIC := [Color(0.55, 0.2, 0.18), Color(0.25, 0.35, 0.55), Color(0.55, 0.47, 0.25), Color(0.32, 0.48, 0.33), Color(0.6, 0.55, 0.5), Color(0.45, 0.25, 0.4)]

var _blocked: Array = []  # [center Vector2, radius]
## axis-aligned building footprints (no grass, no props, no spawns inside)
var _blocked_rects: Array = []
## stable per location: the town looks the same on every visit (loot / enemies vary by day)
var town_rng := RandomNumberGenerator.new()
var plots: Array = []
var buildings: Array[Building] = []
## every searchable piece of furniture in the town
var containers: Array[LootContainer] = []
var _town: BoxBatch
var _mat_cache := {}

var m_wall: Material
var m_brick: Material
var m_metal: Material
var m_concrete: Material


func _ready() -> void:
	loc_id = State.current_location if ItemDB.LOCATIONS.has(State.current_location) else "factory"
	loc = ItemDB.LOCATIONS[loc_id]
	State.context = "surface"
	HUD.set_mode("surface")
	rng.seed = hash(loc_id) + State.day * 7919
	town_rng.seed = hash(loc_id) * 31 + 17
	var mult := State.surface_rad_mult()
	make_environment({
		"hdri": "sky_overcast", "sky_energy": 0.55, "exposure": 0.95, "fog_density": 0.005,
		"fog_color": Color(0.5, 0.44, 0.36), "aerial": 0.8, "sun_scatter": 0.3, "fog_sky_affect": 0.55,
		"vfog_density": 0.011 + 0.01 * mult, "vfog_albedo": Color(0.72, 0.64, 0.52), "vfog_length": 110.0,
		"vfog_ambient": 0.6, "ambient_energy": 0.7, "saturation": 0.72, "contrast": 1.1,
		"profile": {"vfog": true, "ssil": false},
	})
	make_sun(Vector2(-28, 140), Color(1.0, 0.78, 0.55), 0.85, 110.0)
	m_wall = Assets.pbr("plaster_worn", {"tile": 2.5, "tint": Color(0.85, 0.83, 0.8)})
	m_brick = Assets.pbr("brick_wall", {"tile": 2.5, "tint": Color(0.55, 0.5, 0.48)})
	m_metal = Assets.pbr("rusty_metal", {"tile": 2.0})
	m_concrete = Assets.pbr("concrete_floor", {"tile": 3.0, "tint": Color(0.7, 0.68, 0.64)})

	_build_terrain()
	_build_portal()
	_build_town()
	_dress_streets()
	_nature()
	_bounds()
	_spawn_hotspots(mult)
	_spawn_enemies()
	terrain.scatter_grass(rng, SIZE * 0.5 + 6.0, float(Settings.val("vegetation")), _is_blocked)

	var spawn := portal.to_global(Vector3(0, 0.15, -2.6))
	spawn_player(spawn, 0.0)
	player.footstep_surface = "grass"
	player.enable_combat(true)
	portal.set_open(true)
	portal.close_behind(1.4)
	start_weight = State.total_weight()
	if Game.args.has("weapon"):
		var wid := String(Game.args.weapon)
		State.add(wid, 1, true)
		var ammo: String = ItemDB.WEAPONS.get(wid, {}).get("ammo", "")
		if ammo != "":
			State.add(ammo, 120, true)
			State.flags["mag_" + wid] = int(ItemDB.WEAPONS[wid].mag)
		player.equip(wid)
	if Game.args.has("enter") and not buildings.is_empty():
		# debug: stand just inside the street door of building N, looking in
		var bd := buildings[clampi(int(Game.args.enter), 0, buildings.size() - 1)]
		player.global_position = bd.to_global(Vector3(bd.entrance_x, 0.15, bd.size.y * 0.5 - 1.0))
		player.rotation.y = bd.rotation.y
		player.flashlight.visible = Game.args.has("torch")
	if Game.args.has("room"):
		# debug: stand in the corner of the Nth room of a type (bedroom, kitchen...), facing in
		var want := String(Game.args.room)
		var nth := int(Game.args.get("nth", "0"))
		for bd in buildings:
			for rm in bd.rooms:
				if rm.type == want:
					if nth > 0:
						nth -= 1
						continue
					var rr: Rect2 = rm.rect
					var corner := Vector3(rr.position.x + 0.55, 0.15, rr.end.y - 0.55)
					player.global_position = bd.to_global(corner)
					var look := bd.to_global(Vector3(rr.get_center().x, 0.15, rr.get_center().y)) - player.global_position
					player.rotation.y = atan2(-look.x, -look.z)
					player.set_pitch(-0.2)
					break
			if player.global_position.distance_to(exit_pos) > 20.0:
				break
	if Game.args.has("outside") and not buildings.is_empty():
		# debug: stand in the street 9 m in front of building N, looking at its facade
		var bo := buildings[clampi(int(Game.args.outside), 0, buildings.size() - 1)]
		player.global_position = bo.to_global(Vector3(bo.entrance_x + 2.5, 0.15, bo.size.y * 0.5 + 9.0))
		player.rotation.y = bo.rotation.y + 0.25
		player.set_pitch(0.05)
	if Game.args.has("spawn"):
		var e := Enemy.new()
		e.kind = String(Game.args.spawn)
		e.level_ref = self
		var sp := player.global_position + Vector3(0, 0, -6.0)
		e.position = _gy(sp) + Vector3(0, 0.1, 0)
		add_child(e)
		e.rotation.y = PI
		enemies.append(e)
	Audio.ambient("bg", "ambient_wasteland", -2.0, 2.0)
	Audio.ambient("breath", "gasmask_breath", -10.0, 2.0)
	Audio.play_music("music_tension", 4.0, -12.0)
	Settings.set_reverb(0.06, 0.9)
	HUD.mask_effect = 1.0
	HUD.banner(loc.name, "Filtrul ține %d:%02d. Nu rămâne prea mult." % [int(State.mask_filter_left) / 60, int(State.mask_filter_left) % 60], 2.5)
	State.running = true


# --------------------------------------------------------------------------
# Ground helpers
# --------------------------------------------------------------------------

func _gy(p: Vector3, sink := 0.0) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.z) - sink, p.z)


## Tilts a placed node to follow the ground (amount 0..1).
func _align(n: Node3D, amount := 1.0) -> void:
	var nrm := terrain.normal_at(n.global_position.x, n.global_position.z)
	var up := Vector3.UP.lerp(nrm, amount).normalized()
	var b := Basis(Vector3.UP, n.rotation.y)
	var axis := Vector3.UP.cross(up)
	if axis.length() > 0.0001:
		b = Basis(axis.normalized(), Vector3.UP.angle_to(up)) * b
	n.global_basis = b.scaled(n.scale)


func _ground_prop(id: String, p: Vector3, rot_y: float, collide := "box", scale := 1.0, sink := 0.0, align := 0.0) -> Node3D:
	var n := Geo.prop(self, id, _gy(p, sink), rot_y, collide, scale)
	if align > 0.0:
		_align(n, align)
	return n


## Detail props: fade out past `range_end`, optionally no shadows (cheap at distance).
func _lite(n: Node3D, range_end: float, shadows := true) -> Node3D:
	Assets.for_each_geometry(n, func(g: GeometryInstance3D) -> void:
		g.visibility_range_end = range_end
		g.visibility_range_end_margin = range_end * 0.1
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not shadows:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	return n


func _is_blocked(p: Vector2) -> bool:
	for b in _blocked:
		if p.distance_to(b[0]) < float(b[1]) * 0.85:
			return true
	for r in _blocked_rects:
		if (r as Rect2).has_point(p):
			return true
	return false


## Random open spot (not on a street, in a building or near other blocked spots).
func _free_spot(radius: float, tries := 40, r: RandomNumberGenerator = null) -> Vector3:
	if r == null:
		r = rng
	for i in tries:
		var p := Vector2(r.randf_range(-SIZE * 0.45, SIZE * 0.45), r.randf_range(-SIZE * 0.45, SIZE * 0.42))
		var ok := true
		for b in _blocked:
			if p.distance_to(b[0]) < radius + float(b[1]):
				ok = false
				break
		if ok:
			for br in _blocked_rects:
				if (br as Rect2).grow(radius).has_point(p):
					ok = false
					break
		if ok and terrain and terrain._road_mask(p.x, p.y) > 0.3:
			ok = false
		if ok:
			_blocked.append([p, radius])
			return Vector3(p.x, 0, p.y)
	return Vector3(r.randf_range(-SIZE * 0.4, SIZE * 0.4), 0, r.randf_range(-SIZE * 0.4, SIZE * 0.35))


# --------------------------------------------------------------------------
# Generation
# --------------------------------------------------------------------------

func _build_terrain() -> void:
	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.setup(hash(loc_id) & 0xffff, SIZE * 0.5)
	add_child(terrain)
	# shelter exit at the south edge, opening north into the map
	var floor_h := terrain.add_portal(Vector2(0, PORTAL_Z), Vector2(0, -1), BunkerPortal.HALF_W, BunkerPortal.TRENCH, BunkerPortal.HEIGHT)
	exit_pos = Vector3(0, floor_h, PORTAL_Z - 2.0)
	_blocked.append([Vector2(0, PORTAL_Z - 3.0), 9.5])
	# streets: main street across the valley, the service road to the shelter exit,
	# the north-south street and the back street
	terrain.add_road(Vector2(-SIZE * 0.75, 25.0), Vector2(SIZE * 0.75, 19.0), MAIN_HW)
	terrain.add_road(Vector2(0, PORTAL_Z - BunkerPortal.TRENCH - 1.0), Vector2(0.5, 21.0), 2.4)
	terrain.add_road(Vector2(0.0, 20.0), Vector2(0.0, -SIZE * 0.62), STREET_HW)
	terrain.add_road(Vector2(-SIZE * 0.62, CROSS_Z), Vector2(SIZE * 0.62, CROSS_Z), STREET_HW)
	_plan_town()
	# building pads: flat ground under every building
	for p in plots:
		if p.kind != "empty":
			p["h"] = terrain.add_pad(Vector3(p.c.x, 0, p.c.y), (p.size as Vector2).length() * 0.5 + 1.2, 6.0)
	# bomb craters in the open fields
	for i in 2 + town_rng.randi_range(0, 2):
		var p := _free_spot(6.5, 40, town_rng)
		var rad := town_rng.randf_range(3.2, 6.0)
		terrain.add_crater(Vector2(p.x, p.z), rad, rad * town_rng.randf_range(0.22, 0.3))
	terrain.build()


func _main_z(x: float) -> float:
	return lerpf(25.0, 19.0, (x + SIZE * 0.75) / (SIZE * 1.5))


## Sidewalk edge of plot row `ri` (0: north of the main street, 1: south of the back street,
## 2: north of the back street, 3: south of the main street).
func _row_edge(ri: int, x: float) -> float:
	match ri:
		0: return _main_z(x) - MAIN_HW - SIDEWALK
		1: return CROSS_Z + STREET_HW + SIDEWALK
		2: return CROSS_Z - STREET_HW - SIDEWALK
	return _main_z(x) + MAIN_HW + SIDEWALK


## Building parameters per kind (sizes in metres; x = street frontage).
func _kind_spec(kind: String) -> Dictionary:
	var r := town_rng
	match kind:
		"house", "ruin":
			return {"size": Vector2(r.randf_range(7.8, 10.4), r.randf_range(6.4, 7.8)), "height": 2.9, "roof": "gable",
				"yard": r.randf_range(2.6, 4.0), "fence": true, "damaged": kind == "ruin" or r.randf() < 0.3}
		"apartment":
			return {"size": Vector2(18.0, 11.0), "floors": 3, "height": 3.0, "yard": 2.4, "wide": true}
		"shop":
			return {"size": Vector2(r.randf_range(9.5, 11.5), r.randf_range(8.0, 9.0)), "height": 3.4, "yard": 1.2, "sign": SHOP_SIGNS[r.randi() % SHOP_SIGNS.size()]}
		"garage":
			return {"size": Vector2(5.6, 7.0), "height": 2.8, "yard": 2.0, "fence": true}
		"depot":
			return {"size": Vector2(14.0, 10.0), "height": 4.5, "yard": 2.0, "wide": true}
		"hq":
			return {"size": Vector2(16.0, 11.0), "height": 3.2, "yard": 2.0, "wide": true, "sign": "COMANDAMENT"}
		"barracks":
			return {"size": Vector2(24.0, 10.0), "height": 3.2, "yard": 2.0, "wide": true}
		"empty":
			return {"size": Vector2(9.0, 7.5), "yard": 3.0, "fence": r.randf() < 0.5}
		"supermarket":
			return {"size": Vector2(26.0, 18.0), "height": 4.2}
		"hospital":
			return {"size": Vector2(28.0, 14.0), "floors": 2, "height": 3.3}
		"police":
			return {"size": Vector2(18.0, 12.0), "height": 3.3}
		"factory":
			return {"size": Vector2(28.0, 18.0), "height": 6.5}
		"metro":
			return {"size": Vector2(16.0, 10.0), "height": 4.2}
	return {"size": Vector2(8.0, 7.0)}


func _plan_town() -> void:
	var dist: Dictionary = DISTRICTS.get(loc_id, DISTRICTS.factory)
	# the landmark stands on the main street, east of the crossing
	var lk: String = dist.landmark
	var ls := _kind_spec(lk)
	var lfront := _main_z(19.0) - MAIN_HW - SIDEWALK - 2.0
	_add_plot(lk, Vector2(19.0, lfront - (ls.size as Vector2).y * 0.5), 0.0, ls, lfront + 2.0)
	var mix: Array = dist.mix
	var rows := [[-1.0, 0.0], [1.0, PI], [-1.0, 0.0], [1.0, PI]]  # [side of the street, facing yaw]
	var empties := 0
	for ri in rows.size():
		var si := 0
		var prev := ""
		while si < SLOTS.size():
			var x: float = SLOTS[si]
			var kind: String = mix[town_rng.randi() % mix.size()]
			# vacant lots are the exception, never two side by side
			if kind == "empty" and (prev == "empty" or empties >= 3):
				kind = "house" if loc_id != "military" else "garage"
			if kind == "empty":
				empties += 1
			prev = kind
			var spec := _kind_spec(kind)
			var wide: bool = spec.get("wide", false)
			if wide:
				if si + 1 < SLOTS.size() and signf(SLOTS[si + 1]) == signf(x):
					x = (x + float(SLOTS[si + 1])) * 0.5
				else:
					kind = "house"
					spec = _kind_spec(kind)
					wide = false
			var edge := _row_edge(ri, x)
			var side: float = rows[ri][0]
			var c := Vector2(x, edge + side * (float(spec.yard) + (spec.size as Vector2).y * 0.5))
			var ok := _add_plot(kind, c, rows[ri][1], spec, edge)
			if Game.args.has("trace"):
				print("[town] row %d x=%.1f %s -> %s" % [ri, x, kind, "ok" if ok else "rejected"])
			si += 2 if wide else 1


func _add_plot(kind: String, c: Vector2, yaw: float, spec: Dictionary, edge: float) -> bool:
	var sz: Vector2 = spec.size
	var rect := Rect2(c - sz * 0.5, sz)
	if rect.position.x < -46.0 or rect.end.x > 46.0 or rect.position.y < -46.0 or rect.end.y > 46.0:
		return false
	if rect.grow(1.0).intersects(PORTAL_CLEAR):
		return false
	for p in plots:
		if (p.rect as Rect2).grow(1.5).intersects(rect):
			return false
	# the lot runs from the sidewalk to a small backyard behind the building
	var lot_w := maxf(sz.x + 2.0, 12.4)
	var z0 := c.y - sz.y * 0.5 - 3.0 if edge > c.y else edge
	var z1 := edge if edge > c.y else c.y + sz.y * 0.5 + 3.0
	var lot := Rect2(c.x - lot_w * 0.5, z0, lot_w, z1 - z0)
	plots.append({"kind": kind, "c": c, "yaw": yaw, "size": sz, "spec": spec, "rect": rect, "lot": lot, "edge": edge})
	if kind != "empty":
		_blocked_rects.append(rect.grow(0.5))
	return true


func _build_portal() -> void:
	portal = BunkerPortal.new()
	portal.name = "ShelterExit"
	add_child(portal)
	portal.position = Vector3(0, exit_pos.y, PORTAL_Z)
	portal.build()
	portal.prompt_text = "Ieșirea 4 — Coboară în buncăr  (%.1f h)" % (float(loc.travel) * State.mul("travel"))
	portal.on_enter = _leave



## Shared materials, cached so equal tints reuse one material across buildings.
func _m(key: String, make: Callable) -> Material:
	if not _mat_cache.has(key):
		_mat_cache[key] = make.call()
	return _mat_cache[key]


func _mats_for(kind: String, r: RandomNumberGenerator) -> Dictionary:
	var ext: Material
	if kind in ["factory", "depot", "garage", "police"] or (kind in ["house", "ruin"] and r.randf() < 0.25):
		ext = _m("brick", func() -> Material: return Assets.pbr("brick_wall", {"tile": 2.2, "tint": Color(0.78, 0.7, 0.66)}))
	elif kind in ["apartment", "hospital", "hq", "barracks", "metro"]:
		ext = _m("panel", func() -> Material: return Assets.pbr("panel_concrete", {"tile": 3.0, "tint": Color(0.85, 0.84, 0.82)}))
	else:
		# real lime plasters, painted (village houses: white, ochre, sky blue, weathered grey)
		var ti := r.randi() % PLASTER_TEX.size()
		ext = _m("plaster%d" % ti, func() -> Material: return Assets.pbr(PLASTER_TEX[ti], {"tile": 2.6, "tint": Color(0.92, 0.92, 0.9)}))
	var ii := r.randi() % INTERIOR.size()
	var tr := r.randi() % TRIM.size()
	var fa := r.randi() % FABRIC.size()
	var fb := (fa + 1 + r.randi() % (FABRIC.size() - 1)) % FABRIC.size()
	var tin := kind in ["house", "ruin", "barracks"]
	return {
		"ext": ext,
		"int": _m("int%d" % ii, func() -> Material: return Assets.pbr("plaster_int", {"tile": 2.0, "tint": INTERIOR[ii]})),
		"trim": _m("trim%d" % tr, func() -> Material: return Assets.pbr("wood_painted", {"tile": 0.8, "tint": TRIM[tr].lerp(Color.WHITE, 0.45), "fallback": TRIM[tr]})),
		"roof": _m("tin" if tin else "tar", func() -> Material: return Assets.pbr("roof_tin", {"tile": 2.2, "tint": Color(0.85, 0.82, 0.8)}) if tin else Assets.pbr("asphalt", {"tile": 3.0, "tint": Color(0.6, 0.6, 0.6)})),
		"plinth": _m("plinth", func() -> Material: return Assets.pbr("concrete_floor", {"tile": 2.0, "tint": Color(0.6, 0.6, 0.58)})),
		# interior finishes (dedicated Poly Haven sets; each falls back to a flat colour if the set is missing)
		"floor_wood": _m("fwood", func() -> Material: return Assets.pbr("old_floor", {"tile": 2.2, "tint": Color(0.82, 0.76, 0.7), "fallback": Color(0.6, 0.5, 0.4)})),
		"floor_parquet": _m("fparq", func() -> Material: return Assets.pbr("parquet", {"tile": 1.6, "tint": Color(0.85, 0.78, 0.68), "fallback": Color(0.6, 0.45, 0.3)})),
		"floor_tile": _m("ftile", func() -> Material: return Assets.pbr("tiles_floor", {"tile": 1.5, "tint": Color(0.85, 0.83, 0.78), "fallback": Color(0.75, 0.73, 0.68)})),
		"floor_lino": _m("flino", func() -> Material: return Assets.pbr("linoleum", {"tile": 1.8, "tint": Color(0.9, 0.86, 0.8), "fallback": Color(0.5, 0.42, 0.3)})),
		"floor_concrete": _m("fconc", func() -> Material: return Assets.pbr("concrete_floor", {"tile": 2.5, "tint": Color(0.75, 0.74, 0.7)})),
		"wallpaper": _m("wallpaper%d" % ii, func() -> Material: return Assets.pbr("wallpaper", {"tile": 1.6, "tint": INTERIOR[ii].lerp(Color.WHITE, 0.35), "fallback": INTERIOR[ii]})),
		"plaster_int": _m("plaster_int%d" % ii, func() -> Material: return Assets.pbr("plaster_int", {"tile": 2.0, "tint": INTERIOR[ii], "fallback": INTERIOR[ii]})),
		"peeling": _m("peeling", func() -> Material: return Assets.pbr("paint_peeling", {"tile": 2.0, "fallback": Color(0.6, 0.6, 0.55)})),
		"tiles_bath": _m("tbath", func() -> Material: return Assets.pbr("tiles_bath", {"tile": 1.0, "tint": Color(0.9, 0.9, 0.88), "fallback": Color(0.8, 0.8, 0.78)})),
		"ceiling": _m("ceiling", func() -> Material: return Assets.pbr("plaster_int", {"tile": 2.0, "tint": Color(0.92, 0.9, 0.85), "fallback": Color(0.8, 0.78, 0.72)})),
		"rug": _m("rug%d" % fa, func() -> Material: return Assets.pbr("carpet", {"tile": 1.2, "tint": FABRIC[fa].lerp(Color.WHITE, 0.3), "fallback": FABRIC[fa]})),
		"wood": _m("wood", func() -> Material: return Assets.pbr("kitchen_wood", {"tile": 1.0, "tint": Color(0.95, 0.85, 0.7), "fallback": Color(0.85, 0.66, 0.46)})),
		"wood_dark": _m("wood_dark", func() -> Material: return Assets.pbr("kitchen_wood", {"tile": 1.0, "tint": Color(0.5, 0.36, 0.26), "fallback": Color(0.48, 0.34, 0.24)})),
		"metal": _m("metal", func() -> Material: return Assets.pbr("painted_metal", {"tile": 0.8})),
		"white": _m("white", func() -> Material: return Geo.color_mat(Color(0.86, 0.85, 0.8), 0.35)),
		"dark": _m("dark", func() -> Material: return Geo.color_mat(Color(0.07, 0.07, 0.07), 0.6)),
		"fabric_a": _m("fab%d" % fa, func() -> Material: return Assets.pbr("upholstery", {"tile": 0.7, "tint": FABRIC[fa].lerp(Color.WHITE, 0.25), "fallback": FABRIC[fa]})),
		"fabric_b": _m("fab%d" % fb, func() -> Material: return Assets.pbr("upholstery", {"tile": 0.7, "tint": FABRIC[fb].lerp(Color.WHITE, 0.25), "fallback": FABRIC[fb]})),
		"glass": _m("glass", func() -> Material: return Geo.color_mat(Color(0.06, 0.08, 0.09), 0.08, 0.4)),
		"chimney": _m("chimney", func() -> Material: return Assets.pbr("brick_wall", {"tile": 1.0, "tint": Color(0.7, 0.6, 0.55)})),
		"locker": _m("locker", func() -> Material: return Assets.pbr("painted_metal", {"tile": 0.6, "tint": Color(0.7, 0.8, 0.85)})),
		"olive": _m("olive", func() -> Material: return Geo.color_mat(Color(0.28, 0.33, 0.2), 0.7)),
		"red": _m("red", func() -> Material: return Geo.color_mat(Color(0.6, 0.12, 0.1), 0.6)),
	}


## Loot for a new container of `kind` (rolled per visit; empty more often on later visits).
func _roll_kind(kind: String) -> Dictionary:
	var table: Dictionary = ItemDB.LOOT_KINDS.get(kind, {})
	if table.is_empty():
		table = loc.loot
	var visits := int(State.flags.get("visits_" + loc_id, 0))
	if rng.randf() < clampf(0.42 + visits * 0.04, 0.42, 0.7):
		return {}
	var out := {}
	var keys := table.keys()
	for i in (1 if rng.randf() < 0.7 else 2):
		var k: String = keys[rng.randi() % keys.size()]
		var n := maxi(1, roundi(rng.randf_range(0.3, 0.8) * int(table[k])))
		if k in ["pistol", "rifle", "shotgun", "hazmat_suit", "gas_mask", "fuel_can", "shovel", "geiger"]:
			n = 1
		out[k] = int(out.get(k, 0)) + n
	# now and then something the location is known for
	if kind != "crate" and kind != "car" and rng.randf() < 0.15:
		var lk: Array = loc.loot.keys()
		var k2: String = lk[rng.randi() % lk.size()]
		out[k2] = int(out.get(k2, 0)) + 1
	return out


func _build_town() -> void:
	_town = BoxBatch.new()
	_town.cell = 40.0  # fences, debris and yards split per block so they get frustum-culled
	for i in plots.size():
		var p: Dictionary = plots[i]
		var pos := Vector3(p.c.x, float(p.get("h", 0.0)), p.c.y)
		if p.kind == "empty":
			_yard(p, pos, null)
			continue
		var spec: Dictionary = p.spec
		var b := Building.new()
		b.name = "Building_%s_%d" % [p.kind, i]
		b.kind = p.kind
		b.size = spec.size
		b.floors = spec.get("floors", 1)
		b.height = spec.get("height", 3.0)
		b.roof = spec.get("roof", "flat")
		b.damaged = spec.get("damaged", false)
		if LANDMARK_SIGNS.has(p.kind):
			b.sign_text = LANDMARK_SIGNS[p.kind][0]
			b.sign_color = LANDMARK_SIGNS[p.kind][1]
		elif spec.get("sign", "") != "":
			b.sign_text = spec.sign
			b.sign_color = Color(0.9, 0.86, 0.75)
		b.rng = RandomNumberGenerator.new()
		b.rng.seed = town_rng.seed + i * 7717
		b.loot = _roll_kind
		b.key_prefix = "t_%s_%d" % [loc_id, i]
		b.mats = _mats_for(p.kind, b.rng)
		add_child(b)
		b.position = pos
		b.rotation.y = p.yaw
		b.build()
		buildings.append(b)
		containers.append_array(b.containers)
		_yard(p, pos, b)


func _rubble_mats() -> Array:
	return [_m("plinth", func() -> Material: return Assets.pbr("concrete_floor", {"tile": 2.0, "tint": Color(0.6, 0.6, 0.58)})),
		_m("chimney", func() -> Material: return Assets.pbr("brick_wall", {"tile": 1.0, "tint": Color(0.7, 0.6, 0.55)})),
		_m("panel", func() -> Material: return Assets.pbr("panel_concrete", {"tile": 3.0, "tint": Color(0.85, 0.84, 0.82)}))]


## Fence, gate and the bits of a lived-in yard (well, wood pile, garden, tree, car).
func _yard(p: Dictionary, pos: Vector3, b: Building) -> void:
	var r := town_rng
	var kind: String = p.kind
	var lot: Rect2 = p.lot
	var front_sign := 1.0 if p.yaw == 0.0 else -1.0
	var gate_x: float = p.c.x + (b.entrance_x * front_sign if b else 0.0)
	if p.spec.get("fence", false):
		_fence(lot, float(p.edge), gate_x, kind == "ruin" or kind == "empty")
	var back := Vector2(p.c.x, p.c.y - front_sign * ((p.size as Vector2).y * 0.5 + 1.5))
	match kind:
		"house", "ruin":
			if r.randf() < 0.45:
				_well(Vector2(back.x + r.randf_range(-3.0, 3.0), back.y))
			elif r.randf() < 0.6:
				_woodpile(Vector2(back.x + r.randf_range(-3.0, 3.0), back.y), p.yaw)
			if r.randf() < 0.5:
				var tx: float = p.c.x + (lot.size.x * 0.5 - 1.0) * (1.0 if r.randf() < 0.5 else -1.0)
				_tree("tree_dead" if r.randf() < 0.6 or not Assets.has_model("tree_dead_b") else "tree_dead_b", Vector3(tx, 0, back.y + r.randf_range(-1.0, 1.0)), r.randf_range(0.6, 0.9))
		"empty":
			var c := Vector2(p.c.x, p.c.y)
			match r.randi() % 3:
				0:
					_garden(c, p.yaw)
				1:
					_ground_prop("car_wreck", Vector3(c.x, 0, c.y), p.yaw + r.randf_range(-0.6, 0.6), "box", 1.0, 0.08, 0.85)
				_:
					Building.debris(_town, r, _gy(Vector3(c.x, 0, c.y)), 2.2, _rubble_mats(), 40)
			if r.randf() < 0.5:
				_well(Vector2(c.x + 3.0, c.y + r.randf_range(-2.0, 2.0)))
			_blocked.append([c, 4.0])
		"apartment", "shop", "supermarket", "hospital", "metro", "police", "hq":
			var front_y: float = p.c.y + front_sign * ((p.size as Vector2).y * 0.5 + 1.0)
			for k in (2 if kind != "shop" else 1):
				var bx: float = p.c.x + ((p.size as Vector2).x * 0.5 - 1.2) * (1.0 if k == 0 else -1.0)
				if Assets.has_model("trash_bin"):
					_ground_prop("trash_bin", Vector3(bx, 0, front_y), p.yaw + r.randf_range(-0.3, 0.3), "box", 0.8, 0.05)
			if kind in ["apartment", "hospital"] and Assets.has_model("bench"):
				_ground_prop("bench", Vector3(p.c.x + r.randf_range(-3.0, 3.0), 0, front_y + front_sign * 0.4), p.yaw, "box", 1.0, 0.05)
			if kind == "police":
				for k in 6:
					_ground_prop("sandbags", Vector3(p.c.x - 6.0 + k * 2.4, 0, front_y + front_sign * 1.2), p.yaw, "box", 1.0, 0.05, 0.8)
		"barracks", "depot":
			if kind == "barracks":
				_ground_prop("tank_wreck", Vector3(p.c.x - 4.0, 0, p.c.y + front_sign * ((p.size as Vector2).y * 0.5 + 5.0)), 0.6, "box", 1.0, 0.1, 0.5)
			for k in 5:
				_ground_prop("sandbags", Vector3(p.c.x - 5.0 + k * 2.4, 0, p.c.y + front_sign * ((p.size as Vector2).y * 0.5 + 1.6)), p.yaw, "box", 1.0, 0.05, 0.8)
	if kind == "factory":
		# brick chimney behind the hall
		var ch := Vector2(p.c.x + 8.0, p.c.y - (p.size as Vector2).y * 0.5 - 4.0)
		Geo.cylinder(self, 1.6, 26.0, _gy(Vector3(ch.x, 0, ch.y)) + Vector3(0, 12.5, 0), m_brick, Vector3(0.04, 0, 0.03), true)
		_blocked.append([ch, 2.5])


## Wooden picket fence around a lot, with a gate on the street side; ruins get gaps.
func _fence(lot: Rect2, edge: float, gate_x: float, broken: bool) -> void:
	var fi := town_rng.randi() % 3
	var wood: Material = _m("fence%d" % fi, func() -> Material: return Assets.pbr("wood_planks", {"tile": 0.9, "tint": [Color(0.55, 0.42, 0.3), Color(0.35, 0.5, 0.42), Color(0.4, 0.45, 0.58)][fi]}))
	var z_front := edge
	var z_back := lot.position.y if absf(lot.end.y - edge) < 0.01 else lot.end.y
	var x0 := lot.position.x
	var x1 := lot.end.x
	var runs := [[Vector2(x0, z_front), Vector2(x1, z_front), true], [Vector2(x0, z_back), Vector2(x1, z_back), false],
		[Vector2(x0, z_front), Vector2(x0, z_back), false], [Vector2(x1, z_front), Vector2(x1, z_back), false]]
	for run in runs:
		var a: Vector2 = run[0]
		var bb: Vector2 = run[1]
		var length := a.distance_to(bb)
		var dir := (bb - a) / length
		var yaw := atan2(-dir.y, dir.x)
		var gate_t := (gate_x - a.x) if run[2] else -99.0
		var t := 0.0
		var seg_start := 0.0
		while t <= length:
			var in_gate := absf(t - gate_t) < 0.9
			if in_gate or (broken and town_rng.randf() < 0.08):
				if t - seg_start > 0.3:
					_fence_collider(a, dir, seg_start, t, yaw)
				seg_start = t + 0.2
				t += 0.2
				continue
			var p := a + dir * t
			var y := terrain.height_at(p.x, p.y)
			var post := fmod(t, 2.0) < 0.19
			var h := 1.25 if post else town_rng.randf_range(1.0, 1.15)
			if town_rng.randf() < 0.07 and not post:
				t += 0.19
				continue
			var lean := town_rng.randf_range(-0.06, 0.06)
			_town.box_xf(wood, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean), Vector3(p.x, y + h * 0.5 - 0.1, p.y)),
				Vector3(0.09 if post else 0.07, h, 0.09 if post else 0.025))
			t += 0.19
		if length - seg_start > 0.3:
			_fence_collider(a, dir, seg_start, length, yaw)
		# rails
		var k := 0.0
		while k < length - 0.1:
			var k1 := minf(k + 2.0, length)
			if not (run[2] and absf((k + k1) * 0.5 - gate_t) < 1.4):
				var m := a + dir * ((k + k1) * 0.5)
				var y := terrain.height_at(m.x, m.y)
				for ry in [0.3, 0.85]:
					_town.box(wood, Vector3(m.x, y + ry, m.y), Vector3(k1 - k, 0.07, 0.04), yaw)
			k = k1


func _fence_collider(a: Vector2, dir: Vector2, t0: float, t1: float, yaw: float) -> void:
	var m := a + dir * ((t0 + t1) * 0.5)
	_town.collider(Transform3D(Basis(Vector3.UP, yaw), Vector3(m.x, terrain.height_at(m.x, m.y) + 0.55, m.y)), Vector3(t1 - t0, 1.2, 0.1))


## Village well: stone ring, two posts, a little roof and a crank.
func _well(c: Vector2) -> void:
	if _is_blocked(c):
		return
	var y := terrain.height_at(c.x, c.y)
	var stone: Material = _m("stone", func() -> Material: return Assets.pbr("portal_concrete", {"tile": 1.0, "tint": Color(0.72, 0.7, 0.66)}))
	var wood: Material = _m("wood_dark", func() -> Material: return Assets.pbr("wood_planks", {"tile": 0.8, "tint": Color(0.48, 0.34, 0.24)}))
	Geo.cylinder(self, 0.62, 0.85, Vector3(c.x, y + 0.4, c.y), stone, Vector3.ZERO, true, 16)
	Geo.cylinder(self, 0.5, 0.02, Vector3(c.x, y + 0.83, c.y), _m("dark", func() -> Material: return Geo.color_mat(Color(0.07, 0.07, 0.07), 0.6)), Vector3.ZERO, false, 16)
	for s in [-1.0, 1.0]:
		_town.box(wood, Vector3(c.x + s * 0.55, y + 1.05, c.y), Vector3(0.09, 2.1, 0.09))
	_town.box(wood, Vector3(c.x, y + 1.45, c.y), Vector3(1.2, 0.08, 0.08))
	for s in [-1.0, 1.0]:
		_town.box_xf(_m("tin", func() -> Material: return Assets.pbr("rusty_metal", {"tile": 1.6, "tint": Color(0.75, 0.72, 0.7)})),
			Transform3D(Basis(Vector3.RIGHT, s * 0.6), Vector3(c.x, y + 2.25, c.y + s * 0.3)), Vector3(1.4, 0.04, 0.75))
	_blocked.append([c, 1.2])


func _woodpile(c: Vector2, yaw: float) -> void:
	if _is_blocked(c):
		return
	var y := terrain.height_at(c.x, c.y)
	var wood: Material = _m("logs", func() -> Material: return Assets.pbr("wood_planks", {"tile": 0.5, "tint": Color(0.62, 0.48, 0.34)}))
	for row in 4:
		for k in 6 - row:
			var off := Vector3((k - (5 - row) * 0.5) * 0.24, 0.12 + row * 0.21, 0).rotated(Vector3.UP, yaw)
			_town.box(wood, Vector3(c.x, y, c.y) + off, Vector3(0.2, 0.2, 1.0), yaw + town_rng.randf_range(-0.05, 0.05))
	_town.collider(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y + 0.45, c.y)), Vector3(1.5, 0.9, 1.0))
	_blocked.append([c, 1.2])


## Abandoned vegetable garden: soil beds with dry stalks.
func _garden(c: Vector2, yaw: float) -> void:
	var soil: Material = _m("soil", func() -> Material: return Assets.pbr("soil", {"tile": 1.2}))
	for k in 3:
		var off := Vector3((k - 1) * 1.6, 0, 0).rotated(Vector3.UP, yaw)
		var p := Vector3(c.x, 0, c.y) + off
		var y := terrain.height_at(p.x, p.z)
		_town.box(soil, Vector3(p.x, y + 0.04, p.z), Vector3(0.9, 0.16, 5.0), yaw)
		if Assets.has_model("branches_dry"):
			for j in 3:
				var q := p + Vector3(0, 0, -1.6 + j * 1.6).rotated(Vector3.UP, yaw)
				_lite(Geo.prop(self, "branches_dry", Vector3(q.x, y + 0.08, q.z), town_rng.randf() * TAU, "none", 0.45), 60.0, false)


var _trunks := 0


## A wrecked car on the street; some of them have a searchable boot.
func _place_car(p: Vector3, yaw: float) -> void:
	var flat := Vector2(p.x, p.z)
	if _is_blocked(flat):
		return
	for b in _blocked:
		if flat.distance_to(b[0]) < float(b[1]) + 2.4:
			return
	_blocked.append([flat, 2.4])
	if _trunks < 4 and rng.randf() < 0.45:
		_trunks += 1
		var c := LootContainer.new()
		add_child(c)
		c.position = _gy(p, 0.08)
		c.rotation.y = yaw
		var m := Assets.model("car_wreck")
		c.add_child(m)
		Geo.fit_box(c, m, 1.0, 0.95)
		c.setup("car%d" % _trunks, "Portbagaj", _roll_kind("car"), false)
		c.set_ghost(false)
		_align(c, 0.85)
		containers.append(c)
	else:
		_ground_prop("car_wreck", p, yaw, "box", 1.0, 0.08, 0.85)


## Street furniture: parked and crashed cars, lamps, poles, the bus stop, signs, roadblocks.
func _dress_streets() -> void:
	var r := town_rng
	var main_yaw := atan2(6.0, SIZE * 1.5)
	var place_car := _place_car
	# parked along the curbs (both directions), a few slewed across the lane
	for i in 7:
		var x := r.randf_range(-42.0, 42.0)
		if absf(x) < 8.0:
			continue
		var side := 1.0 if r.randf() < 0.5 else -1.0
		place_car.call(Vector3(x, 0, _main_z(x) + side * (MAIN_HW - 1.15)), main_yaw + (PI if side < 0.0 else 0.0) + r.randf_range(-0.1, 0.1))
	for i in 4:
		var x := r.randf_range(-40.0, 40.0)
		if absf(x) < 7.0:
			continue
		var side := 1.0 if r.randf() < 0.5 else -1.0
		place_car.call(Vector3(x, 0, CROSS_Z + side * (STREET_HW - 1.0)), (PI if side < 0.0 else 0.0) + r.randf_range(-0.1, 0.1))
	for i in 3:
		var z := r.randf_range(-40.0, 10.0)
		if absf(z - CROSS_Z) < 7.0:
			continue
		var side := 1.0 if r.randf() < 0.5 else -1.0
		place_car.call(Vector3(side * (STREET_HW - 1.0), 0, z), PI * 0.5 * side + r.randf_range(-0.1, 0.1))
	place_car.call(Vector3(r.randf_range(-2.0, 2.0), 0, _main_z(0.0) + r.randf_range(-1.0, 1.0)), r.randf() * TAU)
	if loc_id in ["market", "police", "metro"]:
		_ground_prop("bus_wreck", Vector3(-24.0, 0, _main_z(-24.0) + 1.6), main_yaw + 0.15, "box", 1.0, 0.08, 0.8)
		_blocked.append([Vector2(-24.0, _main_z(-24.0) + 1.6), 6.0])
	_ground_prop("burnt_truck", Vector3(28.0, 0, CROSS_Z + 1.2), 0.2, "box", 1.0, 0.08, 0.8)
	_blocked.append([Vector2(28.0, CROSS_Z + 1.2), 4.0])
	# utility poles along the main street (south side), some knocked askew
	for i in 7:
		var x := -42.0 + i * 14.0 + r.randf_range(-1.5, 1.5)
		var z := _main_z(x) + MAIN_HW + 0.8
		if Rect2(x - 0.5, z - 0.5, 1, 1).intersects(PORTAL_CLEAR.grow(2.0)):
			continue
		var pole := _ground_prop("utility_pole", Vector3(x, 0, z), r.randf_range(-0.2, 0.2), "box", 1.0, 0.3)
		if r.randf() < 0.5:
			pole.rotation.z = r.randf_range(-0.22, 0.22)
		_blocked.append([Vector2(x, z), 0.8])
	# street lamps along the north-south street and the back street
	if Assets.has_model("street_lamp"):
		var k := 0
		var z := 12.0
		while z > -44.0:
			if absf(z - CROSS_Z) > 5.0:
				var side := 1.0 if k % 2 == 0 else -1.0
				_ground_prop("street_lamp", Vector3(side * (STREET_HW + 0.7), 0, z), PI if side > 0.0 else 0.0, "box", 0.85, 0.2)
				_blocked.append([Vector2(side * (STREET_HW + 0.7), z), 0.8])
			z -= 14.0
			k += 1
		for x in [-36.0, -20.0, 20.0, 36.0]:
			_ground_prop("street_lamp", Vector3(x, 0, CROSS_Z - STREET_HW - 0.7), PI * 0.5, "box", 0.85, 0.2)
	# bus stop on the main street, west of the crossing
	if Assets.has_model("bus_stop"):
		var bx := -8.5
		_ground_prop("bus_stop", Vector3(bx, 0, _main_z(bx) - MAIN_HW - 1.0), main_yaw + PI * 0.5, "box", 1.0, 0.05)
		_blocked.append([Vector2(bx, _main_z(bx) - MAIN_HW - 1.0), 2.0])
	# signs at the crossings
	for p in [Vector3(-STREET_HW - 1.2, 0, _main_z(-4.0) - MAIN_HW - 1.0), Vector3(STREET_HW + 1.2, 0, CROSS_Z + STREET_HW + 1.0)]:
		var sign := _ground_prop("road_sign", p, r.randf() * TAU, "box", 1.0, 0.1)
		sign.rotation.z = r.randf_range(-0.2, 0.2)
	# roadblocks where the streets leave the town + rubble from collapsed facades
	for e in [Vector3(-44.0, 0, _main_z(-44.0)), Vector3(44.0, 0, _main_z(44.0)), Vector3(0, 0, -43.0)]:
		for k in 3:
			var off := Vector3(0, 0, (k - 1) * 2.2) if absf(e.x) > 1.0 else Vector3((k - 1) * 2.2, 0, 0)
			if r.randf() < 0.8:
				_ground_prop("concrete_barrier", e + off, (PI * 0.5 if absf(e.x) > 1.0 else 0.0) + r.randf_range(-0.25, 0.25), "box", 1.0, 0.05, 0.9)
	for b in buildings:
		if b.damaged and r.randf() < 0.7:
			var fp := b.to_global(Vector3(r.randf_range(-b.size.x * 0.4, b.size.x * 0.4), 0, b.size.y * 0.5 + 1.0))
			Building.debris(_town, r, _gy(fp), 1.3, _rubble_mats(), 22)
	_town.commit(self)
	# distant silhouettes on the hills
	for i in 18:
		var a := float(i) / 18.0 * TAU + r.randf_range(-0.1, 0.1)
		var rad := r.randf_range(140, 280)
		var far_id: String = ["ruined_building", "ruin_block", "ruined_building", "ruin_house", "apartment_block"][i % 5]
		if not Assets.has_model(far_id):
			far_id = "ruined_building"
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		var bld := Geo.prop(self, far_id, Vector3(p.x, terrain.height_raw(p.x, p.z) - 1.5, p.z), r.randf() * TAU, "none", r.randf_range(1.2, 2.2))
		Assets.set_shadows(bld, false)


## A dead tree with a trunk-sized collider, rooted into the ground.
func _tree(id: String, p: Vector3, scale: float) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = _gy(p, 0.28 * scale)
	body.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05))
	var m := Assets.model(id)
	m.scale = Vector3.ONE * scale
	body.add_child(m)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.28 * scale
	cyl.height = 3.0 * scale
	cs.shape = cyl
	cs.position.y = 1.5 * scale
	body.add_child(cs)


## Dead trees, stumps, logs, rocks and boulders, all sitting on (and into) the ground.
func _nature() -> void:
	var tree_ids: Array = ["tree_dead", "tree_dead_b"] if Assets.has_model("tree_dead_b") else ["tree_dead"]
	for i in 14:
		var p := _free_spot(1.6)
		if terrain.slope_at(p.x, p.z) > 0.25:
			continue
		_tree(tree_ids[i % tree_ids.size()], p, rng.randf_range(0.75, 1.2))
		if rng.randf() < 0.45 and Assets.has_model("tree_stump"):
			var sp := p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
			if not _is_blocked(Vector2(sp.x, sp.z)):
				_lite(_ground_prop("tree_stump", sp, rng.randf() * TAU, "box", rng.randf_range(0.7, 1.1), 0.12, 0.6), 90.0)
	for i in 2:
		if Assets.has_model("log_fallen"):
			_ground_prop("log_fallen", _free_spot(3.5), rng.randf() * TAU, "box", rng.randf_range(0.7, 1.0), 0.18, 1.0)
	for i in 6:
		if Assets.has_model("branches_dry"):
			_lite(_ground_prop("branches_dry", _free_spot(1.2), rng.randf() * TAU, "none", rng.randf_range(0.7, 1.3), 0.05, 1.0), 70.0, false)
	# rocks: a few in the valley, many on the surrounding slopes
	var rocks: Array = []
	for id in ["rock_a", "rock_b", "stone_small"]:
		if Assets.has_model(id):
			rocks.append(id)
	if not rocks.is_empty():
		for i in 4:
			_lite(_ground_prop(rocks[i % rocks.size()], _free_spot(1.5), rng.randf() * TAU, "box", rng.randf_range(0.7, 1.4), 0.2, 1.0), 110.0)
		for i in 60:
			var a := rng.randf() * TAU
			var r := rng.randf_range(SIZE * 0.53, SIZE * 0.85)
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if absf(p.x) < 14.0 and p.z > PORTAL_Z - 8.0:
				continue
			_lite(_ground_prop(rocks[i % rocks.size()], p, rng.randf() * TAU, "none", rng.randf_range(0.8, 2.6), 0.25, 1.0), 150.0, false)
	if Assets.has_model("boulder"):
		for i in 2:
			_ground_prop("boulder", _free_spot(3.5), rng.randf() * TAU, "box", rng.randf_range(0.6, 1.0), 0.35, 0.8)
		for i in 10:
			var a := rng.randf() * TAU
			var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(SIZE * 0.56, SIZE * 0.9)
			if absf(p.x) < 14.0 and p.z > PORTAL_Z - 8.0:
				continue
			_lite(_ground_prop("boulder", p, rng.randf() * TAU, "none", rng.randf_range(0.8, 1.8), 0.4, 0.9), 220.0, false)
	# dead trees on the hills outside the playable area
	for i in 22:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(SIZE * 0.56, SIZE * 1.1)
		if absf(p.x) < 14.0 and p.z > PORTAL_Z - 8.0:
			continue
		var t := Assets.model(tree_ids[i % tree_ids.size()])
		add_child(t)
		Assets.set_shadows(t, false)
		var s := rng.randf_range(0.8, 1.4)
		t.scale = Vector3.ONE * s
		t.position = _gy(p, 0.3 * s)
		t.rotation.y = rng.randf() * TAU


func _bounds() -> void:
	# invisible walls on the slopes so the player stays in the playable area
	var e := SIZE * 0.5 + 2.0
	for s in [[Vector3(0, 6, -e), Vector3(SIZE + 8, 24, 1)], [Vector3(0, 6, e + 1.5), Vector3(SIZE + 8, 24, 1)],
			[Vector3(-e, 6, 0), Vector3(1, 24, SIZE + 8)], [Vector3(e, 6, 0), Vector3(1, 24, SIZE + 8)]]:
		Geo.collider(self, s[1], s[0])


func _spawn_hotspots(mult: float) -> void:
	for i in 2 + roundi(loc.danger):
		var p := _gy(_free_spot(4.0))
		var r := rng.randf_range(5.0, 9.0)
		hotspots.append([p, r, rng.randf_range(4.0, 8.0)])
		var glow := Geo.omni(self, p + Vector3(0, 0.6, 0), Color(0.55, 1.0, 0.4), 0.5, r * 0.7, false)
		glow.light_volumetric_fog_energy = 3.0
		var b := _ground_prop("oil_barrel", p + Vector3(0.6, 0, 0.3), rng.randf() * TAU, "box", 1.0, -0.3)
		b.rotation.z = PI * 0.5
		if Assets.has_model("radiation_sign"):
			_ground_prop("radiation_sign", p + Vector3(r * 0.8, 0, 0).rotated(Vector3.UP, rng.randf() * TAU), rng.randf() * TAU, "box", 1.0, 0.15)
		else:
			Geo.label3d(self, "☢ PERICOL", p + Vector3(0, 2.0, 0), rng.randf() * TAU, 0.4, Color(0.95, 0.85, 0.2))


func _spawn_enemies() -> void:
	var n := roundi(loc.danger * 3.0 + State.day * 0.15)
	var mix: Array = ENEMY_MIX.get(loc_id, ["mutant"])
	var i := 0
	while i < n:
		var kind: String = mix[rng.randi() % mix.size()]
		if Enemy.model_for(kind) == "":
			kind = "mutant"
		var p := _free_spot(2.0)
		var flat := Vector2(p.x, p.z)
		var ex := Vector2(exit_pos.x, exit_pos.z)
		if flat.distance_to(ex) < 28.0:
			var d := (flat - ex).normalized()
			d.y = -absf(d.y)
			p = Vector3(ex.x + d.x * 32.0, 0, ex.y + d.y * 32.0)
		var pack := rng.randi_range(2, 3) if kind == "dog" else 1
		for k in pack:
			var e := Enemy.new()
			e.kind = kind
			e.level_ref = self
			e.position = _gy(p + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))) + Vector3(0, 0.15, 0)
			e.max_hp = 80.0 + loc.danger * 25.0
			e.damage = 10.0 + loc.danger * 4.0
			add_child(e)
			enemies.append(e)
		i += pack
	# after the raid (held or not) the Corbii wait for you outside, once
	if String(State.flags.get("corbii", "")) in ["raided", "repelled"] and not State.flags.has("corbii_ambush"):
		State.flags["corbii_ambush"] = true
		for k in 2:
			var e := Enemy.new()
			e.kind = "bandit"
			e.level_ref = self
			# in front of the exit only (it sits in the hill at the south edge): a fan
			# toward the town, inside the playable area, not on a building
			var spot := exit_pos
			for tries in 12:
				var ang := -PI * 0.5 + rng.randf_range(-0.95, 0.95)  # -Z (north) +- 55 deg
				var dist := rng.randf_range(20.0, 30.0)
				spot = exit_pos + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
				spot.x = clampf(spot.x, -SIZE * 0.45, SIZE * 0.45)
				spot.z = clampf(spot.z, -SIZE * 0.45, SIZE * 0.4)
				if not _is_blocked(Vector2(spot.x, spot.z)):
					break
			e.position = _gy(spot) + Vector3(0, 0.15, 0)
			e.max_hp = 95.0
			e.damage = 12.0
			add_child(e)
			enemies.append(e)
		HUD.toast("Corbii te așteptau lângă ieșire.", "danger")


func open_local_map() -> void:
	HUD.open_panel(LocalMapPanel.new(self))


func map_config() -> Dictionary:
	var markers: Array = [{"pos": exit_pos, "icon": "objective", "color": Color(1.0, 0.6, 0.15), "label": "Ieșirea 4"}]
	var left := 0
	for c in containers:
		if is_instance_valid(c) and not c.searched:
			left += 1
	# one marker per building: how many places in it are still unsearched
	for b in buildings:
		var n := 0
		for c in b.containers:
			if not c.searched:
				n += 1
		markers.append({"pos": b.global_position, "icon": "res", "color": UITheme.ACCENT if n > 0 else Color(0.5, 0.5, 0.48, 0.7), "label": str(n) if n > 0 else "", "small": true})
	for c in get_children():
		if c is LootContainer:
			markers.append({"pos": c.global_position, "icon": "res", "color": UITheme.ACCENT if not c.searched else Color(0.5, 0.5, 0.48, 0.7), "small": true})
	if State.count("geiger") > 0:
		for h in hotspots:
			markers.append({"pos": h[0], "icon": "rad", "color": Color(0.6, 1.0, 0.35), "ring": float(h[1]), "small": true})
	return {"center": Vector2.ZERO, "extent": SIZE + 12.0, "height": 160.0, "far": 400.0, "ambient": 0.55,
		"markers": markers, "title": loc.name, "subtitle": "Ziua %d · %s · filtru %d:%02d" % [State.day, State.clock_text(), int(State.mask_filter_left) / 60, int(State.mask_filter_left) % 60],
		"legend": [["objective", Color(1.0, 0.6, 0.15), "Ieșirea 4 a adăpostului (întoarcere)"], ["res", UITheme.ACCENT, "Clădire cu locuri necercetate (număr)"],
			["res", Color(0.5, 0.5, 0.48), "Clădire cercetată"], ["rad", Color(0.6, 1.0, 0.35), "Zonă radioactivă (necesită Geiger)"]],
		"info": ["Clădiri: %d  ·  locuri de cercetat: %d" % [buildings.size(), left], "Radiație absorbită: %d mSv" % roundi(State.radiation), "Rucsac: %.1f / %d kg" % [State.total_weight(), int(State.carry_max)]]}


## Bandit drops: a small searchable bag.
func drop_loot(pos: Vector3, items: Dictionary) -> void:
	var clean := {}
	for k in items:
		if int(items[k]) > 0:
			clean[k] = items[k]
	var c := LootContainer.new()
	add_child(c)
	c.position = _gy(pos + Vector3(0.6, 0, 0.3))
	var m := Assets.model("military_crate")
	m.scale = Vector3.ONE * 0.55
	c.add_child(m)
	Geo.fit_box(c, m, 0.55, 1.0)
	c.setup("drop%d" % Time.get_ticks_msec(), "Rucsacul jefuitorului", clean, false)
	c.set_ghost(true)


# --------------------------------------------------------------------------
# Runtime
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _leaving or State.dead:
		return
	# filter
	State.mask_filter_left -= delta
	if State.mask_filter_left <= 0.0:
		if State.remove("mask_filter"):
			State.mask_filter_left = 360.0
			Audio.sfx("reload", -4.0)
			HUD.toast("Filtru nou înșurubat în mască.", "info")
			_choke_warned = false
		else:
			State.mask_filter_left = 0.0
			State.damage(6.0 * delta, "suffocation")
			player.add_shake(0.1)
			if not _choke_warned:
				_choke_warned = true
				HUD.toast("FILTRUL S-A TERMINAT! Întoarce-te imediat!", "danger")
	HUD.set_marker("exit", exit_pos + Vector3(0, 2.0, 0), Color(1.0, 0.6, 0.15), "objective")
	if State.mask_filter_left < 60.0 and State.count("mask_filter") == 0:
		HUD.waypoint = exit_pos + Vector3(0, 2.0, 0)
		HUD.objective("Filtrul se termină!\nÎntoarce-te la ieșirea 4 a adăpostului.")
	else:
		HUD.waypoint = null
		HUD.objective("Caută provizii în %s.\nÎntoarcerea: ieșirea 4 (girofarul portocaliu)." % loc.name)
	# radiation
	var p := player.global_position
	var base := float(loc.rad) * State.surface_rad_mult() * 0.4
	var zone := 1.0
	for h in hotspots:
		var d := p.distance_to(h[0])
		if d < h[1]:
			zone += float(h[2]) * (1.0 - d / float(h[1]))
	var shield := 0.3 * State.mul("suit") if State.count("hazmat_suit") > 0 else 1.0
	_dose_rate = (base * zone + extra_rad) * shield
	extra_rad = 0.0
	State.radiation += _dose_rate * delta
	HUD.rad_effect = clampf((_dose_rate - 0.3) / 3.0, 0.0, 0.8)
	_geiger_t -= delta
	if _geiger_t <= 0.0:
		_geiger_t = clampf(1.0 / (0.5 + _dose_rate * 9.0), 0.02, 1.5) * randf_range(0.3, 1.7)
		if State.count("geiger") > 0 or _dose_rate > 1.0:
			Audio.sfx("geiger_click", -10.0, 0.2)
	# weight: one rule everywhere (the player slows down past State.carry_max, which the
	# backpack upgrade raises); the HUD shows the whole backpack against that limit
	HUD.set_surface_status(State.mask_filter_left, State.count("mask_filter"), _dose_rate if State.count("geiger") > 0 else -1.0, State.total_weight(), State.carry_max, player.weapon_text())


## Gunshots and explosions alert nearby enemies.
func noise(pos: Vector3, radius: float) -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.hear(pos, radius)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	State.flags["visits_" + loc_id] = int(State.flags.get("visits_" + loc_id, 0)) + 1
	HUD.mask_effect = 0.0
	HUD.rad_effect = 0.0
	Audio.ambient("breath", "", 0.0, 1.0)
	Game.return_to_bunker()
