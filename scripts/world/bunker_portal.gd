class_name BunkerPortal
extends Node3D
## Surface portal of the civil-defence shelter network ("Obiectivul 17", exit 4):
## a reinforced-concrete facade cut into an earth-covered hill, sloped wing walls
## along a short trench, a cantilevered canopy, the blast door in a steel frame with
## hazard markings, caged sodium lamps, a rotating amber beacon, vent stacks and an
## antenna on the earth cover, sandbags and barriers at the trench mouth.
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
	var concrete := Assets.pbr("concrete_wall", {"tile": 1.4, "tint": Color(0.66, 0.66, 0.65)})
	var concrete_dark := Assets.pbr("concrete_wall", {"tile": 1.4, "tint": Color(0.4, 0.4, 0.39)})
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
	# --- tunnel behind the door (seen when it opens)
	var tun := concrete_dark
	Geo.box(self, Vector3(5.0, 0.3, 7.0), Vector3(0, -0.15, t + 3.5), tun)
	Geo.box(self, Vector3(5.0, 0.3, 7.0), Vector3(0, 3.05, t + 3.5), tun)
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(0.3, 3.2, 7.0), Vector3(sx * 2.5, 1.5, t + 3.5), tun)
	Geo.box(self, Vector3(5.0, 3.2, 0.3), Vector3(0, 1.5, t + 7.0), tun)
	var red := Geo.omni(self, Vector3(0, 2.6, t + 4.0), Color(1.0, 0.18, 0.08), 0.8, 6.0, false)
	red.light_volumetric_fog_energy = 0.5
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


func _process(delta: float) -> void:
	if beacon:
		beacon.rotation.y += delta * 3.2


## Door swings open (start of a raid: the player has just come out).
func set_open(open: bool) -> void:
	_closed = not open
	if door_pivot:
		door_pivot.rotation.y = OPEN_YAW if open else Assets.DOOR_CLOSED_YAW


func close_behind(delay := 1.2) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or door_pivot == null:
		return
	Audio.sfx_at("door_vault_close", global_position + Vector3(0, 1.5, -1), -2.0, 40.0, 0.0)
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation:y", Assets.DOOR_CLOSED_YAW, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_closed = true
	if Game.args.has("trace"):
		print("[portal] door closed yaw=", door_pivot.rotation.y)
	Audio.sfx_at("impact_metal", global_position + Vector3(0, 1.5, -1), 0.0, 50.0, 0.05)
	if Game.player:
		Game.player.add_shake(0.25)


func _use() -> void:
	if _busy:
		return
	_busy = true
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
