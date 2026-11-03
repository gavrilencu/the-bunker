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
## POI ruins per location: [center, w, d, h, material key]
const POI := {
	"market": [[Vector3(0, 0, -10), 34.0, 22.0, 6.0, "wall"]],
	"hospital": [[Vector3(0, 0, -12), 40.0, 18.0, 10.0, "wall"], [Vector3(-26, 0, 8), 14.0, 22.0, 8.0, "wall"]],
	"police": [[Vector3(0, 0, -8), 24.0, 16.0, 7.0, "brick"]],
	"metro": [[Vector3(0, 0, -6), 26.0, 14.0, 4.0, "wall"]],
	"military": [[Vector3(-14, 0, -14), 20.0, 12.0, 4.5, "wall"], [Vector3(16, 0, -18), 18.0, 14.0, 5.0, "wall"]],
	"factory": [[Vector3(-10, 0, -12), 30.0, 20.0, 9.0, "brick"], [Vector3(22, 0, 2), 16.0, 22.0, 7.0, "brick"]],
}
var _blocked: Array = []  # [center Vector2, radius]
var _poi_h: Array = []    # pad height per POI ruin

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
	var mult := State.surface_rad_mult()
	make_environment({
		"hdri": "sky_overcast", "sky_energy": 0.55, "exposure": 0.95, "fog_density": 0.005,
		"fog_color": Color(0.5, 0.44, 0.36), "aerial": 0.8, "sun_scatter": 0.3, "fog_sky_affect": 0.55,
		"vfog_density": 0.011 + 0.01 * mult, "vfog_albedo": Color(0.72, 0.64, 0.52), "vfog_length": 110.0,
		"vfog_ambient": 0.6, "ambient_energy": 0.7, "saturation": 0.72, "contrast": 1.1,
		"profile": {"vfog": true, "ssil": false},
	})
	make_sun(Vector2(-28, 140), Color(1.0, 0.78, 0.55), 0.85, 110.0)
	m_wall = Assets.pbr("concrete_wall", {"tile": 2.5, "tint": Color(0.75, 0.72, 0.68)})
	m_brick = Assets.pbr("brick_wall", {"tile": 2.5, "tint": Color(0.55, 0.5, 0.48)})
	m_metal = Assets.pbr("rusty_metal", {"tile": 2.0})
	m_concrete = Assets.pbr("concrete_floor", {"tile": 3.0, "tint": Color(0.7, 0.68, 0.64)})

	_build_terrain()
	_build_portal()
	_build_poi()
	_scatter()
	_nature()
	_bounds()
	_spawn_loot()
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
	return false


func _free_spot(radius: float, tries := 40) -> Vector3:
	for i in tries:
		var p := Vector2(rng.randf_range(-SIZE * 0.45, SIZE * 0.45), rng.randf_range(-SIZE * 0.45, SIZE * 0.42))
		var ok := true
		for b in _blocked:
			if p.distance_to(b[0]) < radius + float(b[1]):
				ok = false
				break
		if ok and terrain and radius > 2.5 and terrain._road_mask(p.x, p.y) > 0.3:
			ok = false
		if ok:
			_blocked.append([p, radius])
			return Vector3(p.x, 0, p.y)
	return Vector3(rng.randf_range(-SIZE * 0.4, SIZE * 0.4), 0, rng.randf_range(-SIZE * 0.4, SIZE * 0.35))


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
	# roads: a main street across the valley, a service road down to the shelter exit
	terrain.add_road(Vector2(-SIZE * 0.75, 25.0), Vector2(SIZE * 0.75, 19.0), 3.4)
	terrain.add_road(Vector2(0, PORTAL_Z - BunkerPortal.TRENCH - 1.0), Vector2(0.5, 21.0), 2.4)
	# building pads (ruins stand on flattened ground)
	_poi_h.clear()
	for r in POI.get(loc_id, POI.factory):
		var c: Vector3 = r[0]
		var half_diag := Vector2(float(r[1]), float(r[2])).length() * 0.5
		_poi_h.append(terrain.add_pad(c, half_diag + 0.6, 7.0))
		_blocked.append([Vector2(c.x, c.z), maxf(float(r[1]), float(r[2])) * 0.6])
	# bomb craters in the open
	for i in 3 + rng.randi_range(0, 3):
		var p := _free_spot(6.5)
		var rad := rng.randf_range(3.2, 6.5)
		terrain.add_crater(Vector2(p.x, p.z), rad, rad * rng.randf_range(0.22, 0.32))
	terrain.build()


