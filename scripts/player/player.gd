class_name Player
extends CharacterBody3D
## First-person survivor controller (movement, stamina, interaction, camera FX).
## Weapons live in WeaponSystem (child of the camera).

const WALK := 3.4
const SPRINT := 6.3
const CROUCH := 1.7
const JUMP := 4.4
const STAND_H := 1.8
const CROUCH_H := 1.15
const EYE := 1.64
const CROUCH_EYE := 1.0
const INTERACT_DIST := 2.7

var head: Node3D
var cam: Camera3D
var ray: RayCast3D
var flashlight: SpotLight3D
var weapons: WeaponSystem
var capsule: CapsuleShape3D
var col_shape: CollisionShape3D

var pitch := 0.0
var crouching := false
var can_move := true
var can_look := true
var can_interact := true
var combat_enabled := false
var footstep_surface := "concrete"
var speed_mult := 1.0
var shake := 0.0
var gravity_scale := 1.0
var stamina := 100.0
var exhausted := false
var spread := 0.0
var sprinting := false

var weapon: String:
	get: return weapons.current if weapons else ""

var _bob_t := 0.0
var _step_acc := 0.0
var _hold := 0.0
var _target: Interactable = null
var _eye := EYE
var _was_on_floor := true
var _fall_speed := 0.0
var _stamina_delay := 0.0
var _demolish_target := -1

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	col_shape = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = STAND_H
	col_shape.shape = capsule
	col_shape.position.y = STAND_H * 0.5
	add_child(col_shape)

	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Settings.fov
	cam.near = 0.03
	cam.far = 9000.0
	cam.current = true
	head.add_child(cam)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -INTERACT_DIST)
	ray.collision_mask = 1 | 8
	ray.collide_with_areas = false
	ray.add_exception(self)
	cam.add_child(ray)

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 26.0
	flashlight.spot_angle = 26.0
	flashlight.spot_angle_attenuation = 1.6
	flashlight.light_energy = 3.4
	flashlight.light_color = Color(1.0, 0.93, 0.8)
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 0.6
	flashlight.position = Vector3(0.18, -0.12, 0.0)
	flashlight.visible = false
	cam.add_child(flashlight)

	weapons = WeaponSystem.new()
	cam.add_child(weapons)
	weapons.setup(self)
	Game.register_player(self)


func set_pitch(p: float) -> void:
	pitch = clampf(p, -1.45, 1.45)
	head.rotation.x = pitch


func look_at_point(p: Vector3) -> void:
	var d := p - head.global_position
	rotation.y = atan2(-d.x, -d.z)
	set_pitch(atan2(d.y, Vector2(d.x, d.z).length()))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_look:
		var mm := event as InputEventMouseMotion
		var s := Settings.mouse_sensitivity * lerpf(1.0, 0.62, weapons.ads)
		rotate_y(-mm.relative.x * s)
		set_pitch(pitch - mm.relative.y * s * (-1.0 if Settings.invert_y else 1.0))
		weapons.add_sway(mm.relative)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var ctx := State.context
	if event.is_action_pressed("flashlight"):
		if State.count("flashlight") > 0 or ctx == "intro":
			flashlight.visible = not flashlight.visible
			Audio.sfx("ui_click", -8.0)
	elif event.is_action_pressed("inventory") and ctx in ["bunker", "surface"] and not Game.build_mode_active:
		HUD.open_panel(InventoryPanel.new())
	elif event.is_action_pressed("build") and ctx == "bunker" and not Game.build_mode_active:
		HUD.open_panel(BuildPanel.new())
	elif event.is_action_pressed("upgrades") and ctx == "bunker" and not Game.build_mode_active:
		HUD.open_panel(TechPanel.new())
	elif event.is_action_pressed("map") and ctx in ["bunker", "surface"] and not Game.build_mode_active:
		if Game.level and Game.level.has_method("open_local_map"):
			Game.level.open_local_map()
	elif event.is_action_pressed("demolish") and _demolish_target >= 0 and Game.level and Game.level.has_method("demolish"):
		Game.level.demolish(_demolish_target)
	elif event.is_action_pressed("heal") and ctx in ["bunker", "surface"]:
		if not State.use_item("bandage"):
			if not State.use_item("medkit"):
				HUD.toast("Nu ai bandaje.", "warn")
	elif combat_enabled:
		if event.is_action_pressed("slot_1"):
			equip("axe")
		elif event.is_action_pressed("slot_2"):
			equip("pistol")
		elif event.is_action_pressed("slot_3"):
			equip("rifle")
		elif event.is_action_pressed("slot_4"):
			equip("shotgun")
		elif event.is_action_pressed("rotate"):
			weapons.reload()
		elif event.is_action_pressed("wheel_up") or event.is_action_pressed("wheel_down"):
			_cycle_weapon(1 if event.is_action_pressed("wheel_down") else -1)


