class_name CityLife
extends Node3D
## The town around the bus stop on the morning of Day Zero (Act I).
##
## Static: the shop row behind the stop (pharmacy, bakery, florist...), kiosks, the
## parking lot in front of the panel blocks, the side street, trolleybus wires, the zebra
## crossing with its traffic lights, billboards. Life: cars in both lanes that keep their
## distance, stop at the red light and for people on the road; townspeople waiting at the
## stop, walking to work at Electromaș, crossing at the zebra; pigeons over the square.
## The intro timeline drives it: alert() when the phones buzz, panic() at the siren,
## emp() at the flash (engines, traffic lights and street lights die).

const S := 0.15  # sidewalk top
const STOP_EAST := 3.6
const STOP_WEST := 8.4
const ZEBRA_X := 6.0
## [x centre, frontage, sign, sign colour]
const SHOPS := [
	[-52.0, 12.0, "ALIMENTARA", Color(0.95, 0.85, 0.5)], [-38.5, 10.0, "FARMACIE", Color(0.4, 0.9, 0.45)],
	[-26.0, 9.0, "FLORI", Color(0.95, 0.55, 0.7)], [11.5, 11.0, "PÂINE · COFETĂRIE", Color(0.95, 0.75, 0.45)],
	[25.5, 10.0, "TELEFOANE", Color(0.5, 0.75, 0.95)], [39.0, 11.0, "FRIZERIE", Color(0.92, 0.92, 0.88)],
	[53.0, 10.0, "CAFENEA", Color(0.95, 0.65, 0.35)],
]
const SHOP_FRONT := 13.5
const SHOP_DEPTH := 8.0
## doors of the panel blocks (where people run at the siren)
const BLOCK_DOORS := [-95.0, -80.0, -65.0, -50.0, -35.0, -20.0, 10.0, 25.0, 40.0, 55.0, 70.0, 85.0]
const BLOCK_FRONT := 31.0
## light cycle for the cars: [state, seconds]
const CYCLE := [["red", 7.0], ["green", 11.0], ["yellow", 2.0]]

## Soviet-era paint: white, beige, sky blue, navy, green, grey, cherry, yellow, brown
const CAR_COLORS := [Color(0.86, 0.86, 0.83), Color(0.82, 0.75, 0.58), Color(0.45, 0.62, 0.78), Color(0.14, 0.2, 0.38),
	Color(0.25, 0.42, 0.3), Color(0.5, 0.5, 0.48), Color(0.5, 0.06, 0.08), Color(0.9, 0.74, 0.2), Color(0.32, 0.2, 0.14)]
const SHIRTS := [Color(0.92, 0.92, 0.9), Color(0.55, 0.56, 0.58), Color(0.82, 0.74, 0.6), Color(0.22, 0.35, 0.25), Color(0.5, 0.14, 0.14),
	Color(0.16, 0.2, 0.36), Color(0.12, 0.12, 0.13), Color(0.85, 0.7, 0.25), Color(0.85, 0.45, 0.15), Color(0.6, 0.8, 0.9), Color(0.75, 0.5, 0.6)]
const TROUSERS := [Color(0.12, 0.18, 0.3), Color(0.08, 0.08, 0.09), Color(0.35, 0.35, 0.37), Color(0.3, 0.22, 0.15), Color(0.42, 0.4, 0.3)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.25, 0.15, 0.08), Color(0.45, 0.32, 0.18), Color(0.55, 0.55, 0.55), Color(0.7, 0.58, 0.35)]
static var _npc_mat: ShaderMaterial
static var _car_mat: ShaderMaterial

var cars: Array[TrafficCar] = []
var people: Array[Pedestrian] = []
## doors inside the works the workers run to (set by FactorySite)
var yard_shelters: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _phase := 0
## the first red lasts long enough for the people at the zebra to cross
var _light_t := 13.0
var _powered := true
var _lamp_mats := {}  # car_red, car_yellow, car_green, ped_red, ped_green
var _birds: MultiMeshInstance3D
var _bird := []  # [angle, radius, height, speed, flap phase]
var _scatter := -1.0
var _t := 0.0
var _b := BoxBatch.new()
var _m := {}


