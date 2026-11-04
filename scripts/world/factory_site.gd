class_name FactorySite
extends Node3D
## The Electromaș works on the morning of Day Zero (intro, north of the street).
##
## A Soviet plant laid out on a grid: the gate with checkpoint, raised barrier and the
## open sliding gate; the main avenue with lawns, trees and lamps; the administration
## block with rooftop letters, flags, flower beds and the board of honour; the canteen
## with its smokers' corner; the vehicle workshop with lorries; numbered production
## halls along two cross roads; warehouses with a loading dock; the boiler house under
## the chimney, steam pipes on supports (raised over the avenue), the transformer
## substation, the works railway with wagons, and the civil-defence shelter (Obiectivul 17)
## in its own small square, signposted from the gate. Workers smoke, load and walk to
## their halls; at the siren they run for the nearest door.

const FENCE_Z := -9.0
const AVENUE_X := 36.0
const ROAD_A := -32.0
const ROAD_B := -88.0
const ROAD_W := 8.0
const RAIL_Z := -97.0
const Y_YARD := 0.04
const Y_ROAD := 0.07
## [x, z, label] production halls (factory_hall model, long on Z, front = +Z)
const HALLS := [[-10.0, -62.0, "SECȚIA NR. 1"], [-38.0, -62.0, "SECȚIA NR. 2"], [-66.0, -62.0, "SECȚIA NR. 4"],
	[105.0, -62.0, "SECȚIA NR. 3"], [20.0, -125.0, "SECȚIA NR. 5"], [60.0, -128.0, "SECȚIA NR. 6"], [-25.0, -120.0, "TURNĂTORIA"]]

## doors the workers run to at the siren (filled while building)
var shelters: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var _b := BoxBatch.new()
var _m := {}


func build() -> void:
	rng.seed = 1956
	_b.cell = 40.0  # 360 × 150 m site: split so the part behind the camera is culled
	_materials()
	_fence_and_gate()
	_roads()
	_admin()
	_canteen()
	_garage()
	_halls()
	_warehouses()
	_boiler_house()
	_railway()
	_pipes()
	_substation()
	_shelter_square()
	_lamps_and_trees()
	_storage()
	_lawns()
	_b.commit(self)


func _materials() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.13, 0.15)
	glass.metallic = 0.6
	glass.roughness = 0.06
	_m = {
		"asphalt": Assets.pbr("asphalt", {"tile": 5.0, "fallback": Color(0.16, 0.16, 0.17)}),
		"pave": Assets.pbr("pavement", {"tile": 2.0, "fallback": Color(0.55, 0.54, 0.5)}),
		"grass": Assets.pbr("grass", {"tile": 3.0, "fallback": Color(0.28, 0.36, 0.2)}),
		"gravel": Assets.pbr("gravel", {"tile": 1.5, "fallback": Color(0.4, 0.38, 0.35)}),
		"conc": Assets.pbr("concrete_floor", {"tile": 2.0, "tint": Color(0.75, 0.74, 0.7)}),
		"wall": Assets.pbr("panel_concrete", {"tile": 3.0, "tint": Color(0.88, 0.87, 0.84)}),
		"brick": Assets.pbr("brick_wall", {"tile": 2.5, "tint": Color(0.8, 0.72, 0.68)}),
		"plaster": Assets.pbr("plaster_yellow", {"tile": 2.6, "tint": Color(1.0, 0.97, 0.9)}),
		"wood": Assets.pbr("wood_planks", {"tile": 0.8}),
		"wood_dark": Assets.pbr("wood_planks", {"tile": 0.8, "tint": Color(0.45, 0.33, 0.24)}),
		"steel": Geo.color_mat(Color(0.32, 0.33, 0.32), 0.45, 0.8),
		"green": Assets.pbr("painted_metal", {"tile": 1.0}),
		"insul": Geo.color_mat(Color(0.72, 0.73, 0.72), 0.35, 0.75),
		"white": Geo.color_mat(Color(0.9, 0.9, 0.86), 0.7),
		"yellow": Geo.color_mat(Color(0.95, 0.76, 0.15), 0.6),
		"red": Geo.color_mat(Color(0.72, 0.1, 0.08), 0.6),
		"blue": Geo.color_mat(Color(0.1, 0.28, 0.62), 0.6),
		"black": Geo.color_mat(Color(0.05, 0.05, 0.05), 0.5, 0.3),
		"dark": Geo.color_mat(Color(0.12, 0.12, 0.12), 0.7),
		"rubber": Geo.color_mat(Color(0.04, 0.04, 0.04), 0.9),
		"cab": Geo.color_mat(Color(0.85, 0.42, 0.1), 0.45, 0.2),
		"cab2": Geo.color_mat(Color(0.2, 0.36, 0.58), 0.45, 0.2),
		"olive": Geo.color_mat(Color(0.3, 0.34, 0.22), 0.7),
		"wagon": Geo.color_mat(Color(0.42, 0.2, 0.14), 0.8, 0.2),
		"card": Geo.color_mat(Color(0.62, 0.5, 0.34), 0.9),
		"flower_r": Geo.color_mat(Color(0.8, 0.12, 0.15), 0.8),
		"flower_y": Geo.color_mat(Color(0.95, 0.8, 0.2), 0.8),
		"glass": glass,
	}


## Material set for the Building generator.
func _bmats(ext: Material, trim: Color) -> Dictionary:
	return {
		"ext": ext, "int": Assets.pbr("plaster_int", {"tile": 2.0, "tint": Color(0.88, 0.86, 0.8)}),
		"trim": Geo.color_mat(trim, 0.5), "roof": Assets.pbr("asphalt", {"tile": 3.0, "tint": Color(0.55, 0.55, 0.55)}),
		"plinth": _m.conc, "floor_wood": _m.wood, "floor_tile": _m.conc, "floor_concrete": _m.conc,
		"wood": _m.wood, "wood_dark": _m.wood_dark, "metal": _m.green, "white": _m.white, "dark": _m.dark,
		"fabric_a": _m.white, "fabric_b": _m.dark, "chimney": _m.brick, "glass": _m.glass,
		"locker": _m.steel, "olive": _m.olive, "red": _m.red,
	}


