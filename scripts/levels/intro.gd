extends LevelBase
## Act I — "Ziua Zero": bus stop -> sirens -> flash -> reach Obiectivul 17 and seal the door.

const FLASH_AT := 42.0
const BLAST_POS := Vector3(-4200, 0, -2300)
## Bunker entrance geometry (stairwell going north / -Z and down).
const SW_X0 := 73.0
const SW_X1 := 77.0
const SW_Z_TOP := -49.5
const SW_Z_HOLE := -56.0
const SW_Z_BOTTOM := -62.0
const DEPTH := -6.0
const DOOR_Z := -70.0
const AIRLOCK_Z1 := -78.0
## Where Alex waits for the bus (on the south sidewalk, facing the street).
const BUS_STOP := Vector3(0, 0.15, 7.0)

var t := 0.0
var flashed := false
var shock_arrived := false
var door_closed := false
var door_closing := false
var impact_done := false
var dead := false
var _impact_at := -1.0
var _seismic_done := false
var nuke: NukeBlast
var door_pivot: Node3D
var siren_pole: Node3D
var airlock_lights: Array[Light3D] = []
var ash: GPUParticles3D
var _events := {}
## the living town around the bus stop (traffic, people, lights)
var city: CityLife
var factory: FactorySite

var m_grass: Material
var m_asphalt: Material
var m_concrete: Material
var m_wall: Material
var m_brick: Material
var m_metal: Material
var m_pave: Material


func _ready() -> void:
	State.context = "intro"
	State.running = false
	HUD.set_mode("intro")
	_materials()
	make_environment({
		"hdri": "sky_morning", "sky_energy": 1.0, "exposure": 1.0, "fog_density": 0.00035,
		"fog_color": Color(0.72, 0.76, 0.82), "aerial": 0.6, "sun_scatter": 0.2, "glow": 0.35,
		"ambient_energy": 0.9, "profile": {"vfog": false, "ssil": true}, "fog_sky_affect": 0.05,
	})
	make_sun(Vector2(-19, 62), Color(1.0, 0.9, 0.78), 1.6, 160.0)
	_build_ground()
	_build_street()
	_build_factory()
	_build_entrance()
	_build_city()
	city = CityLife.new()
	city.name = "CityLife"
	add_child(city)
	city.build()
	factory.spawn_workers(city)
	nuke = NukeBlast.new()
	add_child(nuke)
	nuke.position = BLAST_POS
	# inside the shelter, in front of the seats, looking at the street
	spawn_player(BUS_STOP + Vector3(0.6, 0.05, -0.32), 0.0, 2.0)
	player.footstep_surface = "concrete"
	Audio.ambient("bg", "ambient_morning", -4.0, 2.0)
	Settings.set_reverb(0.05, 0.3)
	if Game.args.has("skip"):
		t = float(Game.args.skip)


func _materials() -> void:
	m_grass = Assets.pbr("grass", {"tile": 3.0, "fallback": Color(0.28, 0.36, 0.2)})
	m_asphalt = Assets.pbr("asphalt", {"tile": 5.0, "fallback": Color(0.16, 0.16, 0.17)})
	m_concrete = Assets.pbr("concrete_floor", {"tile": 3.0, "fallback": Color(0.5, 0.5, 0.48)})
	m_wall = Assets.pbr("concrete_wall", {"tile": 2.5, "fallback": Color(0.55, 0.55, 0.52)})
	m_brick = Assets.pbr("brick_wall", {"tile": 2.5, "fallback": Color(0.45, 0.25, 0.2)})
	m_metal = Assets.pbr("rusty_metal", {"tile": 2.0, "fallback": Color(0.35, 0.28, 0.22)})
	m_pave = Assets.pbr("pavement", {"tile": 2.0, "fallback": Color(0.55, 0.54, 0.5)})


# --------------------------------------------------------------------------
# World
# --------------------------------------------------------------------------