func build() -> void:
	rng.seed = 2031
	_b.cell = 40.0  # the street is 560 m long: split so the part behind the camera is culled
	_materials()
	_shop_row()
	_parking()
	_wires()
	_zebra()
	_signals()
	_billboards()
	_b.commit(self)
	_spawn_cars()
	_spawn_people()
	_spawn_birds()
	_apply_lights()
	Audio.ambient("city", "city_traffic", -12.0, 3.0)


func _materials() -> void:
	_m = {
		"white": Geo.color_mat(Color(0.9, 0.9, 0.86), 0.7),
		"yellow": Geo.color_mat(Color(0.95, 0.78, 0.2), 0.7),
		"dark": Geo.color_mat(Color(0.06, 0.06, 0.06), 0.5, 0.3),
		"steel": Geo.color_mat(Color(0.32, 0.33, 0.32), 0.45, 0.8),
		"wire": Geo.color_mat(Color(0.05, 0.05, 0.05), 0.6, 0.5),
		"pave": Assets.pbr("pavement", {"tile": 2.0, "fallback": Color(0.55, 0.54, 0.5)}),
		"asphalt": Assets.pbr("asphalt", {"tile": 5.0, "fallback": Color(0.16, 0.16, 0.17)}),
	}
	for k in ["car_red", "car_yellow", "car_green", "ped_red", "ped_green"]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.08, 0.08)
		m.emission_enabled = true
		m.emission = {"car_red": Color(1.0, 0.12, 0.06), "car_yellow": Color(1.0, 0.65, 0.1), "car_green": Color(0.2, 1.0, 0.45),
			"ped_red": Color(1.0, 0.12, 0.06), "ped_green": Color(0.2, 1.0, 0.45)}[k]
		_lamp_mats[k] = m


func _shop_mats(i: int) -> Dictionary:
	var plaster: Color = [Color(0.95, 0.9, 0.78), Color(0.82, 0.88, 0.95), Color(0.9, 0.8, 0.72), Color(0.85, 0.92, 0.82)][i % 4]
	return {
		"ext": Assets.pbr(["plaster_white", "plaster_yellow", "plaster_blue", "plaster_white"][i % 4], {"tile": 2.6, "tint": plaster.lerp(Color.WHITE, 0.6)}),
		"int": Assets.pbr("plaster_int", {"tile": 2.0, "tint": Color(0.9, 0.88, 0.82)}),
		"trim": Geo.color_mat([Color(0.85, 0.85, 0.82), Color(0.22, 0.38, 0.62), Color(0.5, 0.15, 0.12)][i % 3], 0.5),
		"roof": Assets.pbr("asphalt", {"tile": 3.0, "tint": Color(0.6, 0.6, 0.6)}),
		"plinth": Assets.pbr("concrete_floor", {"tile": 2.0, "tint": Color(0.62, 0.62, 0.6)}),
		"floor_wood": Assets.pbr("wood_planks", {"tile": 1.6}), "floor_tile": Assets.pbr("tiles_wall", {"tile": 1.2}),
		"floor_concrete": Assets.pbr("concrete_floor", {"tile": 2.5}),
		"wood": Assets.pbr("wood_planks", {"tile": 0.8}), "wood_dark": Assets.pbr("wood_planks", {"tile": 0.8, "tint": Color(0.48, 0.34, 0.24)}),
		"metal": Assets.pbr("painted_metal", {"tile": 0.8}), "white": _m.white, "dark": _m.dark,
		"fabric_a": _m.white, "fabric_b": _m.dark, "chimney": Assets.pbr("brick_wall", {"tile": 1.0}),
		"glass": _glass(),
		"locker": _m.steel, "olive": _m.dark, "red": _m.dark,
	}


## Shop windows: dark, glossy, catching the sky.
func _glass() -> Material:
	if not _m.has("glass"):
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.1, 0.13, 0.15)
		g.metallic = 0.6
		g.roughness = 0.06
		_m["glass"] = g
	return _m.glass


