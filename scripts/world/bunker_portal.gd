class_name BunkerPortal
extends Node3D
## Surface portal of the civil-defence shelter network ("Obiectivul 17", exit 4):
## a reinforced-concrete facade cut into an earth-covered hill, sloped wing walls
## along a short trench, a cantilevered canopy, the blast door in a steel frame with
## hazard markings, caged sodium lamps, a rotating amber beacon, vent stacks and an
## antenna on the earth cover, sandbags and barriers at the trench mouth. Behind the
## door (shown only while it is open): an entry vestibule and a stair down to the
## inner airlock door, lit by a caged lamp and a bulkhead lamp.
## Local space: facade front at z = 0, door faces -Z, floor at y = 0.

signal entered

const HALF_W := 4.6       # half the trench width (inner face of the wing walls)
const TRENCH := 6.0       # trench length in front of the facade
const HEIGHT := 5.4       # earth cover above the floor at the facade
const FACADE_H := 4.7
const OPEN_YAW := 0.0

var door_pivot: Node3D
var beacon: Node3D
var _busy := false
var _closed := true
var prompt_text := "Ușa adăpostului — Intră în buncăr"
var on_enter: Callable


static func _stripe_texture() -> ImageTexture:
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var band := int(floor((x + y) / 32.0)) % 2
			var c := Color(0.86, 0.66, 0.08) if band == 0 else Color(0.05, 0.05, 0.05)
			# worn paint
			var n := sin(x * 0.71 + y * 1.3) * cos(x * 0.23 - y * 0.47)
			if n > 0.82:
				c = c.lerp(Color(0.4, 0.38, 0.35), 0.6)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func build() -> void:
	# cast concrete (the board-formed set read as wooden planks in warm light)
	var concrete := Assets.pbr("portal_concrete", {"tile": 2.4, "tint": Color(0.8, 0.8, 0.79)})
	var concrete_dark := Assets.pbr("portal_concrete", {"tile": 2.4, "tint": Color(0.5, 0.5, 0.49)})
	var floor_m := Assets.pbr("concrete_floor", {"tile": 3.0, "tint": Color(0.7, 0.69, 0.66)})
	var metal := Assets.pbr("rusty_metal", {"tile": 1.2})
	var paint := Assets.pbr("painted_metal", {"tile": 1.0, "tint": Color(0.35, 0.38, 0.32)})
	var plate_m := Assets.pbr("painted_metal", {"tile": 1.0, "tint": Color(0.16, 0.28, 0.62)})
	var stripes := StandardMaterial3D.new()
	stripes.albedo_texture = _stripe_texture()
	stripes.roughness = 0.75
	stripes.uv1_triplanar = true
	stripes.uv1_world_triplanar = true
	stripes.uv1_scale = Vector3.ONE * 1.2
	# --- apron + trench floor
	Geo.box(self, Vector3(HALF_W * 2.0 + 1.2, 0.3, TRENCH + 1.2), Vector3(0, -0.12, -TRENCH * 0.5 + 0.4), floor_m)
	# kerb / drainage channel along the wing walls
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(0.35, 0.18, TRENCH), Vector3(sx * (HALF_W - 0.18), 0.09, -TRENCH * 0.5), concrete_dark)
	# --- facade (opening 2.4 x 2.45 for the blast door)
	var t := 1.1
	Geo.box(self, Vector3(HALF_W - 1.2, FACADE_H, t), Vector3(-(HALF_W + 1.2) * 0.5, FACADE_H * 0.5, t * 0.5), concrete)
	Geo.box(self, Vector3(HALF_W - 1.2, FACADE_H, t), Vector3((HALF_W + 1.2) * 0.5, FACADE_H * 0.5, t * 0.5), concrete)
	Geo.box(self, Vector3(2.4, FACADE_H - 2.45, t), Vector3(0, 2.45 + (FACADE_H - 2.45) * 0.5, t * 0.5), concrete)
	# pilasters framing the door bay
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(0.55, FACADE_H, 0.35), Vector3(sx * 2.35, FACADE_H * 0.5, -0.17), concrete)
	# canopy (cantilevered slab) + upstand
	Geo.box(self, Vector3(HALF_W * 2.0 + 1.6, 0.55, 2.4), Vector3(0, FACADE_H + 0.27, -0.9), concrete)
	Geo.box(self, Vector3(HALF_W * 2.0 + 1.6, 0.35, 0.25), Vector3(0, FACADE_H + 0.72, -2.0), concrete_dark)
	# --- wing walls (sloped tops), retaining the earth along the trench
	for sx in [-1.0, 1.0]:
		var w := CSGPolygon3D.new()
		w.polygon = PackedVector2Array([Vector2(-0.4, -0.3), Vector2(TRENCH, -0.3), Vector2(TRENCH, 0.95), Vector2(-0.4, FACADE_H + 0.1)])
		w.depth = 1.2
		w.material = concrete
		w.use_collision = true
		w.rotation_degrees.y = 90.0
		w.position = Vector3(sx * HALF_W + (1.2 if sx > 0 else 0.0), 0, 0)
		add_child(w)
		# coping on top of the wing wall
		var cp := CSGPolygon3D.new()
		cp.polygon = PackedVector2Array([Vector2(-0.4, FACADE_H + 0.1), Vector2(TRENCH + 0.1, 0.95), Vector2(TRENCH + 0.1, 1.1), Vector2(-0.4, FACADE_H + 0.25)])
		cp.depth = 1.35
		cp.material = concrete_dark
		cp.rotation_degrees.y = 90.0
		cp.position = Vector3(sx * HALF_W + (1.27 if sx > 0 else -0.07), 0, 0)
		add_child(cp)
	# --- what the open door shows: entry vestibule + stairwell down into the shelter
	_carve_terrain()
	_build_interior(t, stripes)
	# --- blast door: frame on the facade, leaf opens outward
	var vd := Assets.vault_door(true)
	add_child(vd.root)
	# round vault face toward the outside, frame slab flush with the facade front
	(vd.root as Node3D).rotation.y = PI
	(vd.root as Node3D).position = Vector3(0.25, 0.0, 0.83)
	door_pivot = vd.pivot
	# hazard frame around the door bay
	Geo.mesh_box(self, Vector3(0.22, 2.9, 0.06), Vector3(-2.05, 1.45, -0.95), stripes)
	Geo.mesh_box(self, Vector3(0.22, 2.9, 0.06), Vector3(2.05, 1.45, -0.95), stripes)
	Geo.mesh_box(self, Vector3(4.32, 0.22, 0.06), Vector3(0, 2.95, -0.95), stripes)
	Geo.mesh_box(self, Vector3(2.6, 0.04, 0.5), Vector3(0, 0.05, -1.4), stripes)
	# --- signage
	var plate := Geo.mesh_box(self, Vector3(3.5, 0.78, 0.06), Vector3(0, 3.55, -0.36), plate_m)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l1 := Geo.label3d(self, "ADĂPOST DE PROTECȚIE CIVILĂ", Vector3(0, 3.7, -0.4), PI, 0.24, Color(0.93, 0.92, 0.88))
	var l2 := Geo.label3d(self, "OBIECTIVUL 17  ·  IEȘIREA 4", Vector3(0, 3.4, -0.4), PI, 0.17, Color(1.0, 0.8, 0.3))
	for l in [l1, l2]:
		(l as Label3D).shaded = false
		(l as Label3D).modulate = (l as Label3D).modulate * 0.85
	var big := Geo.label3d(self, "17-Б", Vector3(-3.4, 2.4, -0.03), 0.0, 1.1, Color(0.85, 0.82, 0.72, 0.55))
	big.font = Assets.font("heading")
	big.rotation.y = PI
	var warn := Geo.label3d(self, "ACCES INTERZIS\nPERSOANELOR NEAUTORIZATE", Vector3(3.4, 1.7, -0.03), 0.0, 0.13, Color(0.85, 0.2, 0.15, 0.85))
	warn.font = Assets.font("bold")
	warn.rotation.y = PI
	if Assets.has_model("radiation_sign"):
		var rs := Geo.prop(self, "radiation_sign", Vector3(HALF_W + 0.3, 0.0, -TRENCH + 0.6), PI * 0.5, "none")
		rs.scale = Vector3.ONE * 0.9
	# --- lights: caged sodium lamps under the canopy + rotating amber beacon
	for sx in [-1.0, 1.0]:
		if Assets.has_model("lamp_cage"):
			Geo.prop(self, "lamp_cage", Vector3(sx * 2.9, FACADE_H - 0.35, -1.1), 0.0, "none")
		var lamp := Geo.omni(self, Vector3(sx * 2.9, FACADE_H - 0.55, -1.2), Color(1.0, 0.78, 0.52), 1.3, 10.0, true)
		lamp.light_volumetric_fog_energy = 1.2
		var bulb := Geo.mesh_box(self, Vector3(0.12, 0.12, 0.12), Vector3(sx * 2.9, FACADE_H - 0.5, -1.1), Geo.emissive_mat(Color(1.0, 0.7, 0.35), 6.0))
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon = Node3D.new()
	beacon.position = Vector3(HALF_W - 0.6, FACADE_H + 0.9, -1.4)
	add_child(beacon)
	Geo.cylinder(self, 0.16, 0.12, beacon.position + Vector3(0, -0.2, 0), metal)
	var glass := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11
	cm.bottom_radius = 0.13
	cm.height = 0.22
	glass.mesh = cm
	glass.material_override = Geo.emissive_mat(Color(1.0, 0.55, 0.08), 5.0)
	glass.position = beacon.position + Vector3(0, -0.04, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	for k in 2:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.55, 0.1)
		sp.light_energy = 6.0
		sp.spot_range = 38.0
		sp.spot_angle = 16.0
		sp.light_volumetric_fog_energy = 2.5
		sp.shadow_enabled = false
		sp.rotation = Vector3(-0.12, PI * k, 0)
		beacon.add_child(sp)
	var glow := Geo.omni(self, beacon.position, Color(1.0, 0.55, 0.12), 1.2, 6.0, false)
	glow.light_volumetric_fog_energy = 1.5
	# --- earth cover dressing: vent stacks, antenna
	for v in [[Vector3(2.6, HEIGHT - 0.2, 3.0), 0.22], [Vector3(-1.2, HEIGHT - 0.2, 5.5), 0.3], [Vector3(-3.6, HEIGHT - 0.3, 2.2), 0.18]]:
		var p: Vector3 = v[0]
		var r: float = v[1]
		Geo.cylinder(self, r, 1.9, p + Vector3(0, 0.75, 0), metal, Vector3.ZERO, true, 16)
		Geo.cylinder(self, r * 2.1, 0.12, p + Vector3(0, 1.95, 0), metal, Vector3.ZERO, false, 16)
		Geo.cylinder(self, r * 1.5, 0.3, p + Vector3(0, 1.75, 0), metal, Vector3.ZERO, false, 16)
	if Assets.has_model("radio_antenna"):
		var ant := Geo.prop(self, "radio_antenna", Vector3(-3.0, HEIGHT - 0.4, 6.5), 0.3, "none")
		ant.scale = Vector3.ONE * 1.4
	# --- trench mouth: sandbags, barriers, barrels
	for i in 4:
		Geo.prop(self, "sandbags", Vector3(-HALF_W + 0.7 + i * 0.05, 0.0, -TRENCH + 0.4 + i * 1.15), PI * 0.5)
	Geo.prop(self, "sandbags", Vector3(HALF_W - 0.8, 0.0, -TRENCH + 0.6), PI * 0.5 + 0.1)
	Geo.prop(self, "concrete_barrier", Vector3(-HALF_W - 2.5, 0.0, -TRENCH - 1.5), 0.35)
	Geo.prop(self, "concrete_barrier", Vector3(HALF_W + 2.2, 0.0, -TRENCH - 1.8), -0.3)
	Geo.prop(self, "oil_barrel", Vector3(HALF_W - 0.75, 0.0, -1.9), 0.4)
	Geo.prop(self, "oil_barrel", Vector3(HALF_W - 0.7, 0.0, -2.75), 1.1)
	Geo.prop(self, "military_crate", Vector3(-HALF_W + 0.9, 0.0, -1.7), 0.2)
	if Assets.has_model("jerrycan"):
		Geo.prop(self, "jerrycan", Vector3(-HALF_W + 1.0, 0.0, -2.6), 0.9, "none")
	# --- interaction at the door
	var zone := Geo.interact_zone(self, Vector3(3.0, 2.6, 1.4), Vector3(0, 1.3, -1.6), func() -> String:
		return "" if _busy else prompt_text, func() -> void: _use())
	zone.name = "DoorZone"
	_show_interior(false)
	# debug (screenshots of the doorway): --portalopen keeps the door open, --portalnight
	# turns the sun and the sky off to judge the lamps
	if Game.args.has("portalopen"):
		set_open(true)
		print("[portal] open at ", global_position)
	if Game.args.has("portalnight"):
		get_tree().create_timer(0.5).timeout.connect(_debug_night)