func _building(kind: String, pos: Vector3, yaw: float, size: Vector2, height: float, floors: int, ext: Material, trim: Color, sign := "", sign_color := Color(0.95, 0.92, 0.85)) -> Building:
	var b := Building.new()
	b.kind = kind
	b.size = size
	b.height = height
	b.floors = floors
	b.roof = "flat"
	b.intact = true
	b.furnish = false
	b.sign_text = sign
	b.sign_color = sign_color
	b.rng = RandomNumberGenerator.new()
	b.rng.seed = rng.randi()
	b.mats = _bmats(ext, trim)
	add_child(b)
	b.position = pos
	b.rotation.y = yaw
	b.build()
	return b


func _label(text: String, pos: Vector3, yaw: float, px: float, color: Color, outline := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Assets.font("heading")
	l.font_size = 96
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 10 if outline else 0
	l.outline_modulate = Color(0, 0, 0, 0.6)
	add_child(l)
	l.position = pos
	l.rotation.y = yaw
	return l


# --------------------------------------------------------------------------
# Gate
# --------------------------------------------------------------------------

func _fence_and_gate() -> void:
	# PO-2 panels along the street, plain concrete walls around the rest of the works
	if Assets.has_model("concrete_fence"):
		var x := -40.0
		while x < 28.4:
			Geo.prop(self, "concrete_fence", Vector3(x + 1.205, 0, FENCE_Z), 0.0)
			x += 2.41
		x = 43.0
		while x < 112.0:
			Geo.prop(self, "concrete_fence", Vector3(x + 1.205, 0, FENCE_Z), 0.0)
			x += 2.41
	for w in [[Vector3(-85, 1.25, FENCE_Z), Vector3(90, 2.5, 0.3)], [Vector3(172, 1.25, FENCE_Z), Vector3(120, 2.5, 0.3)],
			[Vector3(-130, 1.25, -79.5), Vector3(0.3, 2.5, 141)], [Vector3(232, 1.25, -79.5), Vector3(0.3, 2.5, 141)],
			[Vector3(51, 1.25, -150), Vector3(362, 2.5, 0.3)]]:
		_b.box(_m.wall, w[0], w[1], 0.0, true)
	# brick gate pillars + arch with the works' name
	for gx in [29.5, 42.5]:
		_b.box(_m.brick, Vector3(gx, 1.9, FENCE_Z), Vector3(1.0, 3.8, 1.0), 0.0, true)
		_b.box(_m.white, Vector3(gx, 3.85, FENCE_Z), Vector3(1.15, 0.12, 1.15))
	_b.box(_m.green, Vector3(36, 4.6, FENCE_Z), Vector3(14.2, 0.9, 0.25))
	_label("UZINA „ELECTROMAȘ”", Vector3(36, 4.6, FENCE_Z + 0.16), 0.0, 0.0044, Color(0.95, 0.9, 0.78), false)
	# the sliding gate, pushed open behind the fence
	var gz := FENCE_Z - 0.6
	_b.box(_m.green, Vector3(48.5, 0.15, gz), Vector3(11.0, 0.12, 0.08))
	_b.box(_m.green, Vector3(48.5, 2.1, gz), Vector3(11.0, 0.1, 0.08))
	var bx := 43.2
	while bx < 54.0:
		_b.box(_m.green, Vector3(bx, 1.1, gz), Vector3(0.05, 2.0, 0.05))
		bx += 0.18
	_b.collider(Transform3D(Basis(), Vector3(48.5, 1.1, gz)), Vector3(11.0, 2.2, 0.12))
	# checkpoint booth just inside, east of the gate
	var bp := Vector3(46.6, 0, -12.6)
	_b.box(_m.plaster, bp + Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 3.2), 0.0, true)
	_b.box(_m.glass, bp + Vector3(0, 1.6, 0), Vector3(3.05, 1.2, 3.05), 0.0, true)
	for c in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
		_b.box(_m.white, bp + c + Vector3(0, 1.6, 0), Vector3(0.14, 1.25, 0.14))
	_b.box(_m.dark, bp + Vector3(0, 2.32, 0), Vector3(3.8, 0.22, 3.8))
	_label("PUNCT DE CONTROL", bp + Vector3(-1.95, 2.55, 0), -PI * 0.5, 0.0032, Color(0.95, 0.92, 0.85))
	# barrier raised for the morning shift
	var pp := Vector3(30.6, 0, -10.4)
	_b.box(_m.yellow, pp + Vector3(0, 0.55, 0), Vector3(0.35, 1.1, 0.35), 0.0, true)
	for k in 12:
		var seg := 0.5
		var along := Vector3(cos(1.35), sin(1.35), 0) * (0.3 + seg * (k + 0.5))
		_b.box_xf(_m.red if k % 2 == 0 else _m.white, Transform3D(Basis(Vector3.BACK, 1.35), pp + Vector3(0, 1.05, 0) + along), Vector3(seg, 0.09, 0.09))
	# foundation stone at the entrance
	_b.box(_m.conc, Vector3(27.2, 0.6, -11.5), Vector3(1.8, 1.2, 0.8), 0.0, true)
	_label("ELECTROMAȘ\n1956", Vector3(27.2, 0.75, -11.08), 0.0, 0.0028, Color(0.85, 0.75, 0.5), false)
	# signs: speed limit + way to the shelter
	_sign_post(Vector3(40.9, 0, -11.2), "10", true)
	_way_sign(Vector3(41.2, 0, -14.5), "ADĂPOST  →")