## Gives a townsperson their own clothes, hair and skin tone (one shared material,
## per-instance colours).
static func dress(model: Node3D) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if _npc_mat == null:
			var src := mi.get_active_material(0) as StandardMaterial3D
			if src == null:
				return
			_npc_mat = ShaderMaterial.new()
			_npc_mat.shader = load("res://shaders/recolor_npc.gdshader")
			_npc_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
		mi.material_override = _npc_mat
		mi.set_instance_shader_parameter("shirt", SHIRTS.pick_random())
		mi.set_instance_shader_parameter("trousers", TROUSERS.pick_random())
		mi.set_instance_shader_parameter("hair", HAIR.pick_random())
		mi.set_instance_shader_parameter("skin", randf_range(0.8, 1.08))


## Day Zero cars are clean (the rusty car_sedan is for the wasteland): a GAZ-24 Volga or a
## VAZ-2107, body repainted in a period colour. yaw turns the model's front to +Z.
const CLEAN_CARS := {"car_volga": {"yaw": 0.0, "paint": "paint"}, "car_lada": {"yaw": -PI * 0.5, "paint": "Body"}}
static var _paint_cache := {}


static func clean_car(color: Color) -> Node3D:
	var ids: Array = []
	for k in CLEAN_CARS:
		if Assets.has_model(k):
			ids.append(k)
	if ids.is_empty():
		var old := Assets.model("car_sedan")
		paint_car(old, color)
		return old
	var id: String = ids.pick_random()
	var holder := Node3D.new()
	holder.name = "Car"
	var m := Assets.model(id)
	holder.add_child(m)
	m.rotation.y = float(CLEAN_CARS[id].yaw)
	var paint_name: String = CLEAN_CARS[id].paint
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if mat == null or mat.resource_name != paint_name:
				continue
			var key := "%s_%s" % [id, color.to_html()]
			if not _paint_cache.has(key):
				var d := mat.duplicate() as StandardMaterial3D
				d.albedo_color = color
				d.metallic = 0.35
				d.roughness = 0.32
				d.clearcoat_enabled = true
				d.clearcoat = 0.6
				d.clearcoat_roughness = 0.15
				_paint_cache[key] = d
			mi.set_surface_override_material(si, _paint_cache[key])
	return holder


## A parked clean car with a collision box (pos = ground point, yaw = heading).
static func parked_car(parent: Node, pos: Vector3, yaw: float, color: Color) -> Node3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	body.rotation.y = yaw
	body.add_child(clean_car(color))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 1.45, 4.5)
	cs.shape = bs
	cs.position.y = 0.72
	body.add_child(cs)
	return body


## Repaints the body of a car_sedan model.
static func paint_car(model: Node3D, color: Color) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not String(mi.name).contains("CarBody"):
			continue
		if _car_mat == null:
			var src := mi.get_active_material(0) as StandardMaterial3D
			if src == null:
				return
			_car_mat = ShaderMaterial.new()
			_car_mat.shader = load("res://shaders/car_paint.gdshader")
			_car_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			if src.normal_enabled and src.normal_texture:
				_car_mat.set_shader_parameter("normal_tex", src.normal_texture)
				_car_mat.set_shader_parameter("has_normal", true)
		mi.material_override = _car_mat
		mi.set_instance_shader_parameter("paint", color)


# --------------------------------------------------------------------------
# Static town
# --------------------------------------------------------------------------

## A row of one-storey shops behind the bus stop, a paved forecourt and two kiosks.
func _shop_row() -> void:
	for i in SHOPS.size():
		var s: Array = SHOPS[i]
		var b := Building.new()
		b.kind = "shop"
		b.size = Vector2(s[1], SHOP_DEPTH)
		b.height = 3.4
		b.roof = "flat"
		b.intact = true
		b.furnish = false
		b.sign_text = s[2]
		b.sign_color = s[3]
		b.rng = RandomNumberGenerator.new()
		b.rng.seed = 900 + i
		b.mats = _shop_mats(i)
		add_child(b)
		b.position = Vector3(s[0], 0.0, SHOP_FRONT + SHOP_DEPTH * 0.5)
		b.rotation.y = PI
		b.build()
		# awning over the shop window
		_b.box(b.mats.trim, Vector3(s[0], 2.75, SHOP_FRONT - 0.55), Vector3(float(s[1]) - 0.6, 0.06, 1.1))
	# forecourt in front of the shops (the trees stand in the grass strip before it)
	Geo.plane(self, Vector2(124.0, 2.6), Vector3(0.5, 0.02, SHOP_FRONT - 1.3), _m.pave)
	for k in [[-13.5, PI], [64.0, PI]]:
		Geo.prop(self, "shop_ruin", Vector3(k[0], 0.0, 16.0), k[1])
	# benches and bins along the forecourt
	for x in [-45.0, -31.0, 18.0, 32.0, 46.0]:
		Geo.prop(self, "bench", Vector3(x, 0.02, SHOP_FRONT - 2.2), PI)
	for x in [-20.0, 60.0]:
		Geo.prop(self, "trash_bin", Vector3(x, 0.02, SHOP_FRONT - 1.0), PI, "box", 0.7)