# --------------------------------------------------------------------------
# Behind the door
# --------------------------------------------------------------------------

## The terrain is a 1 m heightfield: it climbs from the trench floor to the earth
## cover (+5.4 m) inside the single cell row that ends on the facade line, i.e. a
## near-vertical dirt wall standing just in front of the facade. Its planar (xz)
## texture smears into vertical streaks, so it read as a wooden board: it hid the
## lower facade and filled the doorway. Those triangles are dropped from the render
## mesh (the apron slab lies under them, the facade behind them). The collision
## heightfield is kept: it still stops the player at the door frame.
func _carve_terrain() -> void:
	var terrain: Terrain = null
	if get_parent():
		terrain = get_parent().get_node_or_null("Terrain") as Terrain
	if terrain == null:
		return
	var mi := terrain.get_node_or_null("TerrainInner") as MeshInstance3D
	if mi == null or not (mi.mesh is ArrayMesh) or (mi.mesh as ArrayMesh).get_surface_count() == 0:
		return
	var am := mi.mesh as ArrayMesh
	var arr := am.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var n := int(round(sqrt(float(verts.size()))))
	if n * n != verts.size() or idx.size() != (n - 1) * (n - 1) * 6:
		return
	var to_local_xf := global_transform.affine_inverse() * terrain.global_transform
	var to_terrain := terrain.global_transform.affine_inverse() * global_transform
	# grid range around the trench mouth / facade line
	var lo := Vector2i(n, n)
	var hi := Vector2i(-1, -1)
	var half := terrain.size * 0.5
	var step := terrain.size / float(n - 1)
	for c in [Vector3(-HALF_W - 1.5, 0, -2.0), Vector3(HALF_W + 1.5, 0, -2.0), Vector3(-HALF_W - 1.5, 0, 2.0), Vector3(HALF_W + 1.5, 0, 2.0)]:
		var p: Vector3 = to_terrain * (c as Vector3)
		var g := Vector2i(int(floor((p.x + half) / step)), int(floor((p.z + half) / step)))
		lo = Vector2i(mini(lo.x, g.x), mini(lo.y, g.y))
		hi = Vector2i(maxi(hi.x, g.x), maxi(hi.y, g.y))
	lo = lo.clamp(Vector2i.ZERO, Vector2i(n - 2, n - 2))
	hi = hi.clamp(Vector2i.ZERO, Vector2i(n - 2, n - 2))
	var cut := 0
	for iz in range(lo.y, hi.y + 1):
		for ix in range(lo.x, hi.x + 1):
			var a := iz * n + ix
			var zmin := INF
			var zmax := -INF
			var cx := 0.0
			for v in [a, a + 1, a + n, a + n + 1]:
				var lp: Vector3 = to_local_xf * verts[v]
				zmin = minf(zmin, lp.z)
				zmax = maxf(zmax, lp.z)
				cx += lp.x * 0.25
			# the cell row crossing the facade line, across the trench width
			if zmin < -0.01 and zmax > -0.01 and absf(cx) < HALF_W + 0.5:
				var k := (iz * (n - 1) + ix) * 6
				for j in 6:
					idx[k + j] = a
				cut += 1
	if cut == 0:
		return
	arr[Mesh.ARRAY_INDEX] = idx
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if Game.args.has("trace"):
		print("[portal] terrain cells cut: ", cut)