func _sign_post(p: Vector3, text: String, round_sign: bool) -> void:
	_b.box(_m.steel, p + Vector3(0, 1.15, 0), Vector3(0.07, 2.3, 0.07))
	if round_sign:
		_b.cylinder(_m.red, p + Vector3(0, 2.35, 0.02), p + Vector3(0, 2.35, 0.05), 0.33, 16)
		_b.cylinder(_m.white, p + Vector3(0, 2.35, 0.05), p + Vector3(0, 2.35, 0.065), 0.26, 16)
		_label(text, p + Vector3(0, 2.35, 0.075), 0.0, 0.0035, Color(0.05, 0.05, 0.05), false)


## Civil-defence direction board (white on blue); its face looks along `yaw` (0 = +Z).
func _way_sign(p: Vector3, text: String, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	for s in [-0.7, 0.7]:
		_b.box(_m.steel, p + b * Vector3(s, 1.1, 0), Vector3(0.06, 2.2, 0.06))
	_b.box(_m.blue, p + Vector3(0, 2.0, 0), Vector3(1.8, 0.55, 0.04), yaw)
	_label(text, p + b * Vector3(0, 2.0, 0.03), yaw, 0.0034, Color(0.97, 0.97, 0.95), false)


# --------------------------------------------------------------------------
# Roads, lawns, parking
# --------------------------------------------------------------------------

func _roads() -> void:
	Geo.plane(self, Vector2(ROAD_W, 131.0), Vector3(AVENUE_X, Y_ROAD, -74.5), _m.asphalt)
	for z in [ROAD_A, ROAD_B]:
		Geo.plane(self, Vector2(312.0, ROAD_W), Vector3(46.0, Y_ROAD + 0.005, z), _m.asphalt)
		var x := -105.0
		while x < 196.0:
			if absf(x - AVENUE_X) > 6.0:
				_b.box(_m.white, Vector3(x, Y_ROAD + 0.012, z), Vector3(2.5, 0.01, 0.12))
			x += 6.0
		# curbs
		for s in [-1.0, 1.0]:
			_curb(Vector3(-110, 0, z + s * ROAD_W * 0.5), Vector3(AVENUE_X - ROAD_W * 0.5, 0, z + s * ROAD_W * 0.5))
			_curb(Vector3(AVENUE_X + ROAD_W * 0.5, 0, z + s * ROAD_W * 0.5), Vector3(202, 0, z + s * ROAD_W * 0.5))
	var zz := FENCE_Z - 0.5
	while zz > -140.0:
		if absf(zz - ROAD_A) > 5.0 and absf(zz - ROAD_B) > 5.0:
			_b.box(_m.white, Vector3(AVENUE_X, Y_ROAD + 0.012, zz), Vector3(0.12, 0.01, 2.5))
		zz -= 6.0
	# lawns along the avenue between the gate and the first cross road
	for lx in [29.6, 42.4]:
		Geo.plane(self, Vector2(4.4, 16.5), Vector3(lx, 0.05, -19.5), _m.grass)
		_grass(Rect2(lx - 2.1, -27.6, 4.2, 16.2))
		_curb(Vector3(lx - 2.2, 0, -11.25), Vector3(lx - 2.2, 0, -27.75))
		_curb(Vector3(lx + 2.2, 0, -11.25), Vector3(lx + 2.2, 0, -27.75))
	# staff car park west of the administration block
	Geo.plane(self, Vector2(48.0, 13.0), Vector3(-14.0, Y_ROAD, -19.5), _m.asphalt)
	var spots: Array = []
	var px := -36.5
	while px < 8.0:
		_b.box(_m.white, Vector3(px - 1.35, Y_ROAD + 0.012, -15.5), Vector3(0.1, 0.01, 4.8))
		_b.box(_m.white, Vector3(px - 1.35, Y_ROAD + 0.012, -23.5), Vector3(0.1, 0.01, 4.8))
		spots.append(Vector3(px, 0, -15.6))
		spots.append(Vector3(px, 0, -23.4))
		px += 2.7
	for k in 9:
		var i := rng.randi() % spots.size()
		var sp: Vector3 = spots[i]
		spots.remove_at(i)
		CityLife.parked_car(self, sp, (0.0 if sp.z < -20.0 else PI) + rng.randf_range(-0.04, 0.04), CityLife.CAR_COLORS.pick_random())


func _curb(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	_b.box(_m.conc, (a + b) * 0.5 + Vector3(0, 0.08, 0), Vector3(length if absf(d.x) > absf(d.z) else 0.16, 0.16, 0.16 if absf(d.x) > absf(d.z) else length))


# --------------------------------------------------------------------------
# Buildings
# --------------------------------------------------------------------------

## Administration block on the avenue: rooftop letters, canopy, flags, flower beds and
## the board of honour.
func _admin() -> void:
	var b := _building("admin", Vector3(18.0, 0, -19.5), PI * 0.5, Vector2(15.0, 11.0), 3.3, 3, _m.plaster, Color(0.85, 0.85, 0.82))
	var front := 23.5
	# rooftop letters on a steel frame
	var top := 3.3 + 2.0 * Building.STORY
	for k in 4:
		_b.box(_m.steel, Vector3(18.5, top + 1.0, -26.0 + k * 4.3), Vector3(0.1, 2.0, 0.1))
	_b.box(_m.steel, Vector3(18.5, top + 1.9, -19.5), Vector3(0.1, 0.1, 13.0))
	_label("ELECTROMAȘ", Vector3(18.6, top + 1.1, -19.5), PI * 0.5, 0.019, Color(0.9, 0.22, 0.15))
	# entrance canopy
	_b.box(_m.white, Vector3(front + 0.9, 2.65, -19.5), Vector3(1.8, 0.16, 4.0))
	for s in [-1.0, 1.0]:
		_b.box(_m.white, Vector3(front + 1.65, 1.3, -19.5 + s * 1.8), Vector3(0.14, 2.6, 0.14))
	# raised flower beds
	for z in [-14.8, -24.2]:
		_b.box(_m.conc, Vector3(25.6, 0.3, z), Vector3(1.2, 0.6, 3.6), 0.0, true)
		Geo.plane(self, Vector2(1.0, 3.4), Vector3(25.6, 0.61, z), _m.gravel)
		for k in 14:
			_b.box(_m.flower_r if k % 3 else _m.flower_y, Vector3(25.6 + rng.randf_range(-0.4, 0.4), 0.7, z + rng.randf_range(-1.6, 1.6)), Vector3(0.12, 0.16, 0.12))
	# three flag poles (state flag)
	for z in [-15.5, -19.5, -23.5]:
		var fp := Vector3(27.0, 0, z)
		_b.cylinder(_m.steel, fp, fp + Vector3(0, 8.5, 0), 0.06, 8)
		for k in 3:
			_b.box([_m.blue, _m.yellow, _m.red][k], fp + Vector3(0, 7.8, 0.32 + k * 0.5), Vector3(0.03, 1.0, 0.5))
	# board of honour
	var bo := Vector3(27.6, 0, -27.0)
	for s in [-1.0, 1.0]:
		_b.box(_m.steel, bo + Vector3(0, 1.6, s * 2.1), Vector3(0.1, 3.2, 0.1))
	_b.box(_m.red, bo + Vector3(0, 2.1, 0), Vector3(0.1, 2.0, 4.2))
	for k in 8:
		_b.box(_m.white, bo + Vector3(0.06, 2.35 - (k / 4) * 0.8, -1.5 + (k % 4) * 1.0), Vector3(0.02, 0.6, 0.45))
	_label("PANOUL DE ONOARE", bo + Vector3(0.08, 3.25, 0), PI * 0.5, 0.0035, Color(0.95, 0.85, 0.4), false)
	shelters.append(Vector3(front + 0.4, Y_YARD, -19.5))


## Canteen across the avenue, with the smokers' corner in front.
func _canteen() -> void:
	_building("shop", Vector3(56.0, 0, -19.0), -PI * 0.5, Vector2(16.0, 10.0), 3.6, 1, _m.plaster, Color(0.25, 0.42, 0.65), "CANTINĂ", Color(0.95, 0.92, 0.85))
	Geo.prop(self, "bench", Vector3(48.6, Y_YARD, -22.0), PI * 0.5)
	_b.cylinder(_m.steel, Vector3(48.6, 0, -20.4), Vector3(48.6, 0.7, -20.4), 0.2, 10, true)
	shelters.append(Vector3(50.5, Y_YARD, -19.0))


## Vehicle workshop facing the first cross road, a lorry in front, drums by the wall.
func _garage() -> void:
	_building("depot", Vector3(88.0, 0, -18.0), PI, Vector2(18.0, 10.0), 4.6, 1, _m.brick, Color(0.3, 0.45, 0.3), "ATELIER AUTO")
	_truck(Vector3(82.0, 0, -26.5), PI * 0.5, _m.cab2, false)
	for k in 4:
		var bar := Geo.prop(self, "oil_barrel", Vector3(98.4, 0, -14.5 - k * 0.7), rng.randf() * TAU)
		Assets.set_shadows(bar, false)
	shelters.append(Vector3(88.0, Y_YARD, -24.0))


func _halls() -> void:
	for h in HALLS:
		var hx: float = h[0]
		var hz: float = h[1]
		if Assets.has_model("factory_hall"):
			Geo.prop(self, "factory_hall", Vector3(hx, 0, hz), 0.0)
		else:
			_b.box(_m.brick, Vector3(hx, 6.5, hz), Vector3(10.0, 13.0, 29.6), 0.0, true)
		_label(String(h[2]), Vector3(hx, 9.4, hz + 14.95), 0.0, 0.0085, Color(0.95, 0.92, 0.85))
		# paved apron from the road to the hall door
		if hz > -80.0:
			Geo.plane(self, Vector2(6.0, 10.0), Vector3(hx, 0.055, hz + 19.8), _m.pave)
		shelters.append(Vector3(hx, Y_YARD, hz + 15.4))
	_label("SIGURANȚA MUNCII — DATORIA FIECĂRUIA", Vector3(-38.0, 6.3, -47.0), 0.0, 0.006, Color(0.97, 0.95, 0.88))


## Warehouses with a loading dock, pallets and lorries backed up to it.
func _warehouses() -> void:
	if Assets.has_model("warehouse"):
		Geo.prop(self, "warehouse", Vector3(140, 0, -52), PI * 0.5)
		Geo.prop(self, "warehouse", Vector3(178, 0, -60), 0.0)
	# dock along the south face of the first warehouse
	_b.box(_m.conc, Vector3(140.0, 0.6, -39.5), Vector3(28.0, 1.2, 3.0), 0.0, true)
	_b.box(_m.yellow, Vector3(140.0, 1.21, -38.05), Vector3(28.0, 0.02, 0.12))
	# steps down at the west end of the dock
	for k in 5:
		var sh := (5 - k) * 0.24
		_b.box(_m.conc, Vector3(125.83 - k * 0.35, sh * 0.5, -39.5), Vector3(0.35, sh, 3.0), 0.0, true)
	for k in 7:
		var px := 128.0 + k * 3.6 + rng.randf_range(-0.3, 0.3)
		_pallet(Vector3(px, 1.2, -40.0 + rng.randf_range(-0.3, 0.3)), rng.randi_range(1, 3))
	_truck(Vector3(132.5, 0, -33.9), 0.0, _m.cab, true)
	_truck(Vector3(146.0, 0, -33.9), 0.0, _m.cab2, true)
	shelters.append(Vector3(140.0, 1.2, -40.6))


func _pallet(p: Vector3, layers: int) -> void:
	_b.box(_m.wood, p + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), 0.0, true)
	for l in layers:
		for k in 4:
			var o := Vector3(-0.3 + (k % 2) * 0.6, 0.14 + 0.2 + l * 0.42, -0.25 + (k / 2) * 0.5)
			_b.box(_m.card, p + o, Vector3(0.56, 0.4, 0.46))


## Boxy Soviet lorry. Local +Z = cab end. `flatbed`: open dropside body with cargo.
func _truck(p: Vector3, yaw: float, cab: Material, flatbed: bool) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var g := func(mat: Material, c: Vector3, s: Vector3) -> void:
		_b.box_xf(mat, xf * Transform3D(Basis(), c), s)
	g.call(_m.dark, Vector3(0, 0.75, 0), Vector3(1.1, 0.3, 7.2))
	g.call(cab, Vector3(0, 1.9, 2.75), Vector3(2.45, 1.9, 1.9))
	g.call(_m.glass, Vector3(0, 2.35, 3.71), Vector3(2.1, 0.8, 0.04))
	for s in [-1.0, 1.0]:
		g.call(_m.glass, Vector3(s * 1.23, 2.35, 2.9), Vector3(0.04, 0.7, 1.1))
	g.call(_m.dark, Vector3(0, 0.95, 3.8), Vector3(2.45, 0.35, 0.25))
	g.call(_m.white, Vector3(-0.9, 1.25, 3.73), Vector3(0.3, 0.2, 0.05))
	g.call(_m.white, Vector3(0.9, 1.25, 3.73), Vector3(0.3, 0.2, 0.05))
	if flatbed:
		g.call(_m.wood_dark, Vector3(0, 1.15, -1.1), Vector3(2.5, 0.12, 5.0))
		for s in [-1.0, 1.0]:
			g.call(_m.olive, Vector3(s * 1.22, 1.55, -1.1), Vector3(0.06, 0.7, 5.0))
		g.call(_m.olive, Vector3(0, 1.55, -3.58), Vector3(2.5, 0.7, 0.06))
		g.call(_m.card, Vector3(0, 1.55, -0.2), Vector3(1.8, 0.7, 1.8))
	else:
		g.call(_m.green, Vector3(0, 2.15, -1.1), Vector3(2.5, 2.1, 5.0))
	for wz in [2.6, -1.4, -2.7]:
		for s in [-1.0, 1.0]:
			var c: Vector3 = xf * Vector3(s * 1.0, 0.5, wz)
			var d: Vector3 = xf.basis * Vector3(s * 0.32, 0, 0)
			_b.cylinder(_m.rubber, c - d, c + d, 0.5, 12)
	_b.collider(xf * Transform3D(Basis(), Vector3(0, 1.4, 0)), Vector3(2.5, 2.8, 7.6))


## Boiler house under the chimney, with a fuel-oil tank.
func _boiler_house() -> void:
	_building("depot", Vector3(140.0, 0, -106.0), 0.0, Vector2(18.0, 12.0), 7.5, 1, _m.brick, Color(0.5, 0.15, 0.12), "CENTRALA TERMICĂ")
	var ch := Vector3(140, 0, -120)
	_b.cylinder(_m.brick, ch, ch + Vector3(0, 58, 0), 3.2, 28, true)
	_b.cylinder(_m.wall, ch + Vector3(0, 56.4, 0), ch + Vector3(0, 58.2, 0), 3.6, 28)
	for k in 3:
		_b.cylinder(_m.white, ch + Vector3(0, 46.0 + k * 1.6, 0), ch + Vector3(0, 46.7 + k * 1.6, 0), 3.25, 28)
	var tank := Vector3(163.0, 0, -108.0)
	_b.cylinder(_m.insul, tank, tank + Vector3(0, 7.0, 0), 3.4, 24, true)
	_b.box(_m.steel, tank + Vector3(3.45, 3.5, 0), Vector3(0.08, 7.0, 0.5))
	if Assets.has_model("water_tower"):
		Geo.prop(self, "water_tower", Vector3(118, 0, -114), 0.4)


## Works railway: ballast, sleepers, rails and a short train of wagons.
func _railway() -> void:
	Geo.plane(self, Vector2(362.0, 3.4), Vector3(51.0, 0.05, RAIL_Z), _m.gravel)
	var x := -129.0
	while x < 231.0:
		if absf(x - AVENUE_X) > 4.6:
			_b.box(_m.wood_dark, Vector3(x, 0.1, RAIL_Z), Vector3(0.22, 0.12, 2.5))
		x += 0.62
	for s in [-0.76, 0.76]:
		_b.box(_m.steel, Vector3(51.0, 0.21, RAIL_Z + s), Vector3(362.0, 0.15, 0.07))
	_boxcar(Vector3(62.0, 0, RAIL_Z), _m.wagon)
	_boxcar(Vector3(77.0, 0, RAIL_Z), _m.olive)
	_flatcar(Vector3(92.0, 0, RAIL_Z))


func _bogies(c: Vector3, length: float) -> void:
	for s in [-1.0, 1.0]:
		var bc := c + Vector3(s * (length * 0.5 - 2.4), 0, 0)
		_b.box(_m.dark, bc + Vector3(0, 0.75, 0), Vector3(2.6, 0.4, 2.2))
		for ax in [-0.9, 0.9]:
			for zs in [-0.76, 0.76]:
				_b.cylinder(_m.dark, bc + Vector3(ax, 0.48, zs - 0.08), bc + Vector3(ax, 0.48, zs + 0.08), 0.45, 12)


func _boxcar(c: Vector3, mat: Material) -> void:
	_bogies(c, 13.8)
	_b.box(_m.dark, c + Vector3(0, 1.15, 0), Vector3(13.8, 0.3, 2.9))
	_b.box(mat, c + Vector3(0, 2.75, 0), Vector3(13.6, 2.9, 2.9), 0.0, true)
	_b.box(mat, c + Vector3(0, 4.28, 0), Vector3(13.7, 0.16, 2.6))
	var x := -6.3
	while x <= 6.4:
		for s in [-1.0, 1.0]:
			_b.box(_m.dark, c + Vector3(x, 2.75, s * 1.47), Vector3(0.08, 2.8, 0.05))
		x += 1.4
	for s in [-1.0, 1.0]:
		_b.box(_m.dark, c + Vector3(0, 2.6, s * 1.49), Vector3(2.4, 2.4, 0.04))


func _flatcar(c: Vector3) -> void:
	_bogies(c, 13.0)
	_b.box(_m.wood_dark, c + Vector3(0, 1.3, 0), Vector3(13.0, 0.3, 2.9), 0.0, true)
	for k in 3:
		_b.box(_m.green, c + Vector3(-4.0 + k * 4.0, 2.25, 0), Vector3(3.2, 1.6, 2.4), 0.0, true)


## Insulated steam pipes on supports: from the boiler house south to the first cross road,
## then west along it; raised over the avenue for lorries.
func _pipes() -> void:
	var h := 5.0
	var pts := [Vector3(128.0, h, -100.5), Vector3(122.0, h, -100.5), Vector3(122.0, h, -38.4), Vector3(46.0, h, -38.4),
		Vector3(44.0, 6.9, -38.4), Vector3(28.0, 6.9, -38.4), Vector3(26.0, h, -38.4), Vector3(-72.0, h, -38.4)]
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var side := (b - a).normalized().cross(Vector3.UP).normalized()
		_b.cylinder(_m.insul, a, b, 0.24, 10)
		_b.cylinder(_m.insul, a + side * 0.62 + Vector3(0, -0.06, 0), b + side * 0.62 + Vector3(0, -0.06, 0), 0.16, 8)
		# supports along straight, level runs
		if absf(a.y - b.y) < 0.01:
			var length := a.distance_to(b)
			var n := int(length / 9.0)
			for k in range(1, n + 1):
				var p := a.lerp(b, float(k) / (n + 1))
				if _support_blocked(p):
					continue
				for s in [-0.55, 1.15]:
					_b.box(_m.steel, Vector3(p.x, h * 0.5 - 0.15, p.z) + side * s, Vector3(0.22, h - 0.3, 0.22), 0.0, true)
				var mid := Vector3(p.x, h - 0.33, p.z) + side * 0.3
				_b.box_xf(_m.steel, Transform3D(Basis.looking_at(side, Vector3.UP), mid), Vector3(0.18, 0.18, 2.0))
	# the gantry over the avenue
	for x in [27.0, 45.0]:
		for s in [-0.55, 1.15]:
			_b.box(_m.steel, Vector3(x, 3.4, -38.4 - s), Vector3(0.24, 6.8, 0.24), 0.0, true)
		_b.box(_m.steel, Vector3(x, 6.6, -38.7), Vector3(0.2, 0.2, 2.2))


func _support_blocked(p: Vector3) -> bool:
	if absf(p.z - ROAD_A) < ROAD_W * 0.5 + 0.8 or absf(p.z - ROAD_B) < ROAD_W * 0.5 + 0.8 or absf(p.z - RAIL_Z) < 2.4:
		return true
	if absf(p.x - AVENUE_X) < 11.0 or absf(p.x - 75.0) < 4.5:
		return true
	for hh in HALLS:
		if absf(p.x - float(hh[0])) < 4.0 and p.z < -36.0:
			return true
	return false


## Transformer substation: gravel pad behind a fence, two transformers with radiators.
func _substation() -> void:
	var c := Vector3(50.0, 0, -62.0)
	Geo.plane(self, Vector2(14.0, 10.0), c + Vector3(0, 0.055, 0), _m.gravel)
	var corners := [Vector2(-7, -5), Vector2(7, -5), Vector2(7, 5), Vector2(-7, 5)]
	for i in 4:
		var a2: Vector2 = corners[i]
		var b2: Vector2 = corners[(i + 1) % 4]
		var a := c + Vector3(a2.x, 0, a2.y)
		var b := c + Vector3(b2.x, 0, b2.y)
		var n := int(a.distance_to(b) / 2.5)
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			_b.box(_m.steel, p + Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 0.08))
		for y in [0.4, 1.1, 1.8, 2.15]:
			var d := b - a
			_b.box(_m.steel, (a + b) * 0.5 + Vector3(0, y, 0), Vector3(absf(d.x) + 0.05, 0.03, absf(d.z) + 0.05))
		_b.collider(Transform3D(Basis(), (a + b) * 0.5 + Vector3(0, 1.1, 0)), Vector3(absf((b - a).x) + 0.1, 2.2, absf((b - a).z) + 0.1))
	for k in 2:
		var tp := c + Vector3(-2.6 + k * 5.2, 0, -0.5)
		_b.box(_m.conc, tp + Vector3(0, 0.15, 0), Vector3(3.0, 0.3, 2.2), 0.0, true)
		_b.box(_m.green, tp + Vector3(0, 1.4, 0), Vector3(2.2, 2.2, 1.4), 0.0, true)
		for f in 9:
			_b.box(_m.green, tp + Vector3(-0.9 + f * 0.22, 1.3, 0.85), Vector3(0.04, 1.6, 0.3))
		_b.cylinder(_m.green, tp + Vector3(-0.9, 2.85, -0.4), tp + Vector3(0.9, 2.85, -0.4), 0.28, 12)
		for i2 in 3:
			_b.cylinder(_m.white, tp + Vector3(-0.6 + i2 * 0.6, 2.5, 0.2), tp + Vector3(-0.6 + i2 * 0.6, 3.3, 0.2), 0.07, 8)
	_label("PERICOL DE MOARTE!", c + Vector3(0, 1.6, 5.06), 0.0, 0.0034, Color(0.9, 0.15, 0.1), false)
	_b.box(_m.white, c + Vector3(0, 1.6, 5.03), Vector3(2.2, 0.38, 0.03))