## Plane covering `rect` (x0, z0, x1, z1) minus `hole`, as up to 4 pieces.
func _holed(rect: Rect2, hole: Rect2, y: float, mat: Material, collide: bool, surface: String) -> void:
	var pieces: Array[Rect2] = []
	var r := rect
	var h := hole.intersection(rect)
	if h.size == Vector2.ZERO:
		pieces.append(r)
	else:
		pieces.append(Rect2(r.position.x, r.position.y, r.size.x, h.position.y - r.position.y))  # north (smaller z)
		pieces.append(Rect2(r.position.x, h.end.y, r.size.x, r.end.y - h.end.y))  # south
		pieces.append(Rect2(r.position.x, h.position.y, h.position.x - r.position.x, h.size.y))  # west
		pieces.append(Rect2(h.end.x, h.position.y, r.end.x - h.end.x, h.size.y))  # east
	for p in pieces:
		if p.size.x <= 0.01 or p.size.y <= 0.01:
			continue
		var c := Vector3(p.position.x + p.size.x * 0.5, y, p.position.y + p.size.y * 0.5)
		var node := Geo.plane(self, p.size, c, mat, collide)
		node.set_meta("surface", surface)


func _build_ground() -> void:
	var hole := Rect2(SW_X0, SW_Z_HOLE, SW_X1 - SW_X0, SW_Z_TOP - SW_Z_HOLE)
	_holed(Rect2(-3000, -3000, 6000, 6000), hole, 0.0, m_grass, true, "grass")
	# factory yard (concrete) — visual layer slightly above the grass
	_holed(Rect2(-130, -150, 360, 141), hole, 0.04, m_concrete, false, "concrete")