## Service road + parking in front of the panel blocks, and the side street to it.
func _parking() -> void:
	Geo.plane(self, Vector2(200.0, 7.0), Vector3(-5.0, 0.03, 26.0), _m.asphalt)
	Geo.plane(self, Vector2(6.0, 15.0), Vector3(-6.0, 0.03, 15.5), _m.asphalt)
	# painted bays
	var x := -60.0
	while x < 60.0:
		if absf(x + 6.0) > 4.0:
			_b.box(_m.white, Vector3(x, 0.045, 28.3), Vector3(0.1, 0.01, 2.6))
		x += 2.7
	var spots: Array = []
	x = -58.65
	while x < 58.0:
		var near_door := false
		for dx in BLOCK_DOORS:
			if absf(x - dx) < 2.4:
				near_door = true
		if absf(x + 6.0) > 4.5 and not near_door:
			spots.append(x)
		x += 2.7
	for k in 7:
		var i := rng.randi() % spots.size()
		var sx: float = spots[i]
		spots.remove_at(i)
		parked_car(self, Vector3(sx, 0.0, 28.0), (0.0 if rng.randf() < 0.5 else PI) + rng.randf_range(-0.05, 0.05), CAR_COLORS.pick_random())
	for x2 in [-70.0, -10.0, 66.0]:
		Geo.prop(self, "trash_bin", Vector3(x2, 0.03, 23.3), 0.0)


## Trolleybus overhead line: steel poles on the south side, span wires to the poles on
## the factory side, two contact wires over each lane.
func _wires() -> void:
	for i in range(-8, 9):
		var px := i * 34.0 + 12.0
		_b.box(_m.steel, Vector3(px, 3.9, 6.7), Vector3(0.18, 7.8, 0.18))
		_b.box(_m.wire, Vector3(px, 6.9, 0.25), Vector3(0.02, 0.02, 12.9))
		for z in [-1.55, -1.05, 1.05, 1.55]:
			_b.box(_m.wire, Vector3(px, 6.45, z), Vector3(0.015, 0.9, 0.015))
	for z in [-1.55, -1.05, 1.05, 1.55]:
		_b.box(_m.wire, Vector3(0.0, 6.0, z), Vector3(560.0, 0.018, 0.018))


func _zebra() -> void:
	for k in 9:
		_b.box(_m.white, Vector3(ZEBRA_X, 0.06, -4.0 + k * 1.0), Vector3(3.0, 0.01, 0.5))
	_b.box(_m.white, Vector3(STOP_EAST - 0.2, 0.06, 2.5), Vector3(0.3, 0.01, 4.8))
	_b.box(_m.white, Vector3(STOP_WEST + 0.2, 0.06, -2.5), Vector3(0.3, 0.01, 4.8))


## Traffic lights for both directions with pedestrian heads facing the crossing.
func _signals() -> void:
	for sgn in [1.0, -1.0]:
		var base := Vector3(STOP_EAST - 0.3 if sgn > 0.0 else STOP_WEST + 0.3, S, 5.6 * sgn)
		_b.box(_m.steel, base + Vector3(0, 1.75, 0), Vector3(0.12, 3.5, 0.12), 0.0, true)
		# car head faces oncoming traffic (eastbound comes from -X)
		var face: float = -sgn
		var head := base + Vector3(face * 0.18, 3.25, 0)
		_b.box(_m.dark, head, Vector3(0.22, 0.95, 0.32))
		for k in 3:
			var key: String = ["car_red", "car_yellow", "car_green"][k]
			_b.box(_lamp_mats[key], head + Vector3(face * 0.12, 0.3 - k * 0.3, 0), Vector3(0.03, 0.2, 0.2))
		# pedestrian head faces across the street
		var ph := base + Vector3(0, 2.35, -sgn * 0.17)
		_b.box(_m.dark, ph, Vector3(0.28, 0.55, 0.2))
		_b.box(_lamp_mats.ped_red, ph + Vector3(0, 0.13, -sgn * 0.11), Vector3(0.2, 0.2, 0.03))
		_b.box(_lamp_mats.ped_green, ph + Vector3(0, -0.13, -sgn * 0.11), Vector3(0.2, 0.2, 0.03))