## Obiectivul 17: a paved square in front of the shelter pavilion with benches and boards.
func _shelter_square() -> void:
	Geo.plane(self, Vector2(16.0, 13.0), Vector3(75.0, 0.06, -42.5), _m.pave)
	for s in [-1.0, 1.0]:
		Geo.plane(self, Vector2(3.0, 10.0), Vector3(75.0 + s * 9.5, 0.055, -43.5), _m.grass)
		_grass(Rect2(75.0 + s * 9.5 - 1.4, -48.4, 2.8, 9.8))
		Geo.prop(self, "bench", Vector3(75.0 + s * 6.2, Y_YARD, -44.0), -s * PI * 0.5)
	_way_sign(Vector3(68.4, 0, -37.2), "ADĂPOST NR. 17", -PI * 0.5)
	_way_sign(Vector3(41.2, 0, -27.0), "ADĂPOST  →")


## Lamp posts along the avenue and the first cross road; trees at the entrance.
func _lamps_and_trees() -> void:
	var z := -15.0
	while z > -136.0:
		if absf(z - ROAD_A) > 6.0 and absf(z - ROAD_B) > 6.0 and absf(z - RAIL_Z) > 4.0:
			_lamp(Vector3(AVENUE_X - 4.8, 0, z), 1.0)
			_lamp(Vector3(AVENUE_X + 4.8, 0, z - 8.0), -1.0)
		z -= 16.0
	var x := -96.0
	while x < 196.0:
		if absf(x - AVENUE_X) > 8.0 and absf(x - 75.0) > 6.0 and absf(x - 122.0) > 3.0:
			_lamp(Vector3(x, 0, ROAD_A - ROAD_W * 0.5 - 1.0), 0.0)
		x += 24.0
	for p in [Vector3(29.6, 0, -13.5), Vector3(29.6, 0, -25.5), Vector3(42.4, 0, -25.5)]:
		Geo.prop(self, "tree_leafy", p, rng.randf() * TAU, "box", rng.randf_range(0.7, 0.85))