func _build_street() -> void:
	Geo.plane(self, Vector2(6000, 10), Vector3(0, 0.05, 0), m_asphalt)
	# lane markings (one merged mesh) — gap at the zebra crossing
	var white := Geo.color_mat(Color(0.85, 0.85, 0.8), 0.6)
	var marks := BoxBatch.new()
	for i in range(-60, 61):
		if absf(i * 8.0 - 6.0) > 3.0:
			marks.box(white, Vector3(i * 8.0, 0.062, 0), Vector3(3.0, 0.01, 0.15))
	marks.commit(self, false)
	# sidewalks with curbs
	Geo.box(self, Vector3(6000, 0.15, 3.0), Vector3(0, 0.075, 6.5), m_pave, 0.0, false)
	Geo.box(self, Vector3(6000, 0.15, 3.0), Vector3(0, 0.075, -6.5), m_pave, 0.0, false)
	# bus stop where Alex waits: open side (model +X) toward the street; real walls instead
	# of a solid box so the player can stand inside it
	var stop := Geo.prop(self, "bus_stop", BUS_STOP, PI * 0.5, "none")
	var stop_body := StaticBody3D.new()
	stop.add_child(stop_body)
	# model space: glass back at x -0.75, side panels at z +-1.95, seats along the back, roof
	for s in [[Vector3(-0.75, 1.3, 0), Vector3(0.08, 2.6, 4.0)], [Vector3(0.0, 1.3, 1.96), Vector3(1.55, 2.6, 0.08)],
			[Vector3(0.0, 1.3, -1.96), Vector3(1.55, 2.6, 0.08)], [Vector3(-0.4, 0.27, 0), Vector3(0.66, 0.54, 3.5)],
			[Vector3(0.0, 2.78, 0), Vector3(1.62, 0.3, 4.0)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		cs.position = s[0]
		stop_body.add_child(cs)
	Geo.prop(self, "bench", Vector3(-6, 0.15, 7.2), PI)
	Geo.prop(self, "trash_bin", Vector3(5.5, 0.15, 7.6), PI, "box", 0.7)
	# parked cars
	var car_spots := [Vector3(-22, 0, 3.4), Vector3(-34, 0, 3.4), Vector3(16, 0, -3.4), Vector3(48, 0, 3.4), Vector3(-70, 0, -3.4), Vector3(88, 0, 3.4)]
	for i in car_spots.size():
		CityLife.paint_car(Geo.prop(self, "car_sedan", car_spots[i], PI * 0.5 + (PI if i % 2 == 0 else 0.0)), CityLife.CAR_COLORS[(i * 4 + 1) % CityLife.CAR_COLORS.size()])
	# utility poles + street lamps
	for i in range(-8, 9):
		var x := i * 34.0 + 12.0
		var pole := Geo.prop(self, "utility_pole", Vector3(x, 0.15, -6.2), 0.0)
		if i == 1:
			siren_pole = pole
		if i % 2 == 0:
			Geo.prop(self, "street_lamp", Vector3(x + 17.0, 0.15, 6.4), PI)
	# trees in the grass strip between the sidewalk and the shop row (clear of the bus
	# stop, the zebra crossing and the side street)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in range(-10, 11):
		var tx := i * 21.0 + rng.randf_range(-4, 4)
		if absf(tx) < 5.0 or absf(tx - 6.0) < 4.0 or absf(tx + 6.0) < 5.0:
			continue
		Geo.prop(self, "tree_leafy", Vector3(tx, 0, 10.0 + rng.randf_range(0, 0.6)), rng.randf() * TAU, "box", rng.randf_range(0.75, 1.0))
	# apartment blocks behind the bus stop (model is 94 m long along Z)
	for x in [-58.0, 48.0]:
		Geo.prop(self, "apartment_block", Vector3(x, 0, 40), PI * 0.5)
	Geo.prop(self, "apartment_block", Vector3(-5.0, 0, 92), PI * 0.5)
	Geo.prop(self, "apartment_block", Vector3(130.0, 0, 75), 0.0)
	Geo.prop(self, "house_small", Vector3(-150, 0, 30), 0.3)
	Geo.prop(self, "house_small", Vector3(-175, 0, 18), -0.2)


## The Electromaș works north of the street (gate, avenue, halls, railway, the shelter
## square) — see FactorySite.
func _build_factory() -> void:
	factory = FactorySite.new()
	factory.name = "Electromas"
	add_child(factory)
	factory.build()


func _build_entrance() -> void:
	var cx := (SW_X0 + SW_X1) * 0.5
	# pavilion above the stairwell
	var pav_h := 3.1
	Geo.box(self, Vector3(0.4, pav_h, 7.0), Vector3(SW_X0 - 0.2, pav_h * 0.5, (SW_Z_TOP + SW_Z_HOLE) * 0.5), m_wall)
	Geo.box(self, Vector3(0.4, pav_h, 7.0), Vector3(SW_X1 + 0.2, pav_h * 0.5, (SW_Z_TOP + SW_Z_HOLE) * 0.5), m_wall)
	Geo.box(self, Vector3(5.2, 0.4, 7.4), Vector3(cx, pav_h + 0.2, (SW_Z_TOP + SW_Z_HOLE) * 0.5), m_wall)
	# back wall closes the pavilion above ground only (the stairs continue below it)
	Geo.box(self, Vector3(4.8, pav_h + 0.5, 0.4), Vector3(cx, (pav_h - 0.5) * 0.5, SW_Z_HOLE - 0.2), m_wall)
	# concrete fascia over the entrance carrying the signs (2.2 m clear below it)
	var fascia_z := (SW_Z_TOP + SW_Z_HOLE) * 0.5 + 3.7 - 0.15
	Geo.box(self, Vector3(5.2, 0.9, 0.3), Vector3(cx, pav_h - 0.45, fascia_z), m_wall)
	Geo.label3d(self, "OBIECTIVUL 17", Vector3(cx, pav_h - 0.22, fascia_z + 0.16), 0.0, 0.34, Color(0.95, 0.85, 0.3))
	Geo.label3d(self, "ADĂPOST DE PROTECȚIE CIVILĂ", Vector3(cx, pav_h - 0.66, fascia_z + 0.16), 0.0, 0.17)
	# red warning lamp on the roof edge
	var warn := Geo.emissive_mat(Color(1.0, 0.25, 0.1), 4.0)
	Geo.mesh_box(self, Vector3(0.3, 0.2, 0.3), Vector3(cx, pav_h + 0.5, fascia_z), warn)

	# stairs (visual steps + smooth ramp collider)
	var steps := 24
	var run := (SW_Z_TOP - SW_Z_BOTTOM) / steps
	var rise := -DEPTH / steps
	for i in steps:
		var top := -rise * (i + 1)
		var z := SW_Z_TOP - run * (i + 0.5)
		Geo.mesh_box(self, Vector3(SW_X1 - SW_X0, 0.3, run), Vector3(cx, top - 0.15 + rise, z), m_concrete)
	var length := Vector2(SW_Z_TOP - SW_Z_BOTTOM, -DEPTH).length()
	var ang := atan2(-DEPTH, SW_Z_TOP - SW_Z_BOTTOM)
	# the ramp's walking surface runs from ground level at the top to the corridor floor:
	# its 0.2 m slab sits just below that line (no lip to trip on at the top step)
	var ramp_n := Vector3(0, SW_Z_TOP - SW_Z_BOTTOM, DEPTH).normalized()
	var ramp_c := Vector3(cx, DEPTH * 0.5, (SW_Z_TOP + SW_Z_BOTTOM) * 0.5) - ramp_n * 0.1
	Geo.collider(self, Vector3(SW_X1 - SW_X0, 0.2, length), ramp_c, Vector3(-ang, 0, 0))
	# stairwell side walls below ground
	Geo.box(self, Vector3(0.4, 7.0, SW_Z_TOP - DOOR_Z), Vector3(SW_X0 - 0.2, DEPTH * 0.5 + 0.0, (SW_Z_TOP + DOOR_Z) * 0.5), m_wall)
	Geo.box(self, Vector3(0.4, 7.0, SW_Z_TOP - DOOR_Z), Vector3(SW_X1 + 0.2, DEPTH * 0.5 + 0.0, (SW_Z_TOP + DOOR_Z) * 0.5), m_wall)
	# tunnel ceiling (under the ground, after the pavilion)
	Geo.box(self, Vector3(4.8, 0.4, SW_Z_HOLE - DOOR_Z), Vector3(cx, -0.25, (SW_Z_HOLE + DOOR_Z) * 0.5), m_wall)
	# lower corridor floor
	Geo.box(self, Vector3(4.4, 0.4, SW_Z_BOTTOM - AIRLOCK_Z1 + 1.0), Vector3(cx, DEPTH - 0.2, (SW_Z_BOTTOM + AIRLOCK_Z1) * 0.5), m_concrete)
	# bulkhead = the vault door frame (3.97 m wide slab), wall filler above it
	Geo.box(self, Vector3(4.4, 3.0, 0.92), Vector3(cx, (DEPTH + 2.6 - 0.45) * 0.5, DOOR_Z), m_wall)
	# airlock room
	var al_w := 7.0
	var al_c := Vector3(cx, DEPTH, (DOOR_Z + AIRLOCK_Z1) * 0.5)
	Geo.box(self, Vector3(al_w, 0.4, 8.6), Vector3(cx, DEPTH - 0.2, al_c.z), m_concrete)
	Geo.box(self, Vector3(al_w, 0.4, 8.6), Vector3(cx, DEPTH + 3.6, al_c.z), m_wall)
	Geo.box(self, Vector3(0.4, 3.6, 8.6), Vector3(cx - al_w * 0.5, DEPTH + 1.8, al_c.z), m_wall)
	Geo.box(self, Vector3(0.4, 3.6, 8.6), Vector3(cx + al_w * 0.5, DEPTH + 1.8, al_c.z), m_wall)
	Geo.box(self, Vector3(al_w, 3.6, 0.4), Vector3(cx, DEPTH + 1.8, AIRLOCK_Z1 - 0.2), m_wall)
	# side pockets of the bulkhead inside the airlock
	Geo.box(self, Vector3(1.4, 3.6, 0.6), Vector3(cx - al_w * 0.5 + 0.7, DEPTH + 1.8, DOOR_Z), m_wall)
	Geo.box(self, Vector3(1.4, 3.6, 0.6), Vector3(cx + al_w * 0.5 - 0.7, DEPTH + 1.8, DOOR_Z), m_wall)
	Geo.prop(self, "metal_shelf", Vector3(cx + 2.7, DEPTH, -75.5), -PI * 0.5)
	Geo.prop(self, "military_crate", Vector3(cx - 2.6, DEPTH, -76.6), 0.2)
	Geo.prop(self, "fire_extinguisher", Vector3(cx - 3.1, DEPTH, -71.2), 0.0)
	Geo.label3d(self, "ECLUZA  ·  ÎNCHIDEȚI UȘA", Vector3(cx, DEPTH + 2.9, AIRLOCK_Z1 + 0.02), 0.0, 0.22, Color(0.95, 0.8, 0.3))

	# lights: corridor + airlock
	# hanging lamps (model is upright, 0.35 m tall, origin at the bottom)
	Geo.prop(self, "lamp_cage", Vector3(cx, -0.8, -65.0), 0.0, "none")
	Geo.omni(self, Vector3(cx, -1.0, -65.0), Color(1.0, 0.82, 0.6), 2.2, 11.0)
	Geo.prop(self, "lamp_cage", Vector3(cx + 1.5, DEPTH + 3.6 - 0.35, -76.0), 0.0, "none")
	var red := Geo.omni(self, Vector3(cx, DEPTH + 3.1, -74.0), Color(1.0, 0.15, 0.08), 2.2, 10.0)
	airlock_lights.append(red)
	var white := Geo.omni(self, Vector3(cx + 1.5, DEPTH + 3.0, -76.0), Color(1.0, 0.85, 0.65), 1.4, 8.0)
	airlock_lights.append(white)
	Geo.omni(self, Vector3(cx, 2.6, SW_Z_TOP - 2.5), Color(1.0, 0.82, 0.6), 1.0, 8.0, false)

	# The blast door. Model space: outside/corridor is -Z, so turn it 180° to face
	# the stairs (+Z here). The slab (model z 0.83..1.75) is centred on DOOR_Z.
	# Blast doors open outward, toward the threat, so overpressure seals them.
	var vd := Assets.vault_door(false)
	var droot: Node3D = vd.root
	add_child(droot)
	droot.rotation.y = PI
	droot.position = Vector3(cx, DEPTH, DOOR_Z + 1.29)
	door_pivot = vd.pivot

	Geo.interact_zone(self, Vector3(2.6, 2.6, 0.3), Vector3(cx, DEPTH + 1.3, DOOR_Z - 0.65), _door_prompt, _close_door, 2.0)


func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 14:
		var p := Vector3(rng.randf_range(-2400, -700), 0, rng.randf_range(-1400, 600))
		if absf(p.z) < 40.0:
			p.z += 120.0
		var b := Geo.prop(self, "apartment_block", p, rng.randf() * TAU, "none", rng.randf_range(1.0, 1.6))
		Assets.set_shadows(b, false)
	for i in 10:
		var p := Vector3(rng.randf_range(250, 900), 0, rng.randf_range(-900, -250))
		var b := Geo.prop(self, "apartment_block", p, rng.randf() * TAU, "none", rng.randf_range(0.9, 1.3))
		Assets.set_shadows(b, false)


# --------------------------------------------------------------------------
# Timeline
# --------------------------------------------------------------------------

func _once(key: String) -> bool:
	if _events.has(key):
		return false
	_events[key] = true
	return true


func _process(delta: float) -> void:
	if dead:
		return
	t += delta
	_update_surface()
	var stairs := Vector3((SW_X0 + SW_X1) * 0.5, 0, SW_Z_TOP + 1.0)
	var door_target := Vector3((SW_X0 + SW_X1) * 0.5, DEPTH + 1.4, DOOR_Z - 2.0)

	if t > 2.0 and _once("thought"):
		HUD.subtitle("Alex", "Iar întârzie autobuzul... Mai bine mergeam pe jos până la uzină.", 4.5)
	if t > 6.5 and _once("alert"):
		city.alert()
		Audio.sfx("ui_click", 2.0, 0.0)
		HUD.alert("ALERTĂ NAȚIONALĂ", "ATAC NUCLEAR IMINENT ÎN ZONA VADUL NOU. ADĂPOSTIȚI-VĂ IMEDIAT ÎN CEL MAI APROPIAT ADĂPOST. ACESTA NU ESTE UN EXERCIȚIU.", 7.0)
		player.add_shake(0.05)
	if t > 8.0 and _once("siren"):
		city.panic()
		if siren_pole:
			Audio.loop_at("siren_air_raid", siren_pole, 8.0, 900.0)
		Audio.ambient("siren", "siren_air_raid", -12.0, 3.0)
		Audio.ambient("bg", "ambient_morning", -20.0, 6.0)
	if t > 10.0 and _once("go"):
		HUD.subtitle("Alex", "Nu... nu se poate. Obiectivul 17! Adăpostul de sub uzină — codurile sunt la mine. Fugi!", 6.0)

	if not door_closed:
		var inside := player.global_position.z < SW_Z_TOP - 1.0 and player.global_position.y < -0.5
		HUD.waypoint = door_target if inside else stairs
		if not flashed:
			if t > 10.0:
				var left := maxf(FLASH_AT - t, 0.0)
				HUD.objective("Ajunge la Obiectivul 17  ·  impact estimat în %d s" % ceili(left) if not inside else "Închide ușa blindată din interiorul ecluzei!")
		else:
			var left := maxf(_shock_eta(), 0.0)
			HUD.objective("UNDA DE ȘOC SOSEȘTE ÎN %d s — ÎNCHIDE UȘA!" % ceili(left))
	else:
		HUD.waypoint = null
		HUD.objective("")

	if t >= FLASH_AT and not flashed:
		_flash()
	if flashed and not _seismic_done and t > FLASH_AT + 2.0:
		_seismic_done = true
		player.add_shake(0.35)
		Audio.sfx("explosion_nuclear", -18.0, 0.0)
	if flashed and not shock_arrived and nuke.shock_radius >= _player_blast_dist():
		_shock_hits()
	if _impact_at > 0.0 and t >= _impact_at and not impact_done:
		_impact_inside()


func _update_surface() -> void:
	var p := player.global_position
	var on_hard := absf(p.z) < 8.2 or (p.z < -9.0 and p.z > -150.0 and p.x > -130.0 and p.x < 230.0) or p.y < -0.5
	player.footstep_surface = "concrete" if on_hard else "grass"


func _player_blast_dist() -> float:
	var p := player.global_position
	return Vector2(p.x - BLAST_POS.x, p.z - BLAST_POS.z).length()


func _shock_eta() -> float:
	return (_player_blast_dist() - nuke.shock_radius) / nuke.shock_speed


func _flash() -> void:
	flashed = true
	nuke.detonate()
	city.emp()
	HUD.flash(1.0)
	player.add_shake(0.15)
	Audio.ambient("bg", "", 0.0, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "light_energy", 3.5, 0.1)
	tw.chain().tween_property(sun, "light_energy", 0.9, 6.0)
	tw.tween_property(sun, "light_color", Color(1.0, 0.62, 0.38), 8.0)
	tw.tween_property(env, "fog_light_color", Color(0.85, 0.55, 0.35), 10.0)
	tw.tween_property(env, "fog_density", 0.0012, 14.0)
	tw.tween_property(env, "fog_sky_affect", 0.8, 8.0)
	tw.tween_property(env, "adjustment_saturation", 1.15, 8.0)
	if env.sky and env.sky.sky_material:
		tw.tween_property(env.sky.sky_material, "energy_multiplier", 0.4, 7.0)
	_spawn_ash()
	if door_closed:
		_impact_at = maxf(_impact_at, t + 1.0)
	HUD.subtitle("Alex", "Doamne...", 3.0)


func _shock_hits() -> void:
	shock_arrived = true
	Audio.sfx("explosion_nuclear", 4.0 if not door_closed else -6.0, 0.0)
	Audio.sfx("shockwave_wind", 2.0 if not door_closed else -10.0, 0.0)
	if door_closed or door_closing:
		_impact_at = t
		return
	dead = true
	player.add_shake(3.0)
	player.can_move = false
	HUD.flash(0.7)
	HUD.set_post("tint", Vector3(0.8, 0.6, 0.45))
	var tw := create_tween()
	tw.tween_property(player, "rotation:z", 1.2, 0.8)
	await get_tree().create_timer(1.6).timeout
	HUD.set_post("tint", Vector3(1, 1, 1))
	State.damage(1000.0, "shockwave")


func _door_prompt() -> String:
	if door_closed or door_closing:
		return ""
	if player.global_position.z > DOOR_Z - 0.75:
		return "Ușa blindată — Intră în ecluză ca s-o închizi"
	return "Ușa blindată — Închide"


func _close_door() -> void:
	if door_closed or door_closing:
		return
	if player.global_position.z > DOOR_Z - 0.75:
		HUD.toast("Intră mai întâi în ecluză!", "warn")
		return
	door_closing = true
	Audio.sfx("door_vault_close", 2.0, 0.0)
	if door_pivot:
		var tw := create_tween()
		tw.tween_property(door_pivot, "rotation:y", Assets.DOOR_CLOSED_YAW, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	else:
		await get_tree().create_timer(3.0).timeout
	door_closed = true
	door_closing = false
	player.add_shake(0.6)
	Audio.sfx("metal_impact", 0.0, 0.0)
	HUD.objective("")
	if shock_arrived:
		_impact_at = t + 0.5
	elif flashed:
		_impact_at = t + maxf(_shock_eta(), 0.5)
	else:
		_impact_at = t + 4.0
	HUD.subtitle("Alex", "Închisă... Am închis-o.", 3.0)


func _impact_inside() -> void:
	impact_done = true
	if not shock_arrived:
		Audio.sfx("explosion_nuclear", -2.0, 0.0)
	player.add_shake(2.2)
	for l in airlock_lights:
		_flicker(l)
	_ceiling_dust()
	await get_tree().create_timer(3.5).timeout
	HUD.subtitle("Alex", "...Sunt viu. Afară nu mai e nimic. Doar eu și Obiectivul 17.", 5.0)
	await get_tree().create_timer(5.5).timeout
	await HUD.fade_to(1.0, 2.0)
	Audio.stop_all_ambient(2.0)
	HUD.banner("Ziua 1", "14 octombrie 2031. Lumea de deasupra nu mai există.", 4.0)
	await get_tree().create_timer(6.0).timeout
	Game.intro_complete()


func _flicker(l: Light3D) -> void:
	var base := l.light_energy
	var tw := create_tween()
	for i in 14:
		tw.tween_property(l, "light_energy", base * randf_range(0.0, 0.3), randf_range(0.03, 0.12))
		tw.tween_property(l, "light_energy", base * randf_range(0.6, 1.2), randf_range(0.03, 0.15))
	tw.tween_property(l, "light_energy", base * 0.6, 0.3)


func _ceiling_dust() -> void:
	var cx := (SW_X0 + SW_X1) * 0.5
	var p := GPUParticles3D.new()
	p.amount = 400
	p.lifetime = 2.5
	p.one_shot = true
	p.explosiveness = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.0, 0.05, 4.0)
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 2.0
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.66, 0.6)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	p.draw_pass_1 = qm
	add_child(p)
	p.position = Vector3(cx, DEPTH + 3.3, -74.0)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _spawn_ash() -> void:
	ash = GPUParticles3D.new()
	ash.amount = 900
	ash.lifetime = 8.0
	ash.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25, 1, 25)
	pm.gravity = Vector3(1.2, -0.8, 0.4)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	ash.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.72, 0.68)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	ash.draw_pass_1 = qm
	ash.local_coords = false
	player.add_child(ash)
	ash.position = Vector3(0, 12, 0)