func _build_portal() -> void:
	portal = BunkerPortal.new()
	portal.name = "ShelterExit"
	add_child(portal)
	portal.position = Vector3(0, exit_pos.y, PORTAL_Z)
	portal.build()
	portal.prompt_text = "Ieșirea 4 — Coboară în buncăr  (%.1f h)" % (float(loc.travel) * State.mul("travel"))
	portal.on_enter = _leave


## A ruined building shell with doorways and broken walls; returns interior spots.
func _ruin(center: Vector3, w: float, d: float, h: float, mat: Material) -> Array:
	var spots: Array = []
	Geo.plane(self, Vector2(w, d), center + Vector3(0, 0.05, 0), m_concrete)
	var t := 0.4
	var sides := [
		[Vector3(0, 0, -d * 0.5), w, 0.0], [Vector3(0, 0, d * 0.5), w, 0.0],
		[Vector3(-w * 0.5, 0, 0), d, PI * 0.5], [Vector3(w * 0.5, 0, 0), d, PI * 0.5],
	]
	var modular := Assets.has_model("ruin_wall_a") and Assets.has_model("ruin_wall_b")
	for si in sides.size():
		var s: Array = sides[si]
		var length: float = s[1]
		if modular:
			_modular_side(center + s[0], length, float(s[2]), si == 1)
			continue
		var seg := 3.0
		var n := int(length / seg)
		var door_i := rng.randi_range(1, maxi(n - 2, 1))
		for i in n:
			if i == door_i and (si == 1 or rng.randf() < 0.5):
				continue
			if rng.randf() < 0.12:
				continue
			var hh := h * rng.randf_range(0.35, 1.0)
			var off := -length * 0.5 + seg * (i + 0.5)
			var local := Vector3(off, 0, 0).rotated(Vector3.UP, s[2])
			var pos: Vector3 = center + s[0] + local + Vector3(0, hh * 0.5, 0)
			Geo.box(self, Vector3(seg + 0.02, hh, t), pos, mat, s[2])
	if modular:
		for i in rng.randi_range(1, 3):
			var dp := center + Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0.05, rng.randf_range(-d * 0.3, d * 0.3))
			var slab := Geo.prop(self, "debris_slab", dp, rng.randf() * TAU)
			slab.rotation.z = rng.randf_range(-0.35, 0.35)
	for i in 6:
		spots.append(center + Vector3(rng.randf_range(-w * 0.4, w * 0.4), 0, rng.randf_range(-d * 0.4, d * 0.4)))
	return spots


var poi_spots: Array = []


## One side of a ruined building made of real wall pieces (models are long on Z).
func _modular_side(mid: Vector3, length: float, rot: float, front: bool) -> void:
	var x := -length * 0.5
	var door_at := rng.randf_range(-length * 0.25, length * 0.25)
	var door_done := false
	while x < length * 0.5 - 1.0:
		if not door_done and (front or rng.randf() < 0.5) and x + 2.5 > door_at:
			door_done = true
			x += 2.6
			continue
		var piece := "ruin_wall_a" if rng.randf() < 0.55 else "ruin_wall_b"
		var seg := 5.0 if piece == "ruin_wall_a" else 7.0
		if x + seg > length * 0.5 + 1.5:
			seg = 5.0
			piece = "ruin_wall_a"
		if rng.randf() < 0.1:
			x += seg
			continue
		var along := Vector3(x + seg * 0.5, 0, 0).rotated(Vector3.UP, rot)
		var wall := Geo.prop(self, piece, mid + along + Vector3(0, -0.05, 0), rot + PI * 0.5 + (PI if rng.randf() < 0.5 else 0.0))
		if rng.randf() < 0.3:
			Geo.prop(self, "rubble_pile", mid + along + Vector3(0, 0, 1.3).rotated(Vector3.UP, rot) * (1.0 if front else -1.0), rng.randf() * TAU, "none", rng.randf_range(0.35, 0.6))
		wall.set_meta("ruin", true)
		x += seg