func _billboards() -> void:
	for spec in [[Vector3(-34.0, 0, 23.0), "VADUL NOU  ·  ORAȘUL TĂU", Color(0.2, 0.42, 0.7)], [Vector3(30.0, 0, 23.0), "ELECTROMAȘ  ·  75 DE ANI", Color(0.62, 0.18, 0.12)]]:
		var p: Vector3 = spec[0]
		for s in [-1.0, 1.0]:
			_b.box(_m.steel, p + Vector3(s * 2.4, 3.4, 0), Vector3(0.2, 6.8, 0.2))
		var board := Geo.color_mat(spec[2], 0.8)
		_b.box(board, p + Vector3(0, 6.3, 0), Vector3(7.0, 3.0, 0.18))
		_b.box(_m.white, p + Vector3(0, 6.3, 0.02), Vector3(7.3, 3.3, 0.12))
		var l := Label3D.new()
		l.text = spec[1]
		l.font = Assets.font("heading")
		l.font_size = 96
		l.pixel_size = 0.0075
		l.modulate = Color(0.97, 0.95, 0.88)
		l.outline_size = 0
		add_child(l)
		l.position = p + Vector3(0, 6.3, -0.11)
		l.rotation.y = PI


# --------------------------------------------------------------------------
# Life
# --------------------------------------------------------------------------

func _spawn_cars() -> void:
	# a queue at the red light on both sides, others further away
	for x in [STOP_EAST - 2.4, STOP_EAST - 9.0, -62.0, -118.0, -160.0]:
		_car(1.0, x, x > -20.0)
	for x in [STOP_WEST + 2.4, STOP_WEST + 9.0, 75.0, 125.0, 170.0]:
		_car(-1.0, x, x < 20.0)


func _car(d: float, x: float, waiting: bool) -> void:
	var c := TrafficCar.new().setup(d, x, self)
	add_child(c)
	if waiting:
		c.speed = 0.0
	cars.append(c)


func _person(route: Array[Vector3], spd: float, kind := "walk") -> Pedestrian:
	var p := Pedestrian.new()
	p.idler = kind == "idle"
	p.crosser = kind == "cross"
	p.loop = kind == "loop"
	p.setup(route, spd, self)
	add_child(p)
	people.append(p)
	return p


func _spawn_people() -> void:
	# waiting for the bus next to Alex
	var w1 := _person([Vector3(-2.75, S, 6.1)], 1.0, "idle")
	w1.rotation.y = PI
	var w2 := _person([Vector3(2.45, S, 5.7)], 1.0, "idle")
	w2.rotation.y = PI * 0.85
	# along the south sidewalk (in front of the shelter: z 5.6)
	for k in 5:
		var a := rng.randf_range(-110.0, -15.0) if k % 2 == 0 else rng.randf_range(15.0, 110.0)
		var b := rng.randf_range(-40.0, 40.0)
		var z: float = 5.6 if (minf(a, b) < 3.0 and maxf(a, b) > -3.0) else [5.6, 7.3][k % 2]
		_person([Vector3(a, S, z), Vector3(b, S, z)], rng.randf_range(1.1, 1.5))
	# the morning shift walking to the factory gate
	for k in 4:
		var x0 := rng.randf_range(-90.0, -10.0) if k < 2 else rng.randf_range(60.0, 120.0)
		_person([Vector3(x0, S, -6.6), Vector3(35.0 + k * 0.8, S, -6.6), Vector3(35.0 + k * 0.8, 0.0, -10.5), Vector3(33.0 + k * 1.5, 0.0, -22.0)], rng.randf_range(1.2, 1.5))
	# waiting at the zebra for the green man
	for k in 2:
		_person([Vector3(ZEBRA_X - 0.6 + k * 1.1, S, 6.3 + k * 0.3), Vector3(ZEBRA_X - 0.4 + k * 0.9, 0.05, 0.0), Vector3(ZEBRA_X + k * 0.9, S, -6.4), Vector3(ZEBRA_X + 24.0, S, -6.6)], 1.3, "cross")
	# shop forecourt
	for k in 4:
		var a := rng.randf_range(-58.0, 60.0)
		var b := clampf(a + rng.randf_range(-25.0, 25.0), -58.0, 60.0)
		_person([Vector3(a, 0.02, SHOP_FRONT - 1.4), Vector3(b, 0.02, SHOP_FRONT - 1.4)], rng.randf_range(1.0, 1.4))
	# parking lot
	for k in 2:
		var a := rng.randf_range(-50.0, 50.0)
		_person([Vector3(a, 0.03, 25.0), Vector3(a + rng.randf_range(-15.0, 15.0), 0.03, 25.5)], rng.randf_range(1.0, 1.3))