const STEPS := 14          # risers from the vestibule down to the lower landing
const RISE := 0.19
const GOING := 0.28
const VEST_HW := 1.9       # vestibule half width (the open leaf needs x <= 1.51, z <= 2.58)
const VEST_H := 2.95
const STAIR_Z := 3.3       # first nosing (top of the flight)
const SHAFT_HW := 1.2      # stair shaft half width = the door opening
const END_Z := 9.0         # end wall of the lower landing

var _interior: Node3D


## Entry vestibule behind the blast door and a straight flight of stairs down to a
## lower landing with the inner airlock door. Painted concrete (the bunker's own wall
## shader), steel nosings, yellow handrails, cables, a caged lamp hanging in the
## vestibule (the one shadowed light: its spill through the doorway is shaped by the
## frame) and a bulkhead lamp at the bottom of the stairs.
func _build_interior(t: float, stripes: Material) -> void:
	_interior = Node3D.new()
	_interior.name = "Interior"
	add_child(_interior)
	var root := _interior
	var gy := global_position.y
	var drop := STEPS * RISE                       # lower landing level (below the door sill)
	var flight_end := STAIR_Z + (STEPS - 1) * GOING
	var pitch := atan2(RISE, GOING)
	var paint := Color(0.2, 0.31, 0.26)
	var wall_v := BunkerBuilder.wall_material(paint, true, 0.6)
	wall_v.set_shader_parameter("floor_y", gy)
	var wall_s := BunkerBuilder.wall_material(paint, false, 0.5)
	wall_s.set_shader_parameter("floor_y", gy - drop)
	var fl_id := "bunker_floor" if Assets.has_texture_set("bunker_floor") else "concrete_floor"
	var floor_m := Assets.pbr(fl_id, {"tile": 2.0, "tint": Color(0.6, 0.58, 0.54)})
	var tread_m := Assets.pbr(fl_id, {"tile": 1.6, "tint": Color(0.5, 0.49, 0.46)})
	var ceil_m := Assets.pbr("bunker_ceiling" if Assets.has_texture_set("bunker_ceiling") else "concrete_wall", {"tile": 2.5, "tint": Color(0.66, 0.65, 0.62)})
	var steel := Assets.pbr("rusty_metal", {"tile": 0.8})
	var worn := Assets.pbr("rusty_metal", {"tile": 0.6, "tint": Color(0.5, 0.49, 0.47)})  # trodden steel
	var door_m := Assets.pbr("painted_metal", {"tile": 1.0, "tint": Color(0.55, 0.6, 0.52)})
	var yellow := Geo.color_mat(Color(0.78, 0.56, 0.1), 0.55, 0.15)
	var dark := Geo.color_mat(Color(0.06, 0.06, 0.055), 0.6, 0.4)

	# --- vestibule (floor level with the sill)
	Geo.box(root, Vector3(VEST_HW * 2.0 + 0.6, 0.3, STAIR_Z - 1.0), Vector3(0, -0.15, (STAIR_Z + 1.0) * 0.5), floor_m)
	Geo.box(root, Vector3(VEST_HW * 2.0 + 0.6, 0.3, STAIR_Z - t + 0.3), Vector3(0, VEST_H + 0.15, (STAIR_Z + t) * 0.5), ceil_m)
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(0.3, VEST_H, STAIR_Z - t), Vector3(sx * (VEST_HW + 0.15), VEST_H * 0.5, (STAIR_Z + t) * 0.5), wall_v)
		# back wall either side of the stair opening
		Geo.box(root, Vector3(VEST_HW - SHAFT_HW + 0.3, VEST_H, 0.3), Vector3(sx * (SHAFT_HW + VEST_HW + 0.3) * 0.5, VEST_H * 0.5, STAIR_Z - 0.15), wall_v)
	# steel sill plate through the doorway
	_mbox(root, Vector3(2.4, 0.03, 1.25), Vector3(0, 0.035, 0.5), worn)
	# lintel (downstand) over the stair head, hazard band + stencil
	_mbox(root, Vector3(SHAFT_HW * 2.0, VEST_H - 2.3, 0.3), Vector3(0, (VEST_H + 2.3) * 0.5, STAIR_Z - 0.15), wall_v)
	_mbox(root, Vector3(SHAFT_HW * 2.0, 0.14, 0.02), Vector3(0, 2.37, STAIR_Z - 0.31), stripes)
	_stencil(root, "↓  OBIECTIVUL 17  ↓", Vector3(0, 2.66, STAIR_Z - 0.32), 0.17, Color(0.88, 0.86, 0.78, 0.82))
	# hazard marking at the stair head
	_mbox(root, Vector3(SHAFT_HW * 2.0, 0.012, 0.22), Vector3(0, 0.006, STAIR_Z - 0.2), stripes)

	# --- stair shaft
	var shaft_len := END_Z - STAIR_Z + 0.3
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(0.3, VEST_H + drop + 0.3, shaft_len), Vector3(sx * (SHAFT_HW + 0.15), (VEST_H - drop - 0.3) * 0.5, STAIR_Z - 0.3 + shaft_len * 0.5), wall_s)
	Geo.box(root, Vector3(SHAFT_HW * 2.0 + 0.6, VEST_H + drop + 0.3, 0.3), Vector3(0, (VEST_H - drop - 0.3) * 0.5, END_Z + 0.15), wall_s)
	# steps: tread k at -(k+1)*RISE, nosing k on the edge of the tread above
	for k in STEPS - 1:
		var top := -(k + 1) * RISE
		_mbox(root, Vector3(SHAFT_HW * 2.0, RISE + 0.3, GOING), Vector3(0, top - (RISE + 0.3) * 0.5, STAIR_Z + (k + 0.5) * GOING), tread_m)
	for k in STEPS:
		var nz := STAIR_Z + k * GOING
		_mbox(root, Vector3(SHAFT_HW * 2.0 - 0.02, 0.035, 0.05), Vector3(0, -k * RISE - 0.0125, nz - 0.022), yellow if k == 0 or k == STEPS - 1 else worn)
		_mbox(root, Vector3(SHAFT_HW * 2.0 - 0.02, 0.05, 0.008), Vector3(0, -k * RISE - 0.03, nz + 0.003), worn)
	# lower landing
	Geo.box(root, Vector3(SHAFT_HW * 2.0 + 0.6, 0.3, END_Z - flight_end + GOING), Vector3(0, -drop - 0.15, (END_Z + flight_end - GOING) * 0.5), floor_m)
	# walkable ramp over the flight (one collider instead of fourteen steps)
	var run := Vector2(STEPS * GOING, drop)
	Geo.collider(root, Vector3(SHAFT_HW * 2.0, 0.2, run.length()), Vector3(0, -drop * 0.5 - 0.1 * cos(pitch), STAIR_Z + run.x * 0.5 - 0.1 * sin(pitch)), Vector3(pitch, 0, 0))
	# soffit following the flight 2.3 m above the nosings, then the landing ceiling
	var land_ceil := -drop + 2.4
	var s0 := Vector2(STAIR_Z, 2.3)
	var s1 := Vector2(STAIR_Z + (2.3 - land_ceil) / tan(pitch), land_ceil)
	var mid := (s0 + s1) * 0.5
	var nrm := Vector2(sin(pitch), cos(pitch))  # (z, y) normal of the soffit underside
	var dn := Vector2(cos(pitch), -sin(pitch))  # (z, y) down the slope
	mid += nrm * 0.15 - dn * 0.175              # slab centre; the extra length goes into the lintel
	var soffit := _mbox(root, Vector3(SHAFT_HW * 2.0 + 0.6, 0.3, s0.distance_to(s1) + 0.35), Vector3(0, mid.y, mid.x), ceil_m)
	soffit.rotation.x = pitch
	_mbox(root, Vector3(SHAFT_HW * 2.0 + 0.6, 0.3, END_Z - s1.x + 0.2), Vector3(0, land_ceil + 0.15, (END_Z + s1.x) * 0.5), ceil_m)

	# --- handrails (yellow tube on wall brackets), 0.9 m above the nosing line
	for sx in [-1.0, 1.0]:
		var x: float = sx * (SHAFT_HW - 0.075)
		var a := Vector3(x, 0.9, STAIR_Z - 0.45)
		var b := Vector3(x, 0.9, STAIR_Z)
		var c := Vector3(x, 0.9 - (STEPS - 1) * RISE, flight_end)
		var d := Vector3(x, c.y, flight_end + 0.35)
		for seg in [[a, b], [b, c], [c, d]]:
			_rod(root, seg[0], seg[1], 0.024, yellow)
		for f in [0.0, 0.33, 0.66, 1.0]:
			var p := b.lerp(c, f) + Vector3(0, -0.05, 0)
			_rod(root, p, Vector3(sx * SHAFT_HW, p.y, p.z), 0.012, steel)
			_mbox(root, Vector3(0.012, 0.12, 0.07), Vector3(sx * (SHAFT_HW - 0.006), p.y, p.z), steel)

	# --- services: three cables down the left wall of the shaft, a junction box,
	#     an extinguisher and a fire detector in the vestibule
	if Assets.has_model("cable_run"):
		# 1 m pieces (model along +Y): down the slope under the soffit, then level to the end wall
		var along := Vector3(0, -sin(pitch), cos(pitch))
		var slope_len := (2.3 - land_ceil) / sin(pitch)
		for kc in 3:
			var p0 := Vector3(-SHAFT_HW + 0.03, 2.05 - kc * 0.09, STAIR_Z - 0.3)
			var p1 := p0 + along * slope_len
			for run_spec in [[p0, along, slope_len, PI * 0.5 + pitch], [p1, Vector3(0, 0, 1), END_Z - p1.z, PI * 0.5]]:
				var o: Vector3 = run_spec[0]
				var dir: Vector3 = run_spec[1]
				var length: float = run_spec[2]
				var i := 0.0
				while i < length - 0.02:
					var c := Geo.prop(root, "cable_run", o + dir * i, 0.0, "none")
					c.rotation = Vector3(run_spec[3], 0, 0)
					c.scale.y = minf(1.0, length - i)
					Assets.set_shadows(c, false)
					i += 1.0
	if Assets.has_model("utility_box"):
		Assets.set_shadows(Geo.prop(root, "utility_box", Vector3(-VEST_HW + 0.12, 1.35, 2.55), PI * 0.5, "none"), false)
	if Assets.has_model("fire_extinguisher"):
		Assets.set_shadows(Geo.prop(root, "fire_extinguisher", Vector3(-VEST_HW + 0.2, 0.0, 1.75), PI * 0.5, "none"), false)
	if Assets.has_model("fire_alarm"):
		var fa := Geo.prop(root, "fire_alarm", Vector3(0.6, VEST_H - 0.01, 2.0), 0.0, "none")
		fa.rotation.x = PI
		Assets.set_shadows(fa, false)

	# --- lower landing: inner airlock door, painted number, red "occupied" lamp
	var dx := -0.42
	_mbox(root, Vector3(1.16, 2.04, 0.08), Vector3(dx, -drop + 1.02, END_Z - 0.03), steel)
	var leaf := _mbox(root, Vector3(0.96, 1.9, 0.06), Vector3(dx, -drop + 0.95, END_Z - 0.09), door_m)
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for hy in [0.4, 1.5]:
		_mbox(root, Vector3(0.1, 0.12, 0.06), Vector3(dx + 0.44, -drop + hy, END_Z - 0.14), dark)
	var wheel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.13
	tor.outer_radius = 0.16
	tor.rings = 20
	wheel.mesh = tor
	wheel.material_override = steel
	wheel.rotation.x = PI * 0.5
	wheel.position = Vector3(dx - 0.05, -drop + 1.1, END_Z - 0.17)
	root.add_child(wheel)
	_rod(root, Vector3(dx - 0.05, -drop + 1.1, END_Z - 0.12), Vector3(dx - 0.05, -drop + 1.1, END_Z - 0.18), 0.03, steel)
	var big := _stencil(root, "17", Vector3(0.68, -drop + 1.62, END_Z - 0.01), 0.62, Color(0.86, 0.82, 0.7, 0.85))
	big.font = Assets.font("heading")
	_stencil(root, "ECLUZA", Vector3(0.68, -drop + 1.22, END_Z - 0.01), 0.12, Color(0.86, 0.82, 0.7, 0.8))
	var red := _mbox(root, Vector3(0.08, 0.08, 0.06), Vector3(dx - 0.68, -drop + 1.9, END_Z - 0.04), Geo.emissive_mat(Color(1.0, 0.12, 0.05), 5.0))
	red.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- lamps
	# caged lamp hanging in the vestibule (shadowed: the doorway shapes its spill)
	var lp := Vector3(-0.5, VEST_H, 2.2)
	_rod(root, lp, lp + Vector3(0, -0.12, 0), 0.01, steel)
	if Assets.has_model("lamp_cage"):
		var lc := Assets.model("lamp_cage")
		root.add_child(lc)
		lc.position = lp + Vector3(0, -0.47, 0)
		Assets.set_shadows(lc, false)
	var bulb := _mbox(root, Vector3(0.07, 0.09, 0.07), lp + Vector3(0, -0.36, 0), Geo.emissive_mat(Color(1.0, 0.72, 0.4), 7.0))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l1 := Geo.omni(root, lp + Vector3(0, -0.42, 0), Color(1.0, 0.74, 0.48), 2.8, 9.0, true)
	l1.light_volumetric_fog_energy = 0.8
	# oval bulkhead lamp over the inner door at the bottom of the stairs
	var bp := Vector3(dx, -drop + 2.23, END_Z - 0.02)
	var base := _mbox(root, Vector3(0.3, 0.2, 0.05), bp + Vector3(0, 0, -0.025), dark)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.radial_segments = 16
	sm.rings = 8
	dome.mesh = sm
	dome.scale = Vector3(1.3, 0.8, 0.5)
	dome.material_override = Geo.emissive_mat(Color(1.0, 0.7, 0.38), 6.0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position = bp + Vector3(0, 0, -0.06)
	root.add_child(dome)
	for gyo in [-0.04, 0.0, 0.04]:
		_mbox(root, Vector3(0.27, 0.012, 0.012), bp + Vector3(0, gyo, -0.115), dark)
	var l2 := Geo.omni(root, bp + Vector3(0, -0.1, -0.3), Color(1.0, 0.66, 0.36), 2.6, 6.5, false)
	l2.light_volumetric_fog_energy = 0.4


## Mesh-only box (no collision).
func _mbox(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	return Geo.mesh_box(parent, size, pos, mat)


## Thin cylinder between two points.
func _rod(parent: Node, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if d.length() > 0.0001:
		mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	return mi


## Painted stencil on a wall facing -Z (toward the door).
func _stencil(parent: Node, text: String, pos: Vector3, size: float, color: Color) -> Label3D:
	var l := Geo.label3d(parent, text, pos, PI, size, color)
	l.font = Assets.font("bold")
	l.shaded = true
	return l


## Interior meshes and lamps only exist while the door is (being) opened: during the
## raid the door is shut and they would cost draw calls and a shadow map for nothing.
func _show_interior(on: bool) -> void:
	if _interior:
		_interior.visible = on


func _debug_night() -> void:
	var lv := Game.level
	if lv == null:
		return
	var sun: Variant = lv.get("sun")
	if sun is DirectionalLight3D:
		(sun as DirectionalLight3D).light_energy = 0.0
	var env: Variant = lv.get("env")
	if env is Environment:
		var e := env as Environment
		e.ambient_light_energy = 0.04
		e.background_energy_multiplier = 0.03
		e.fog_light_color = Color(0.02, 0.025, 0.035)
		e.volumetric_fog_albedo = Color(0.25, 0.25, 0.27)
		e.volumetric_fog_ambient_inject = 0.0
		if e.sky and e.sky.sky_material is PanoramaSkyMaterial:
			(e.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = 0.02


func _process(delta: float) -> void:
	if beacon:
		beacon.rotation.y += delta * 3.2


## Door swings open (start of a raid: the player has just come out).
func set_open(open: bool) -> void:
	_closed = not open
	_show_interior(open)
	if door_pivot:
		door_pivot.rotation.y = OPEN_YAW if open else Assets.DOOR_CLOSED_YAW


func close_behind(delay := 1.2) -> void:
	if Game.args.has("portalopen"):
		return
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or door_pivot == null:
		return
	Audio.sfx_at("door_vault_close", global_position + Vector3(0, 1.5, -1), -2.0, 40.0, 0.0)
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation:y", Assets.DOOR_CLOSED_YAW, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_closed = true
	_show_interior(false)
	if Game.args.has("trace"):
		print("[portal] door closed yaw=", door_pivot.rotation.y)
	Audio.sfx_at("impact_metal", global_position + Vector3(0, 1.5, -1), 0.0, 50.0, 0.05)
	if Game.player:
		Game.player.add_shake(0.25)


func _use() -> void:
	if _busy:
		return
	_busy = true
	_show_interior(true)
	Audio.sfx_at("door_vault_open", global_position + Vector3(0, 1.5, -1), 0.0, 40.0, 0.0)
	if Game.player:
		Game.player.can_move = false
		Game.player.add_shake(0.3)
	if door_pivot:
		var tw := create_tween()
		tw.tween_property(door_pivot, "rotation:y", OPEN_YAW, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	entered.emit()
	if on_enter.is_valid():
		on_enter.call()