## Street lamp: steel pole with an arm over the road (`arm` = +1 / -1 along X, 0 = toward +Z).
func _lamp(p: Vector3, arm: float) -> void:
	var dir := Vector3(arm, 0, 0) if arm != 0.0 else Vector3(0, 0, 1)
	_b.box(_m.steel, p + Vector3(0, 3.5, 0), Vector3(0.14, 7.0, 0.14), 0.0, true)
	_b.box(_m.steel, p + Vector3(0, 6.9, 0) + dir * 0.75, Vector3(0.08, 0.08, 1.5) if arm == 0.0 else Vector3(1.5, 0.08, 0.08))
	_b.box(_m.dark, p + Vector3(0, 6.8, 0) + dir * 1.45, Vector3(0.5, 0.16, 0.28) if arm != 0.0 else Vector3(0.28, 0.16, 0.5))
	_b.box(_m.glass, p + Vector3(0, 6.7, 0) + dir * 1.45, Vector3(0.38, 0.04, 0.22) if arm != 0.0 else Vector3(0.22, 0.04, 0.38))


# --------------------------------------------------------------------------
# Open storage and greenery
# --------------------------------------------------------------------------

## Open-air stores: shipping containers, steel pipes, concrete slabs, cable drums.
func _storage() -> void:
	var cols := [_m.wagon, _m.olive, _m.cab2, _m.green, _m.cab]
	# east of the workshop, between the fence and the first cross road
	for k in 4:
		_box_container(Vector3(108.0 + k * 7.0, 0, -16.0), 0.0, cols[k % cols.size()])
		if k % 2 == 0:
			_box_container(Vector3(108.0 + k * 7.0, 2.6, -16.0), 0.0, cols[(k + 2) % cols.size()])
	for k in 3:
		_box_container(Vector3(110.0 + k * 7.0, 0, -22.5), 0.0, cols[(k + 3) % cols.size()])
	_pipe_stack(Vector3(144.0, 0, -18.0), 0.0, 5)
	_pipe_stack(Vector3(144.0, 0, -23.5), 0.0, 4)
	for k in 3:
		_slab_stack(Vector3(158.0 + k * 7.5, 0, -17.0), rng.randi_range(4, 7))
	for k in 4:
		_cable_drum(Vector3(160.0 + k * 3.0, 0, -23.5))
	_truck(Vector3(186.0, 0, -20.0), 0.0, _m.cab, true)
	# behind the halls on the far side of the railway
	for k in 3:
		_pipe_stack(Vector3(-80.0, 0, -108.0 - k * 6.0), PI * 0.5, rng.randi_range(3, 5))
	for k in 4:
		_slab_stack(Vector3(-62.0, 0, -106.0 - k * 4.0), rng.randi_range(3, 6))
	for k in 5:
		_box_container(Vector3(-100.0, 0, -108.0 - k * 6.5), PI * 0.5, cols[k % cols.size()])
	for k in 5:
		_cable_drum(Vector3(-50.0 + k * 2.6, 0, -138.0))


