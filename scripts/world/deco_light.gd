class_name DecoLight
extends Interactable
## Placeable light fixture for the bunker (ceiling, wall or floor mounted).
##
## Each type builds its own geometry and light rig. The light follows the bunker power
## (generator = full, emergency batteries = 30 %, none = off; the lantern has its own
## battery) and the per-light settings kept in the save: on/off, colour preset,
## brightness and shadows. [E] opens LightPanel.
## Origin conventions: ceiling fixtures hang down from y = 0, wall fixtures stick out
## along +Z from the wall plane z = 0, floor fixtures stand on y = 0.

const COLORS := [
	["Cald", Color(1.0, 0.74, 0.46)],
	["Neutru", Color(1.0, 0.9, 0.76)],
	["Rece", Color(0.78, 0.88, 1.0)],
	["Chihlimbar", Color(1.0, 0.5, 0.12)],
	["Roșu", Color(1.0, 0.13, 0.07)],
	["Verde", Color(0.35, 1.0, 0.42)],
	["Albastru", Color(0.28, 0.48, 1.0)],
	["Violet", Color(0.74, 0.34, 1.0)],
]
const LEVEL_MIN := 0.1
const LEVEL_MAX := 1.5

## Per type: default colour index and shadows, emission energy of the glowing parts,
## flicker = joins the random bunker flicker, start_flicker = stutters when switched on.
const RIGS := {
	"lamp": {"color": 0, "shadow": true, "glow": 6.0, "flicker": true},
	"fluoro": {"color": 2, "shadow": false, "glow": 7.0, "flicker": true, "start_flicker": true},
	"sconce": {"color": 0, "shadow": false, "glow": 5.0},
	"bulkhead": {"color": 1, "shadow": false, "glow": 3.0},
	"beacon": {"color": 4, "shadow": false, "glow": 4.0},
	"string_lights": {"color": 0, "shadow": false, "glow": 5.0},
	"floor_lamp": {"color": 0, "shadow": false, "glow": 4.0},
	"work_light": {"color": 1, "shadow": true, "glow": 9.0},
	"lantern": {"color": 0, "shadow": false, "glow": 3.0},
}

var type := ""
var def: Dictionary
var rig: Dictionary
## Persistent settings {on, c, l, s}: a reference into the save data.
var cfg: Dictionary
## Build-mode preview: no collision, no interaction.
var preview := false
var lights: Array[Light3D] = []
var bases: Array[float] = []
## Set by the level's shadow budget: only the lamps nearest the player cast shadows.
var shadow_ok := true
## [material, base emission energy] of every glowing surface
var glows: Array = []
var rotor: Node3D

var _power := "gen"
var _lit := false
var _k := 1.0
var _flick: Tween
var _metal: Material
var _dark: Material
var _steel: Material


static func default_cfg(t: String) -> Dictionary:
	var r: Dictionary = RIGS.get(t, {})
	return {"on": true, "c": int(r.get("color", 0)), "l": 1.0, "s": bool(r.get("shadow", false))}


static func is_light(t: String) -> bool:
	return RIGS.has(t)


func setup(p_type: String, p_cfg: Dictionary, p_preview := false) -> DecoLight:
	type = p_type
	def = ItemDB.BUILDABLES.get(type, {})
	rig = RIGS.get(type, {})
	cfg = p_cfg
	var d := default_cfg(type)
	for k in d:
		if not cfg.has(k):
			cfg[k] = d[k]
	preview = p_preview
	_metal = Assets.pbr("painted_metal", {"tile": 0.4, "fallback": Color(0.24, 0.26, 0.24)})
	_dark = Geo.color_mat(Color(0.05, 0.05, 0.05), 0.45, 0.6)
	_steel = Geo.color_mat(Color(0.34, 0.34, 0.32), 0.35, 0.85)
	match type:
		"lamp": _build_lamp()
		"fluoro": _build_fluoro()
		"sconce": _build_sconce()
		"bulkhead": _build_bulkhead()
		"beacon": _build_beacon()
		"string_lights": _build_string()
		"floor_lamp": _build_floor_lamp()
		"work_light": _build_work_light()
		"lantern": _build_lantern()
	for l in lights:
		l.light_volumetric_fog_energy = 1.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 40.0
		l.distance_fade_length = 10.0
		l.shadow_bias = 0.06
		l.shadow_normal_bias = 1.2
	if preview:
		collision_layer = 0
		collision_mask = 0
	else:
		var aabb := Assets.model_aabb(self)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = aabb.size.max(Vector3.ONE * 0.08)
		cs.shape = bs
		cs.position = aabb.get_center()
		add_child(cs)
		set_ghost(false)
		prompt_func = func() -> String: return "%s — Setări lumină" % def.get("name", "Lumină")
		used.connect(func(_by: Node) -> void: HUD.open_panel(LightPanel.new(self)))
	set_process(rotor != null)
	apply()
	return self