func _build_poi() -> void:
	var list: Array = POI.get(loc_id, POI.factory)
	poi_spots = []
	for i in list.size():
		var r: Array = list[i]
		var c: Vector3 = r[0]
		c.y = float(_poi_h[i])
		poi_spots += _ruin(c, float(r[1]), float(r[2]), float(r[3]), m_brick if r[4] == "brick" else m_wall)
	var base: float = float(_poi_h[0]) if _poi_h.size() > 0 else 0.0
	match loc_id:
		"market":
			Geo.label3d(self, "UNIC", Vector3(0, base + 6.6, 1.2), 0.0, 1.6, Color(0.8, 0.3, 0.25))
			for i in 4:
				poi_spots.append(Vector3(-12.0 + i * 8.0, base, -10))
		"hospital":
			Geo.label3d(self, "SPITALUL RAIONAL", Vector3(0, base + 9.0, -2.8), 0.0, 1.0, Color(0.85, 0.85, 0.8))
		"police":
			Geo.label3d(self, "POLIȚIA", Vector3(0, base + 6.2, 0.2), 0.0, 1.0, Color(0.3, 0.45, 0.85))
		"metro":
			Geo.label3d(self, "M", Vector3(0, base + 5.2, 1.3), 0.0, 2.6, Color(0.9, 0.2, 0.15))
			Geo.label3d(self, "PIAȚA UNIRII", Vector3(0, base + 3.9, 1.3), 0.0, 0.7, Color(0.9, 0.88, 0.8))
			for i in 3:
				_ground_prop("bus_wreck", Vector3(-20 + i * 18, 0, 14), 0.2 + i * 0.4, "box", 1.0, 0.05, 0.6)
		"military":
			_ground_prop("tank_wreck", Vector3(4, 0, 4), 0.7, "box", 1.0, 0.1, 0.5)
			_blocked.append([Vector2(4, 4), 5.0])
			for i in 8:
				_ground_prop("sandbags", Vector3(-10 + i * 1.3, 0, 10), 0.0, "box", 1.0, 0.03, 0.8)
		_:
			var ch := Vector3(30, 0, -30)
			Geo.cylinder(self, 2.6, 30.0, _gy(ch) + Vector3(0, 14.5, 0), m_brick, Vector3(0.12, 0, 0.08), true)