func _box_container(p: Vector3, yaw: float, mat: Material) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	_b.box_xf(mat, xf * Transform3D(Basis(), Vector3(0, 1.3, 0)), Vector3(6.06, 2.59, 2.44), true)
	var x := -2.7
	while x <= 2.75:
		for s in [-1.0, 1.0]:
			_b.box_xf(mat, xf * Transform3D(Basis(), Vector3(x, 1.3, s * 1.235)), Vector3(0.08, 2.4, 0.04))
		x += 0.6
	_b.box_xf(_m.dark, xf * Transform3D(Basis(), Vector3(3.04, 1.3, 0)), Vector3(0.03, 2.4, 0.04))


func _pipe_stack(p: Vector3, yaw: float, rows: int) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	for s in [-2.5, 2.5]:
		_b.box_xf(_m.wood_dark, xf * Transform3D(Basis(), Vector3(s, 0.08, 0)), Vector3(0.2, 0.16, 3.4))
	var r := 0.24
	for row in rows:
		var n := rows - row + 2
		for k in n:
			var z := (k - (n - 1) * 0.5) * r * 2.05
			var y := 0.16 + r + row * r * 1.75
			var a: Vector3 = xf * Vector3(-4.0, y, z)
			var b: Vector3 = xf * Vector3(4.0, y, z)
			_b.cylinder(_m.steel if row % 2 == 0 else _m.green, a, b, r, 10)
	_b.collider(xf * Transform3D(Basis(), Vector3(0, 0.16 + rows * r * 0.9, 0)), Vector3(8.0, 0.32 + rows * r * 1.8, (rows + 2) * r * 2.05))


