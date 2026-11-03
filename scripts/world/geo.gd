class_name Geo
extends RefCounted
## Static helpers to build level geometry, props, lights.


static func mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	return mi


## Solid box with collision.
static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0, shadows := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body


## Invisible collider.
static func collider(parent: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	body.rotation = rot
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body


static func plane(parent: Node, size: Vector2, pos: Vector3, mat: Material, collide := false) -> Node3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collide:
		var body := StaticBody3D.new()
		parent.add_child(body)
		body.position = pos
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(size.x, 0.2, size.y)
		cs.shape = sh
		cs.position.y = -0.1
		body.add_child(cs)
		return body
	parent.add_child(mi)
	mi.position = pos
	return mi


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, collide := false, sides := 24) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		parent.add_child(body)
		body.position = pos
		body.rotation = rot
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		return body
	parent.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	return mi


## Places model `id`. collide: "box" (StaticBody + fitted box), "none".
## Returns the root (StaticBody3D for "box", model Node3D otherwise).
static func prop(parent: Node, id: String, pos: Vector3, rot_y := 0.0, collide := "box", scale := 1.0) -> Node3D:
	var m := Assets.model(id)
	m.scale = Vector3.ONE * scale
	if collide == "box":
		var body := StaticBody3D.new()
		parent.add_child(body)
		body.position = pos
		body.rotation.y = rot_y
		body.add_child(m)
		fit_box(body, m, scale)
		return body
	parent.add_child(m)
	m.position = pos
	m.rotation.y = rot_y
	return m


## Adds a box CollisionShape3D to `body` matching the model's AABB.
static func fit_box(body: CollisionObject3D, model: Node3D, scale := 1.0, shrink := 0.96) -> CollisionShape3D:
	var aabb := Assets.model_aabb(model)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = (aabb.size * scale * shrink).max(Vector3.ONE * 0.05)
	cs.shape = sh
	cs.position = model.position + (aabb.position + aabb.size * 0.5) * scale
	body.add_child(cs)
	return cs


## Interactable prop (model + collision). `ghost` = non-blocking.
static func interact_prop(parent: Node, id: String, pos: Vector3, rot_y: float, prompt_fn: Callable, use_fn: Callable, hold := 0.0, ghost := false, scale := 1.0) -> Interactable:
	var it := Interactable.new()
	parent.add_child(it)
	it.position = pos
	it.rotation.y = rot_y
	var m := Assets.model(id)
	m.scale = Vector3.ONE * scale
	it.add_child(m)
	fit_box(it, m, scale, 1.0)
	it.prompt_func = prompt_fn
	it.used.connect(func(_by: Node) -> void: use_fn.call())
	it.hold_time = hold
	it.set_ghost(ghost)
	it.set_meta("model", m)
	return it


## Invisible interactable volume.
static func interact_zone(parent: Node, size: Vector3, pos: Vector3, prompt_fn: Callable, use_fn: Callable, hold := 0.0) -> Interactable:
	var it := Interactable.new()
	parent.add_child(it)
	it.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	it.prompt_func = prompt_fn
	it.used.connect(func(_by: Node) -> void: use_fn.call())
	it.hold_time = hold
	it.set_ghost(true)
	return it


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, shadows := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.shadow_bias = 0.06
	l.shadow_normal_bias = 1.2
	l.light_volumetric_fog_energy = 1.4
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	parent.add_child(l)
	l.position = pos
	return l


static func spot(parent: Node, pos: Vector3, look_dir: Vector3, color: Color, energy: float, light_range: float, angle: float, shadows := true) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.6
	parent.add_child(l)
	l.position = pos
	l.look_at(pos + look_dir, Vector3.UP if absf(look_dir.normalized().y) < 0.99 else Vector3.FORWARD)
	return l


static func color_mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func emissive_mat(c: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func label3d(parent: Node, text: String, pos: Vector3, rot_y := 0.0, size := 0.2, color := Color(0.9, 0.85, 0.75)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Assets.font("heading")
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	parent.add_child(l)
	l.position = pos
	l.rotation.y = rot_y
	return l


## Floating dust motes in a box volume.
static func dust(parent: Node, center: Vector3, extents: Vector3, amount := 120, color := Color(1, 0.95, 0.85, 0.35)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(8, int(amount * float(Settings.val("particles"))))
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.visibility_aabb = AABB(-extents, extents * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0, -0.01, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.06
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed_random = 0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.008, 0.008)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# lit dust: only visible where light actually falls (light shafts)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.roughness = 1.0
	mat.disable_receive_shadows = false
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	qm.material = mat
	p.draw_pass_1 = qm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = center
	return p