func _cycle_weapon(dir: int) -> void:
	var owned: Array = []
	for id in ["axe", "pistol", "rifle", "shotgun"]:
		if State.count(id) > 0:
			owned.append(id)
	if owned.is_empty():
		return
	var i := owned.find(weapons.current)
	equip(owned[posmod(i + dir, owned.size())])


func _physics_process(delta: float) -> void:
	_move(delta)
	_interact(delta)
	_camera_fx(delta)
	if combat_enabled:
		weapons.tick(delta, sprinting, Vector2(velocity.x, velocity.z).length(), is_on_floor())
		spread = weapons.spread_now * 14.0


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= _gravity * gravity_scale * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	var input := Vector2.ZERO
	if can_move and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and on_floor and not crouching and stamina > 8.0 and State.overweight() < 15.0:
			velocity.y = JUMP
			use_stamina(12.0)
		var want_crouch := Input.is_action_pressed("crouch")
		if want_crouch != crouching:
			if want_crouch or not _ceiling_blocked():
				crouching = want_crouch
	if int(get_meta("debug_move", 0)) > 0 and can_move:
		input = Vector2(0, -1)
	var over := State.overweight() if State.context in ["bunker", "surface"] else 0.0
	var can_sprint := not exhausted and stamina > 1.0 and over < 5.0 and weapons.ads < 0.3
	sprinting = (Input.is_action_pressed("sprint") or int(get_meta("debug_move", 0)) == 2) and not crouching and input.y < 0.0 and can_move and can_sprint and input.length() > 0.1
	var spd := (CROUCH if crouching else (SPRINT if sprinting else WALK)) * speed_mult
	spd *= lerpf(1.0, 0.55, weapons.ads)
	if State.context in ["bunker", "surface"] and State.energy < 12.0:
		spd *= 0.72
	if over > 0.0:
		spd *= 0.8 if over < 15.0 else 0.55
	_update_stamina(delta, sprinting)
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var accel := 11.0 if on_floor else 2.5
	velocity.x = lerpf(velocity.x, dir.x * spd, minf(accel * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * spd, minf(accel * delta, 1.0))
	move_and_slide()

	var target_h := CROUCH_H if crouching else STAND_H
	capsule.height = lerpf(capsule.height, target_h, minf(12.0 * delta, 1.0))
	col_shape.position.y = capsule.height * 0.5
	_eye = lerpf(_eye, CROUCH_EYE if crouching else EYE, minf(10.0 * delta, 1.0))
	head.position.y = _eye

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if on_floor and hspeed > 0.5:
		_step_acc += hspeed * delta
		var stride := 2.6 if sprinting else 2.1
		if _step_acc >= stride:
			_step_acc = 0.0
			Audio.sfx("footstep_" + footstep_surface, -14.0 + (3.0 if sprinting else 0.0) - (6.0 if crouching else 0.0), 0.08)
		_bob_t += delta * hspeed * 1.9
	if on_floor and not _was_on_floor:
		Audio.sfx("footstep_" + footstep_surface, -9.0)
		shake = maxf(shake, clampf(_fall_speed / 20.0, 0.05, 0.4))
		weapons.land(clampf(_fall_speed / 8.0, 0.1, 1.0))
		_fall_speed = 0.0
	_was_on_floor = on_floor


func use_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_delay = 0.9
	if stamina <= 0.0:
		exhausted = true
		Audio.sfx("breath_heavy", -8.0, 0.05)


func _update_stamina(delta: float, is_sprinting: bool) -> void:
	if State.context == "intro":
		stamina = 100.0
		return
	if is_sprinting:
		use_stamina(15.0 * (1.0 + State.overweight() / 20.0) * delta)
	else:
		_stamina_delay -= delta
		if _stamina_delay <= 0.0:
			var regen := 24.0 * (0.55 if State.energy < 25.0 else 1.0) * (0.6 if State.hydration < 15.0 else 1.0)
			stamina = minf(stamina + regen * delta, 100.0)
	if exhausted and stamina > 30.0:
		exhausted = false


func _ceiling_blocked() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * (STAND_H + 0.1), 1)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()