func _slab_stack(p: Vector3, n: int) -> void:
	for k in n:
		_b.box(_m.conc, p + Vector3(rng.randf_range(-0.05, 0.05), 0.2 + k * 0.32, rng.randf_range(-0.05, 0.05)), Vector3(6.0, 0.24, 1.5))
		for s in [-2.0, 2.0]:
			_b.box(_m.wood_dark, p + Vector3(s, 0.04 + k * 0.32, 0), Vector3(0.12, 0.08, 1.6))
	_b.collider(Transform3D(Basis(), p + Vector3(0, n * 0.16 + 0.04, 0)), Vector3(6.0, n * 0.32 + 0.08, 1.5))


func _cable_drum(p: Vector3) -> void:
	var a := p + Vector3(0, 0.95, -0.42)
	var b := p + Vector3(0, 0.95, 0.42)
	_b.cylinder(_m.wood, a, a + Vector3(0, 0, 0.08), 0.95, 16, true)
	_b.cylinder(_m.wood, b - Vector3(0, 0, 0.08), b, 0.95, 16)
	_b.cylinder(_m.black, a, b, 0.65, 14)


## Grass between the halls, along the roads and on the north block.
func _lawns() -> void:
	for x0 in [-61.0, -33.0]:
		Geo.plane(self, Vector2(18.0, 28.0), Vector3(x0 + 9.0, 0.05, -62.0), _m.grass)
		_grass(Rect2(x0 + 0.3, -75.7, 17.4, 27.4))
	# behind the shelter pavilion (it ends at z -56.5): keep clear of the stairwell
	Geo.plane(self, Vector2(24.0, 21.0), Vector3(70.0, 0.05, -69.5), _m.grass)
	_grass(Rect2(58.3, -79.7, 23.4, 20.0))
	Geo.plane(self, Vector2(40.0, 5.0), Vector3(-80.0, 0.05, -94.0), _m.grass)
	_grass(Rect2(-99.7, -96.3, 39.4, 4.6))
	Geo.plane(self, Vector2(52.0, 40.0), Vector3(95.0, 0.05, -125.0), _m.grass)
	_grass(Rect2(69.3, -144.7, 51.4, 39.4), 0.9)
	for p in [Vector3(-52.0, 0, -55.0), Vector3(-24.0, 0, -70.0), Vector3(84.0, 0, -122.0), Vector3(96.0, 0, -132.0)]:
		Geo.prop(self, "tree_leafy", p, rng.randf() * TAU, "box", rng.randf_range(0.75, 0.95))


