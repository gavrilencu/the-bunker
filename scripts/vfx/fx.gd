class_name FX
extends RefCounted
## Combat effects: bullet-hole decals, impact particles, tracers, shell casings,
## muzzle-flash texture. All textures are generated procedurally once.

const MAX_DECALS := 60

static var _decals: Array = []
static var _hole_tex: Texture2D
static var _flash_tex: Texture2D
static var _soft_tex: Texture2D


static func hole_texture() -> Texture2D:
	if _hole_tex:
		return _hole_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var ang := atan2(y - n * 0.5, x - n * 0.5)
			var crack := 0.08 * sin(ang * 7.0) + 0.05 * sin(ang * 13.0 + 1.3)
			var core := 1.0 - smoothstep(0.12, 0.2, d)
			var ring := (1.0 - smoothstep(0.22, 0.62 + crack, d)) * 0.75
			var a := clampf(maxf(core, ring) + rng.randf_range(-0.05, 0.05), 0.0, 1.0)
			var c := lerpf(0.02, 0.18, smoothstep(0.1, 0.6, d))
			img.set_pixel(x, y, Color(c, c * 0.95, c * 0.9, a))
	_hole_tex = ImageTexture.create_from_image(img)
	return _hole_tex


static func flash_texture() -> Texture2D:
	if _flash_tex:
		return _flash_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var d := v.length()
			var ang := atan2(v.y, v.x)
			var rays := pow(absf(cos(ang * 3.0)), 18.0) * (1.0 - d) * 1.4
			var glow := pow(maxf(1.0 - d, 0.0), 3.0)
			var a := clampf(glow + rays, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.85 + 0.15 * glow, 0.55 + 0.45 * glow, a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex


static func soft_texture() -> Texture2D:
	if _soft_tex:
		return _soft_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, pow(maxf(1.0 - d, 0.0), 2.0)))
	_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex


## Surface kind from what was hit.
static func surface_of(collider: Object, normal: Vector3) -> String:
	if collider == null:
		return "concrete"
	if collider is Enemy:
		return "flesh"
	var n: Node = collider as Node
	var s := ""
	while n and s.length() < 200:
		s += String(n.name).to_lower() + " "
		if n.get_child_count() > 0:
			s += String(n.get_child(0).name).to_lower() + " "
		n = n.get_parent() if not (n.get_parent() is LevelBase) else null
	for k in ["car", "barrel", "shelf", "locker", "generator", "tank", "truck", "bus", "metal", "sign", "pole", "jerrycan", "door", "fence"]:
		if s.contains(k):
			return "metal"
	if normal.y > 0.7 and State.context == "surface":
		return "dirt"
	return "concrete"


static func impact(parent: Node, pos: Vector3, normal: Vector3, kind: String) -> void:
	if parent == null:
		return
	var col := Color(0.55, 0.52, 0.48, 0.9)
	var amount := 14
	match kind:
		"flesh":
			col = Color(0.42, 0.02, 0.02, 0.95)
			amount = 18
		"metal":
			col = Color(1.0, 0.7, 0.3, 1.0)
		"dirt":
			col = Color(0.42, 0.36, 0.28, 0.9)
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.9 if kind != "metal" else 0.35
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 35.0 if kind != "flesh" else 55.0
	pm.initial_velocity_min = 1.0 if kind != "metal" else 4.0
	pm.initial_velocity_max = 3.5 if kind != "metal" else 9.0
	pm.gravity = Vector3(0, -9.0 if kind in ["metal", "flesh"] else -1.5, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.6 if kind != "metal" else 0.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * (0.09 if kind in ["concrete", "dirt"] else 0.035)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = soft_texture()
	mat.albedo_color = col
	mat.vertex_color_use_as_albedo = true
	if kind == "metal":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = mat
	p.draw_pass_1 = qm
	parent.add_child(p)
	p.global_position = pos + normal * 0.02
	_orient(p, normal)
	p.emitting = true
	p.finished.connect(p.queue_free)
	if kind != "flesh":
		_decal(parent, pos, normal)
	Audio.sfx_at("impact_" + kind if kind != "dirt" else "impact_concrete", pos, -6.0, 30.0, 0.15)


static func _orient(n: Node3D, normal: Vector3) -> void:
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
	n.look_at(n.global_position + normal, up)
	n.rotate_object_local(Vector3.UP, PI)


static func _decal(parent: Node, pos: Vector3, normal: Vector3) -> void:
	var d := Decal.new()
	d.texture_albedo = hole_texture()
	d.size = Vector3(0.11, 0.08, 0.11)
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	parent.add_child(d)
	d.global_position = pos
	# Decal projects along its local -Y: align -Y with -normal
	var y := normal.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	d.global_basis = Basis(x, y, z).rotated(y, randf() * TAU)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var length := from.distance_to(to)
	bm.size = Vector3(0.012, 0.012, length)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.07)
	tw.tween_callback(mi.queue_free)


static func shell(parent: Node, pos: Vector3, right: Vector3, shotgun := false) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006 if not shotgun else 0.011
	cm.bottom_radius = cm.top_radius
	cm.height = 0.025 if not shotgun else 0.06
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.6, 0.25) if not shotgun else Color(0.7, 0.12, 0.08)
	mat.metallic = 0.9 if not shotgun else 0.1
	mat.roughness = 0.35
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var vel := right * randf_range(1.4, 2.2) + Vector3.UP * randf_range(1.0, 1.8)
	var spin := Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	var ground := pos.y - 1.45
	var holder := {"v": vel, "t": 0.0}
	var tick := func(delta: float) -> bool:
		holder.t += delta
		holder.v += Vector3.DOWN * 9.8 * delta
		mi.global_position += holder.v * delta
		mi.rotation += spin * delta
		if mi.global_position.y < ground:
			mi.global_position.y = ground
			return true
		return holder.t > 1.5
	var tw := mi.create_tween()
	tw.tween_method(func(_x: float) -> void:
		if is_instance_valid(mi) and not mi.has_meta("landed"):
			if tick.call(1.0 / 60.0):
				mi.set_meta("landed", true)
				Audio.sfx_at("shell_casing", mi.global_position, -14.0, 12.0, 0.2), 0.0, 1.0, 1.0)
	tw.tween_interval(6.0)
	tw.tween_callback(mi.queue_free)