func _scatter() -> void:
	for i in 6:
		var p := _free_spot(9.0)
		var b := _ground_prop("ruined_building", p, rng.randf() * TAU, "box", rng.randf_range(0.7, 1.1), 0.4)
		Assets.set_shadows(b, true)
	for i in 9:
		_ground_prop("car_wreck", _free_spot(3.0), rng.randf() * TAU, "box", 1.0, 0.08, 0.85)
	if loc_id in ["market", "police"]:
		for i in 3:
			_ground_prop("bus_wreck" if i == 0 else "car_wreck", _free_spot(5.0), rng.randf() * TAU, "box", 1.0, 0.08, 0.8)
	for i in 14:
		_ground_prop("rubble_pile", _free_spot(2.0), rng.randf() * TAU, "box", rng.randf_range(0.6, 1.4), 0.15, 0.7)
	for id in ["ruin_house", "ruin_block", "ruin_house"]:
		if Assets.has_model(id):
			_ground_prop(id, _free_spot(8.0), rng.randf() * TAU, "box", 1.0, 0.35)
	for i in 2:
		_ground_prop("burnt_truck", _free_spot(4.0), rng.randf() * TAU, "box", 1.0, 0.08, 0.8)
	for i in 4:
		_ground_prop("tire_pile", _free_spot(1.2), rng.randf() * TAU, "box", 1.0, 0.05, 0.9)
	for i in 5:
		_ground_prop("scrap_pile", _free_spot(1.8), rng.randf() * TAU, "none", 1.0, 0.1, 0.9)
	for i in 4:
		_ground_prop("debris_slab", _free_spot(2.0), rng.randf() * TAU, "box", 1.0, 0.1, 0.9)
	for i in 3:
		var sign := _ground_prop("road_sign", _free_spot(0.8), rng.randf() * TAU, "box", 1.0, 0.1)
		sign.rotation.z = rng.randf_range(-0.3, 0.3)
	if loc_id == "market":
		for i in 2:
			_ground_prop("shop_ruin", _free_spot(4.0), rng.randf() * TAU, "box", 1.0, 0.2)
	# utility poles along the main street, some knocked askew
	for i in 7:
		var x := -42.0 + i * 14.0 + rng.randf_range(-2.0, 2.0)
		var z := lerpf(25.0, 19.0, (x + SIZE * 0.75) / (SIZE * 1.5)) + 5.2
		var pole := _ground_prop("utility_pole", Vector3(x, 0, z), rng.randf_range(-0.2, 0.2), "box", 1.0, 0.3)
		if rng.randf() < 0.6:
			pole.rotation.z = rng.randf_range(-0.28, 0.28)
		_blocked.append([Vector2(x, z), 0.8])
	for i in 8:
		_ground_prop("concrete_barrier", _free_spot(1.5), rng.randf() * TAU, "box", 1.0, 0.05, 0.9)
	# distant silhouettes on the hills
	for i in 18:
		var a := float(i) / 18.0 * TAU + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(140, 280)
		var far_id: String = ["ruined_building", "ruin_block", "ruined_building", "ruin_house", "apartment_block"][i % 5]
		if not Assets.has_model(far_id):
			far_id = "ruined_building"
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var b := Geo.prop(self, far_id, Vector3(p.x, terrain.height_raw(p.x, p.z) - 1.5, p.z), rng.randf() * TAU, "none", rng.randf_range(1.2, 2.2))
		Assets.set_shadows(b, false)


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
	for i in 4:
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
		for i in 10:
			_lite(_ground_prop(rocks[i % rocks.size()], _free_spot(1.0), rng.randf() * TAU, "box", rng.randf_range(0.7, 1.6), 0.2, 1.0), 110.0)
		for i in 60:
			var a := rng.randf() * TAU
			var r := rng.randf_range(SIZE * 0.53, SIZE * 0.85)
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if absf(p.x) < 14.0 and p.z > PORTAL_Z - 8.0:
				continue
			_lite(_ground_prop(rocks[i % rocks.size()], p, rng.randf() * TAU, "none", rng.randf_range(0.8, 2.6), 0.25, 1.0), 150.0, false)
	if Assets.has_model("boulder"):
		for i in 3:
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
	for i in 26:
		var a := float(i) / 26.0 * TAU
		var r := SIZE * 0.5 + 3.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < 14.0 and p.z > 0.0:
			continue
		_lite(_ground_prop("rubble_pile", p, rng.randf() * TAU, "none", rng.randf_range(1.5, 2.5), 0.3, 0.8), 200.0, false)


func _roll_loot(n_entries: int) -> Dictionary:
	var table: Dictionary = loc.loot
	var keys := table.keys()
	var out := {}
	var visits := int(State.flags.get("visits_" + loc_id, 0))
	var scarcity := clampf(1.0 - visits * 0.12, 0.4, 1.0)
	for i in n_entries:
		var k: String = keys[rng.randi() % keys.size()]
		var maxn: int = table[k]
		var n := maxi(1, roundi(rng.randf_range(0.3, 0.75) * maxn * scarcity))
		if k in ["pistol", "hazmat_suit", "gas_mask", "fuel_can"]:
			n = 1
		out[k] = int(out.get(k, 0)) + n
	return out