# --------------------------------------------------------------------------
# Workers
# --------------------------------------------------------------------------

## People at work: a guard, smokers at the canteen, men on the dock and on the avenue.
func spawn_workers(city: CityLife) -> void:
	city.yard_shelters = shelters
	# [route, speed, standing still, facing]
	var crew := [
		[[Vector3(44.6, Y_YARD, -12.4)], 1.0, true, -PI * 0.5],
		[[Vector3(47.4, Y_YARD, -18.6)], 1.0, true, PI * 0.75],
		[[Vector3(46.6, Y_YARD, -19.9)], 1.0, true, PI * 0.35],
		[[Vector3(47.9, Y_YARD, -20.6)], 1.0, true, -PI * 0.8],
		[[Vector3(129.0, 1.2, -40.6), Vector3(151.0, 1.2, -40.6)], 1.1, false, 0.0],
		[[Vector3(150.0, 1.2, -41.2), Vector3(131.0, 1.2, -41.2)], 1.0, false, 0.0],
		[[Vector3(34.3, Y_ROAD, -14.0), Vector3(34.3, Y_ROAD, -70.0)], 1.3, false, 0.0],
		[[Vector3(38.0, Y_ROAD, -60.0), Vector3(38.0, Y_ROAD, -16.0)], 1.2, false, 0.0],
		[[Vector3(-60.0, Y_ROAD, ROAD_A - 3.0), Vector3(20.0, Y_ROAD, ROAD_A - 3.0)], 1.3, false, 0.0],
		[[Vector3(60.0, Y_ROAD, ROAD_A + 3.0), Vector3(118.0, Y_ROAD, ROAD_A + 3.0)], 1.25, false, 0.0],
		[[Vector3(84.5, Y_YARD, -28.6)], 1.0, true, PI],
	]
	for w in crew:
		var route: Array[Vector3] = []
		route.assign(w[0])
		var p := Pedestrian.new()
		p.idler = w[2]
		p.setup(route, w[1], city)
		city.add_child(p)
		city.people.append(p)
		if w[2]:
			p.rotation.y = w[3]


## Real grass clumps on a lawn (October: green going straw-coloured at the tips).
func _grass(r: Rect2, per_m2 := 1.5) -> void:
	var id := "grass_green" if Foliage.available("grass_green") else "grass_dry"
	Foliage.lawn(self, id, r, 0.05, per_m2 * float(Settings.val("vegetation")), rng, Color(0.95, 0.95, 0.85))