func _interact(delta: float) -> void:
	var prompt := ""
	var target: Interactable = null
	_demolish_target = -1
	if can_interact and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Game.build_mode_active:
		ray.force_raycast_update()
		var c := ray.get_collider()
		var n: Node = c
		while n and not (n is Interactable):
			if n.has_meta("built_index"):
				_demolish_target = int(n.get_meta("built_index"))
			n = n.get_parent()
			if n is Player or n == get_tree().current_scene:
				n = null
		if n is Interactable:
			if n.has_meta("built_index"):
				_demolish_target = int(n.get_meta("built_index"))
			target = n
			prompt = target.get_prompt()
			if prompt == "":
				target = null
	if target != _target:
		_hold = 0.0
		_target = target
	var progress := 0.0
	var alt := "Demontează (50% înapoi)" if _demolish_target >= 0 and State.context == "bunker" else ""
	if _target:
		var ht := _target.get_hold_time()
		if ht <= 0.0:
			if Input.is_action_just_pressed("interact"):
				_target.use(self)
		else:
			if Input.is_action_pressed("interact"):
				_hold += delta
				progress = clampf(_hold / ht, 0.0, 1.0)
				if _hold >= ht:
					_hold = 0.0
					progress = 0.0
					_target.use(self)
			else:
				_hold = 0.0
		var title := ""
		var action := prompt
		var parts := prompt.split(" — ", false, 1)
		if parts.size() == 2:
			title = parts[0]
			action = parts[1]
		HUD.set_interaction(title, action, ht > 0.0, progress, alt)
	elif alt != "":
		HUD.set_interaction("Construcție", "", false, 0.0, alt)
	else:
		HUD.set_interaction("", "", false, 0.0)


func _camera_fx(delta: float) -> void:
	shake = maxf(shake - delta * 1.4, 0.0)
	var amp := clampf(Vector2(velocity.x, velocity.z).length() / SPRINT, 0.0, 1.0) * float(Settings.val("headbob")) if is_on_floor() else 0.0
	amp *= lerpf(1.0, 0.3, weapons.ads)
	var bob := Vector3(cos(_bob_t) * 0.025, absf(sin(_bob_t)) * 0.045, 0.0) * amp
	var t := Time.get_ticks_msec() * 0.001
	var sh := Vector3(sin(t * 37.0) + sin(t * 23.0) * 0.5, cos(t * 31.0) + sin(t * 41.0) * 0.5, 0.0) * shake * 0.06
	cam.position = bob + sh
	var ca := weapons.cam_anim
	cam.rotation = Vector3(ca.x, ca.y, sin(t * 29.0) * shake * 0.03 + ca.z)
	var target := Settings.fov * weapons.fov_mult() + (6.0 if sprinting else 0.0)
	cam.fov = lerpf(cam.fov, target, minf(10.0 * delta, 1.0))


func add_shake(amount: float) -> void:
	shake = clampf(maxf(shake, amount), 0.0, 3.0)


# --------------------------------------------------------------------------
# Combat glue
# --------------------------------------------------------------------------

func enable_combat(on: bool) -> void:
	combat_enabled = on
	weapons.switch(weapons.best_weapon() if on else "")


func equip(w: String) -> void:
	weapons.switch(w)


func weapon_text() -> String:
	return ""


func take_hit(amount: float, from: Vector3, bleed_chance := 0.3) -> bool:
	State.damage(amount, "enemy")
	HUD.hurt(amount)
	HUD.damage_from(from)
	add_shake(0.5)
	weapons._r_rvel += Vector3(randf_range(-80, 80), randf_range(-120, 120), randf_range(-200, 200))
	if randf() < bleed_chance:
		var was := State.bleeding
		State.bleeding = minf(State.bleeding + 1.0, 3.0)
		if was <= 0.0:
			HUD.toast("Sângerezi! Folosește un bandaj [H].", "danger")
	var push := (global_position - from)
	push.y = 0
	velocity += push.normalized() * 3.0
	return State.dead