func _spawn_loot() -> void:
	var models := ["wooden_crate", "military_crate", "metal_shelf", "locker", "oil_barrel", "first_aid_kit", "toolbox", "supermarket_shelf"]
	var names := {"wooden_crate": "Ladă", "military_crate": "Ladă militară", "metal_shelf": "Raft", "locker": "Dulap",
		"oil_barrel": "Butoi", "first_aid_kit": "Trusă medicală", "toolbox": "Trusă de scule", "supermarket_shelf": "Raft de magazin"}
	var count := 11 + roundi(loc.danger * 2.0)
	for i in count:
		var p: Vector3
		if i < poi_spots.size():
			p = poi_spots[i]
		else:
			p = _gy(_free_spot(1.5))
		var model: String = models[rng.randi() % models.size()]
		if loc_id == "market" and rng.randf() < 0.6:
			model = "supermarket_shelf"
		elif loc_id == "hospital" and rng.randf() < 0.4:
			model = "first_aid_kit"
		elif loc_id in ["military", "police"] and rng.randf() < 0.5:
			model = "military_crate"
		var c := LootContainer.new()
		add_child(c)
		c.position = p + Vector3(0, 0.04, 0)
		c.rotation.y = rng.randf() * TAU
		var m := Assets.model(model)
		c.add_child(m)
		Geo.fit_box(c, m, 1.0, 1.0)
		var items := _roll_loot(rng.randi_range(1, 3)) if rng.randf() > 0.15 else {}
		c.setup("s%d" % i, names.get(model, "Container"), items, false)
		c.set_ghost(false)
	# a few wrecked cars can be searched too
	for i in 3:
		var c := LootContainer.new()
		add_child(c)
		c.position = _gy(_free_spot(3.0), 0.08)
		c.rotation.y = rng.randf() * TAU
		var m := Assets.model("car_wreck")
		c.add_child(m)
		Geo.fit_box(c, m, 1.0, 0.95)
		c.setup("car%d" % i, "Portbagaj", _roll_loot(2), false)
		c.set_ghost(false)
		_align(c, 0.85)


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


func open_local_map() -> void:
	HUD.open_panel(LocalMapPanel.new(self))


func map_config() -> Dictionary:
	var markers: Array = [{"pos": exit_pos, "icon": "objective", "color": Color(1.0, 0.6, 0.15), "label": "Ieșirea 4"}]
	var left := 0
	for c in get_children():
		if c is LootContainer:
			if not c.searched:
				left += 1
			markers.append({"pos": c.global_position, "icon": "res", "color": UITheme.ACCENT if not c.searched else Color(0.5, 0.5, 0.48, 0.7), "small": true})
	if State.count("geiger") > 0:
		for h in hotspots:
			markers.append({"pos": h[0], "icon": "rad", "color": Color(0.6, 1.0, 0.35), "ring": float(h[1]), "small": true})
	return {"center": Vector2.ZERO, "extent": SIZE + 12.0, "height": 160.0, "far": 400.0, "ambient": 0.55,
		"markers": markers, "title": loc.name, "subtitle": "Ziua %d · %s · filtru %d:%02d" % [State.day, State.clock_text(), int(State.mask_filter_left) / 60, int(State.mask_filter_left) % 60],
		"legend": [["objective", Color(1.0, 0.6, 0.15), "Ieșirea 4 a adăpostului (întoarcere)"], ["res", UITheme.ACCENT, "Container necercetat"],
			["res", Color(0.5, 0.5, 0.48), "Container gol"], ["rad", Color(0.6, 1.0, 0.35), "Zonă radioactivă (necesită Geiger)"]],
		"info": ["Containere rămase: %d" % left, "Radiație absorbită: %d mSv" % roundi(State.radiation), "Rucsac: %.1f / %d kg" % [State.total_weight(), int(State.carry_max)]]}


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
	# weight
	var w := State.total_weight() - start_weight
	player.speed_mult = 0.72 if w > CARRY else 1.0
	HUD.set_surface_status(State.mask_filter_left, State.count("mask_filter"), _dose_rate if State.count("geiger") > 0 else -1.0, maxf(w, 0.0), CARRY, player.weapon_text())


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