## Pigeons circling over the shops; they scatter when the siren starts.
func _spawn_birds() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0, 0, 0.16), Vector3(-0.24, 0.02, -0.02), Vector3(0, 0.02, -0.08), Vector3(0, 0, 0.16), Vector3(0, 0.02, -0.08), Vector3(0.24, 0.02, -0.02),
			Vector3(0, -0.03, 0.18), Vector3(0, 0.03, -0.16), Vector3(0.03, 0, 0.0)]:
		st.add_vertex(v)
	st.generate_normals()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = 18
	_birds = MultiMeshInstance3D.new()
	_birds.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.26, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_birds.material_override = mat
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_birds)
	for i in 18:
		_bird.append([rng.randf() * TAU, rng.randf_range(7.0, 16.0), rng.randf_range(9.0, 15.0), rng.randf_range(0.35, 0.6) * (1.0 if i % 3 else -1.0), rng.randf() * TAU])


# --------------------------------------------------------------------------
# Queries for cars / people
# --------------------------------------------------------------------------

func light_red() -> bool:
	return _powered and CYCLE[_phase][0] != "green"


## The green man: cars have had red for a moment.
func walk_signal() -> bool:
	return _powered and CYCLE[_phase][0] == "red" and _light_t > 9.0


func distance_to_stop_line(c: TrafficCar) -> float:
	return (STOP_EAST - c.front()) if c.dir > 0.0 else (c.front() - STOP_WEST)


func gap_ahead(c: TrafficCar) -> float:
	var best := INF
	for o in cars:
		if o == c or not is_instance_valid(o) or o.dir != c.dir:
			continue
		var g := (o.back() - c.front()) * c.dir
		if g > -1.0 and g < best:
			best = g
	return best


## Distance from the bumper to the nearest person standing in this lane ahead.
func obstacle_ahead(c: TrafficCar) -> float:
	# called by every car every physics tick: no temporary arrays
	var best := INF
	var front := c.front()
	for n in people:
		best = _obstacle_dist(n, c, front, best)
	if Game.player and is_instance_valid(Game.player):
		best = _obstacle_dist(Game.player, c, front, best)
	return best


func _obstacle_dist(n: Node3D, c: TrafficCar, front: float, best: float) -> float:
	if not is_instance_valid(n) or not n.visible:
		return best
	var p := n.global_position
	if p.y > 0.6 or absf(p.z - c.lane_z) > 1.6:
		return best
	var d := (p.x - front) * c.dir
	if d > -0.5 and d < best:
		return maxf(d, 0.0)
	return best


# --------------------------------------------------------------------------
# Timeline
# --------------------------------------------------------------------------

func alert() -> void:
	for p in people:
		if is_instance_valid(p):
			p.alert()


func panic() -> void:
	for p in people:
		if is_instance_valid(p):
			p.panic(_escape(p.global_position))
	for c in cars:
		if is_instance_valid(c):
			c.panic()
	_scatter = 0.0
	Audio.ambient_volume("city", -24.0, 4.0)


## Gaps in the shop row people can run through (x).
const GAPS := [-60.5, -44.8, -32.0, -18.5, -6.0, 1.5, 18.8, 32.0, 46.3, 60.0, 68.0]