func title() -> String:
	return def.get("name", "Lumină")


func color() -> Color:
	return COLORS[clampi(int(cfg.get("c", 0)), 0, COLORS.size() - 1)][1]


func is_lit() -> bool:
	return _lit


func self_powered() -> bool:
	return bool(def.get("self_powered", false))


func apply_power(ps: String) -> void:
	var was := _lit
	_power = ps
	apply()
	if _lit and not was and rig.get("start_flicker", false) and not preview:
		flicker(7)


## Pushes cfg + power state to the lights and glowing materials.
func apply() -> void:
	var own := self_powered()
	_lit = bool(cfg.get("on", true)) and (own or _power != "none")
	_k = clampf(float(cfg.get("l", 1.0)), LEVEL_MIN, LEVEL_MAX) * (1.0 if own or _power == "gen" else 0.3)
	_set_output(1.0)


func _set_output(m: float) -> void:
	var col := color()
	for i in lights.size():
		var l := lights[i]
		l.visible = _lit
		l.light_color = col
		l.light_energy = bases[i] * _k * m
		l.shadow_enabled = bool(cfg.get("s", false)) and shadow_ok and i == 0
	for g in glows:
		var mat: StandardMaterial3D = g[0]
		mat.emission = col
		mat.emission_energy_multiplier = float(g[1]) * _k * m if _lit else 0.0


func set_shadow_ok(v: bool) -> void:
	if v == shadow_ok:
		return
	shadow_ok = v
	if not lights.is_empty():
		lights[0].shadow_enabled = bool(cfg.get("s", false)) and v


## A short stutter of the light (bunker atmosphere, fluorescent start-up).
func flicker(n := 4) -> void:
	if not _lit or lights.is_empty():
		return
	if _flick and _flick.is_valid():
		_flick.kill()
	_flick = create_tween()
	for i in n:
		var dip := randf_range(0.03, 0.4)
		_flick.tween_method(_set_output, 1.0, dip, 0.04)
		_flick.tween_method(_set_output, dip, 1.0, randf_range(0.03, 0.12))
	_flick.tween_callback(apply)


func _process(delta: float) -> void:
	if rotor and _lit:
		rotor.rotate_y(delta * TAU * 1.15)


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

func _glow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.9, 0.85)
	m.roughness = 0.25
	m.emission_enabled = true
	glows.append([m, float(rig.get("glow", 4.0))])
	return m


## Makes the emissive surfaces of an imported model controllable (colour, brightness).
func _adopt_model_glow(root: Node, energy_override := -1.0) -> void:
	if root is MeshInstance3D and (root as MeshInstance3D).mesh:
		var mi := root as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src is StandardMaterial3D and (src as StandardMaterial3D).emission_enabled:
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				mi.set_surface_override_material(i, m)
				var e := energy_override if energy_override > 0.0 else m.emission_energy_multiplier
				glows.append([m, e])
	for c in root.get_children():
		_adopt_model_glow(c, energy_override)


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return mi


func _cyl(r_top: float, r_bottom: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, sides := 16, parent: Node3D = null) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return _mesh(cm, pos, mat, rot, Vector3.ONE, parent)


func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(bm, pos, mat, rot, Vector3.ONE, parent)


