class_name NukeBlast
extends Node3D
## Procedural nuclear detonation: flash light, fireball, rising stem + cap,
## toroidal roll, ground base surge and an expanding blast-wave dust wall.

const CLOUD_SHADER := preload("res://shaders/cloud.gdshader")
const DUST_SHADER := preload("res://shaders/dust_wall.gdshader")

var shock_speed := 360.0
var shock_radius := 0.0
var t := 0.0
var active := false

var flash_light: OmniLight3D
var fireball: MeshInstance3D
var stem: MeshInstance3D
var cap: MeshInstance3D
var torus: MeshInstance3D
var surge: MeshInstance3D
var shock: MeshInstance3D
var shock_inner: MeshInstance3D
var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	visible = false
	flash_light = OmniLight3D.new()
	flash_light.omni_range = 14000.0
	flash_light.omni_attenuation = 0.5
	flash_light.light_color = Color(1.0, 0.92, 0.8)
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	flash_light.light_volumetric_fog_energy = 0.0
	flash_light.position = Vector3(0, 600, 0)
	add_child(flash_light)

	fireball = _cloud_part(_sphere(), 1.0, 0.18, 1.6, Vector3(0, 1, 0))
	stem = _cloud_part(_stem_mesh(), 0.8, 0.35, 2.4, Vector3(0, -1.5, 0))
	cap = _cloud_part(_sphere(), 0.9, 0.3, 2.0, Vector3(0, -0.6, 0))
	torus = _cloud_part(_torus(), 0.9, 0.35, 2.6, Vector3(0, 1.0, 0))
	surge = _cloud_part(_sphere(), 0.0, 0.25, 3.0, Vector3(1, 0, 0))
	(surge.material_override as ShaderMaterial).set_shader_parameter("cool_color", Color(0.48, 0.42, 0.36))
	for m in [fireball, stem, cap, torus, surge]:
		m.visible = false

	shock = _dust_ring(Color(0.5, 0.42, 0.34), 0.95)
	shock_inner = _dust_ring(Color(0.36, 0.3, 0.25), 0.8)


func _sphere() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 72
	s.rings = 36
	return s


func _stem_mesh() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.55
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 48
	c.rings = 24
	c.cap_top = false
	c.cap_bottom = false
	return c


func _torus() -> TorusMesh:
	var t2 := TorusMesh.new()
	t2.inner_radius = 0.55
	t2.outer_radius = 1.0
	t2.rings = 64
	t2.ring_segments = 32
	return t2


func _cloud_part(mesh: Mesh, heat: float, disp: float, nscale: float, roll: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = CLOUD_SHADER
	mat.set_shader_parameter("heat", heat)
	mat.set_shader_parameter("disp", disp)
	mat.set_shader_parameter("noise_scale", nscale)
	mat.set_shader_parameter("roll_dir", roll)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2000.0
	_mats.append(mat)
	add_child(mi)
	return mi


func _dust_ring(c: Color, opacity: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 256
	cm.rings = 4
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var mat := ShaderMaterial.new()
	mat.shader = DUST_SHADER
	mat.set_shader_parameter("dust_color", c)
	mat.set_shader_parameter("opacity", opacity)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16000.0
	mi.visible = false
	add_child(mi)
	return mi


func detonate() -> void:
	active = true
	visible = true
	t = 0.0
	for m in [fireball, stem, cap, torus, surge, shock, shock_inner]:
		m.visible = true


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	# Flash: blinding then decaying to a fiery glow.
	var flash := 60.0 * exp(-t * 2.2) + 4.0 * exp(-t * 0.12)
	flash_light.light_energy = flash
	flash_light.light_color = Color(1.0, 0.92, 0.8).lerp(Color(1.0, 0.45, 0.15), clampf(t / 6.0, 0.0, 1.0))

	var rise := clampf(t / 32.0, 0.0, 1.0)
	var ease_rise := 1.0 - pow(1.0 - rise, 2.2)
	var top_y := lerpf(250.0, 3200.0, ease_rise)
	var heat := clampf(1.0 - t / 26.0, 0.12, 1.0)

	# Fireball expands fast, rises and becomes the cap's core.
	var fr := lerpf(80.0, 520.0, clampf(t / 2.5, 0.0, 1.0)) * (1.0 + 0.4 * rise)
	fireball.scale = Vector3(fr, fr * 0.92, fr)
	fireball.position.y = lerpf(fr * 0.6, top_y - fr * 0.2, clampf(t / 8.0, 0.0, 1.0) * ease_rise + clampf(t / 8.0, 0.0, 1.0) * 0.3)
	(fireball.material_override as ShaderMaterial).set_shader_parameter("heat", clampf(1.0 - t / 14.0, 0.25, 1.0))
	(fireball.material_override as ShaderMaterial).set_shader_parameter("emission_strength", 14.0 * clampf(1.0 - t / 30.0, 0.3, 1.0))

	# Cap: wide, flattened, slowly spreading.
	var cr := lerpf(300.0, 1500.0, clampf(t / 40.0, 0.0, 1.0)) * (0.6 + 0.4 * ease_rise)
	cap.scale = Vector3(cr, cr * lerpf(0.75, 0.45, rise), cr)
	cap.position.y = top_y
	torus.scale = Vector3(cr * 1.08, cr * 0.9, cr * 1.08)
	torus.position.y = top_y - cr * 0.28
	torus.rotation.y += delta * 0.03
	for m in [cap, torus]:
		(m.material_override as ShaderMaterial).set_shader_parameter("heat", heat * 0.9)

	# Stem from the ground to the cap.
	var sh := maxf(top_y - cr * 0.3, 10.0)
	var sr := lerpf(90.0, 260.0, rise)
	stem.scale = Vector3(sr, sh, sr)
	stem.position.y = sh * 0.5
	(stem.material_override as ShaderMaterial).set_shader_parameter("heat", heat * 0.7)

	# Base surge along the ground.
	var gr := lerpf(100.0, 2600.0, clampf(t / 45.0, 0.0, 1.0))
	surge.scale = Vector3(gr, lerpf(60.0, 260.0, rise), gr)
	surge.position.y = 0.0

	for m in _mats:
		m.set_shader_parameter("lightness", lerpf(1.6, 0.85, clampf(t / 10.0, 0.0, 1.0)))

	# Blast wave.
	shock_radius = t * shock_speed
	var h := lerpf(260.0, 120.0, clampf(shock_radius / 6000.0, 0.0, 1.0))
	shock.scale = Vector3(shock_radius, h, shock_radius)
	shock.position.y = h * 0.5 - 5.0
	var r2 := maxf(shock_radius - 120.0, 1.0)
	shock_inner.scale = Vector3(r2, h * 1.3, r2)
	shock_inner.position.y = h * 0.65 - 5.0