## Escape route from `pos`: factory side -> along the sidewalk, through the gate into the
## yard; town side -> through the nearest gap in the shop row to the nearest block door.
func _escape(pos: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	if pos.z < 0.0:
		var from := pos
		if pos.z > -9.5:
			# still outside the fence: along the sidewalk and through the gate
			var gx := 36.0 + rng.randf_range(-3.5, 3.5)
			path.append(Vector3(gx, S, -6.6))
			path.append(Vector3(gx, 0.04, -11.0))
			from = path.back()
		if yard_shelters.is_empty():
			path.append(Vector3(36.0, 0.04, -26.0))
			return path
		var best: Vector3 = yard_shelters[0]
		for d in yard_shelters:
			if from.distance_to(d) < from.distance_to(best):
				best = d
		if absf(best.x - from.x) > 6.0:
			# go round by the avenue / first cross road instead of through buildings
			path.append(Vector3(from.x if absf(from.x - 36.0) < 5.0 else 36.0, 0.07, -32.0) if from.z > -30.0 else Vector3(from.x, 0.07, -32.0))
			path.append(Vector3(best.x, 0.07, -32.0))
		path.append(best)
		return path
	var x := pos.x
	if pos.z < 22.5:
		var gap: float = GAPS[0]
		for g in GAPS:
			if absf(g - pos.x) < absf(gap - pos.x):
				gap = g
		if pos.z < SHOP_FRONT - 0.5:
			path.append(Vector3(gap, 0.02, SHOP_FRONT - 1.4))
		path.append(Vector3(gap, 0.02, 22.6))
		x = gap
	var door: float = BLOCK_DOORS[0]
	for d in BLOCK_DOORS:
		if absf(d - x) < absf(door - x):
			door = d
	path.append(Vector3(door, 0.03, 24.5))
	path.append(Vector3(door, 0.03, BLOCK_FRONT))
	return path


func emp() -> void:
	_powered = false
	_apply_lights()
	for c in cars:
		if is_instance_valid(c):
			c.emp()
	Audio.ambient("city", "", 0.0, 0.5)


func _apply_lights() -> void:
	var st: String = CYCLE[_phase][0]
	var on := {"car_red": st == "red", "car_yellow": st == "yellow", "car_green": st == "green",
		"ped_red": st != "red", "ped_green": st == "red"}
	for k in _lamp_mats:
		(_lamp_mats[k] as StandardMaterial3D).emission_energy_multiplier = (3.0 if on[k] else 0.0) if _powered else 0.0


func _process(delta: float) -> void:
	_t += delta
	if _powered:
		_light_t -= delta
		if _light_t <= 0.0:
			_phase = (_phase + 1) % CYCLE.size()
			_light_t = float(CYCLE[_phase][1])
			_apply_lights()
		# the green man blinks before it turns red
		if CYCLE[_phase][0] == "red" and _light_t < 2.0:
			(_lamp_mats.ped_green as StandardMaterial3D).emission_energy_multiplier = 3.0 if fmod(_t, 0.5) < 0.25 else 0.0
	_update_birds(delta)


func _update_birds(delta: float) -> void:
	if _birds == null or not _birds.visible:
		return
	if _scatter >= 0.0:
		_scatter += delta
		if _scatter > 8.0:
			_birds.visible = false
			return
	var center := Vector3(4.0, 0.0, 17.0)
	for i in _bird.size():
		var b: Array = _bird[i]
		b[0] += float(b[3]) * delta * (1.0 + maxf(_scatter, 0.0) * 1.5)
		b[4] += delta * (11.0 if _scatter >= 0.0 else 7.0)
		var r: float = b[1] + maxf(_scatter, 0.0) * 6.0
		var h: float = b[2] + maxf(_scatter, 0.0) * 4.0 + sin(_t * 0.7 + i) * 0.6
		var a: float = b[0]
		var pos := center + Vector3(cos(a) * r, h, sin(a) * r)
		var fwd := Vector3(-sin(a), 0.0, cos(a)) * signf(b[3])
		var basis := Basis.looking_at(-fwd, Vector3.UP) * Basis(Vector3.BACK, sin(b[4]) * 0.5)
		_birds.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 1.6), pos))