func _sphere(r: float, pos: Vector3, mat: Material, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	var mi := _mesh(sm, pos, mat, Vector3.ZERO, scl, parent)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Thin rod between two points (wires, tripod legs).
func _rod(a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var mi := _cyl(r, r, d.length(), (a + b) * 0.5, mat, Vector3.ZERO, 6)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	return mi


func _omni(pos: Vector3, energy: float, light_range: float, parent: Node3D = null) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	(parent if parent else self).add_child(l)
	l.position = pos
	lights.append(l)
	bases.append(energy)
	return l


## Spot shining along the parent's -Z rotated by `rot`.
func _spot(pos: Vector3, rot: Vector3, energy: float, light_range: float, angle: float, parent: Node3D = null) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.spot_range = light_range
	l.spot_angle = angle
	l.spot_angle_attenuation = 1.2
	(parent if parent else self).add_child(l)
	l.position = pos
	l.rotation = rot
	lights.append(l)
	bases.append(energy)
	return l


# --------------------------------------------------------------------------
# Fixtures
# --------------------------------------------------------------------------

## Industrial cage lamp hanging on a short rod.
func _build_lamp() -> void:
	_cyl(0.035, 0.035, 0.012, Vector3(0, -0.006, 0), _steel)
	_cyl(0.01, 0.01, 0.1, Vector3(0, -0.05, 0), _steel)
	var m := Assets.model("lamp_cage")
	add_child(m)
	m.position.y = -0.45
	Assets.set_shadows(m, false)
	_adopt_model_glow(m)
	_omni(Vector3(0, -0.42, 0), 2.6, 8.0)  # shorter range: fewer lights overlap per pixel


## Fluorescent fitting on two drop rods; the diffuser tube is emissive.
func _build_fluoro() -> void:
	for z in [-0.42, 0.42]:
		_cyl(0.006, 0.006, 0.14, Vector3(0, -0.07, z), _steel, Vector3.ZERO, 6)
		_cyl(0.025, 0.025, 0.01, Vector3(0, -0.005, z), _steel)
	var m := Assets.model("fluorescent_lamp")
	add_child(m)
	m.position.y = -0.14 - 0.088
	Assets.set_shadows(m, false)
	_adopt_model_glow(m, 6.0)
	var tube := _cyl(0.017, 0.017, 1.08, Vector3(0, -0.232, 0), _glow_mat(), Vector3(PI * 0.5, 0, 0), 10)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_omni(Vector3(0, -0.4, 0), 2.3, 8.0)


## Wall plate + arm with a small cage lamp hanging from its tip.
func _build_sconce() -> void:
	_box(Vector3(0.12, 0.17, 0.02), Vector3(0, 0, 0.01), _metal)
	_cyl(0.011, 0.011, 0.3, Vector3(0, 0.05, 0.16), _steel, Vector3(PI * 0.5, 0, 0), 8)
	_cyl(0.008, 0.008, 0.06, Vector3(0, 0.02, 0.3), _steel, Vector3.ZERO, 6)
	var m := Assets.model("lamp_cage")
	add_child(m)
	m.scale = Vector3.ONE * 0.75
	m.position = Vector3(0, -0.01 - 0.35 * 0.75, 0.3)
	Assets.set_shadows(m, false)
	_adopt_model_glow(m)
	_omni(Vector3(0, -0.16, 0.34), 1.4, 7.0)


## Oval Soviet bulkhead lamp: cast base, frosted dome, grille.
func _build_bulkhead() -> void:
	var oval := Vector3(1.35, 1.0, 1.0)
	_mesh(_cyl_mesh(0.1, 0.1, 0.04, 24), Vector3(0, 0, 0.02), _metal, Vector3(PI * 0.5, 0, 0), oval)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.075
	rim.outer_radius = 0.095
	rim.rings = 24
	_mesh(rim, Vector3(0, 0, 0.045), _dark, Vector3(PI * 0.5, 0, 0), oval)
	_sphere(0.078, Vector3(0, 0, 0.045), _glow_mat(), Vector3(1.35, 1.0, 0.6))
	for y in [-0.035, 0.0, 0.035]:
		_box(Vector3(0.21, 0.01, 0.01), Vector3(0, y, 0.093), _dark)
	_box(Vector3(0.01, 0.15, 0.01), Vector3(0, 0, 0.095), _dark)
	_omni(Vector3(0, 0, 0.2), 1.3, 6.0)


## Rotating warning beacon on a wall bracket (two counter-facing spots on a rotor).
func _build_beacon() -> void:
	_box(Vector3(0.14, 0.14, 0.02), Vector3(0, 0, 0.01), _metal)
	_box(Vector3(0.05, 0.03, 0.17), Vector3(0, -0.05, 0.1), _metal)
	_cyl(0.068, 0.075, 0.05, Vector3(0, -0.015, 0.2), _dark, Vector3.ZERO, 20)
	var dome := _cyl(0.052, 0.06, 0.11, Vector3(0, 0.065, 0.2), _glow_mat(), Vector3.ZERO, 20)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere(0.052, Vector3(0, 0.12, 0.2), glows.back()[0], Vector3(1, 0.5, 1))
	rotor = Node3D.new()
	add_child(rotor)
	rotor.position = Vector3(0, 0.065, 0.2)
	_spot(Vector3.ZERO, Vector3(0, -PI * 0.5, 0), 5.0, 10.0, 24.0, rotor)
	_spot(Vector3.ZERO, Vector3(0, PI * 0.5, 0), 5.0, 10.0, 24.0, rotor)
	_omni(Vector3(0, 0.07, 0.27), 0.5, 3.0)


## 2.4 m garland of small bulbs sagging between two hooks.
func _build_string() -> void:
	var n := 13
	var length := 2.4
	var sag := 0.16
	var pts: Array[Vector3] = []
	for i in n:
		var t := float(i) / (n - 1)
		pts.append(Vector3(-length * 0.5 + length * t, -sag * 4.0 * t * (1.0 - t), 0.035))
	var wire := Geo.color_mat(Color(0.03, 0.03, 0.03), 0.6)
	for i in n - 1:
		_rod(pts[i], pts[i + 1], 0.0035, wire)
	var g := _glow_mat()
	for i in range(1, n - 1):
		_cyl(0.007, 0.007, 0.022, pts[i] + Vector3(0, -0.014, 0), _dark, Vector3.ZERO, 6)
		_sphere(0.019, pts[i] + Vector3(0, -0.04, 0), g)
	for x in [-length * 0.5, length * 0.5]:
		_box(Vector3(0.02, 0.03, 0.035), Vector3(x, 0, 0.018), _steel)
	for x in [-0.8, 0.0, 0.8]:
		_omni(Vector3(x, -0.15, 0.12), 0.35, 3.2)


## Floor lamp: weighted base, pole, open fabric shade lit from inside.
func _build_floor_lamp() -> void:
	_cyl(0.15, 0.165, 0.03, Vector3(0, 0.015, 0), _metal, Vector3.ZERO, 28)
	_cyl(0.012, 0.012, 1.42, Vector3(0, 0.74, 0), _steel, Vector3.ZERO, 8)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.82, 0.74, 0.6)
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.emission_enabled = true
	glows.append([cloth, 0.6])
	var cm := _cyl_mesh(0.13, 0.21, 0.26, 28)
	cm.cap_top = false
	cm.cap_bottom = false
	var shade := _mesh(cm, Vector3(0, 1.49, 0), cloth)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere(0.034, Vector3(0, 1.43, 0), _glow_mat())
	_omni(Vector3(0, 1.42, 0), 1.5, 6.5)


## Site floodlight on a tripod, head tilted down, shining along +Z.
func _build_work_light() -> void:
	var hub := Vector3(0, 0.75, 0)
	for k in 3:
		var a := TAU * k / 3.0 + PI / 6.0
		_rod(Vector3(cos(a) * 0.36, 0.0, sin(a) * 0.36), hub, 0.011, _steel)
	_cyl(0.016, 0.016, 0.82, Vector3(0, 1.16, 0), _steel, Vector3.ZERO, 8)
	_box(Vector3(0.36, 0.022, 0.03), Vector3(0, 1.57, 0), _dark)
	for x in [-0.17, 0.17]:
		_box(Vector3(0.02, 0.15, 0.03), Vector3(x, 1.645, 0), _dark)
	var head := Node3D.new()
	add_child(head)
	head.position = Vector3(0, 1.66, 0)
	head.rotation.x = 0.35
	_box(Vector3(0.3, 0.22, 0.1), Vector3.ZERO, Geo.color_mat(Color(0.75, 0.55, 0.08), 0.5, 0.3), Vector3.ZERO, head)
	var lens := _box(Vector3(0.26, 0.18, 0.01), Vector3(0, 0, 0.051), _glow_mat(), Vector3.ZERO, head)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [-0.05, 0.0, 0.05]:
		_box(Vector3(0.27, 0.008, 0.008), Vector3(0, y, 0.058), _dark, Vector3.ZERO, head)
	_spot(Vector3(0, 0, 0.07), Vector3(0, PI, 0), 7.0, 14.0, 40.0, head)
	_omni(Vector3(0, 0, 0.16), 0.4, 2.5, head)


## Battery camping lantern (works without bunker power).
func _build_lantern() -> void:
	_cyl(0.055, 0.06, 0.025, Vector3(0, 0.0125, 0), _dark, Vector3.ZERO, 20)
	var glass := _cyl(0.044, 0.044, 0.11, Vector3(0, 0.08, 0), _glow_mat(), Vector3.ZERO, 20)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_box(Vector3(0.008, 0.11, 0.008), Vector3(cos(a) * 0.05, 0.08, sin(a) * 0.05), _dark)
	_cyl(0.03, 0.06, 0.035, Vector3(0, 0.152, 0), _dark, Vector3.ZERO, 20)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.038
	handle.outer_radius = 0.046
	handle.rings = 20
	_mesh(handle, Vector3(0, 0.19, 0), _steel, Vector3(PI * 0.5, 0, 0))
	_omni(Vector3(0, 0.09, 0), 0.9, 4.5)


func _cyl_mesh(r_top: float, r_bottom: float, h: float, sides := 16) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return cm
