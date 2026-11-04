class_name Enemy
extends CharacterBody3D
## Surface hostiles. kind: mutant | hazmat | dog | bandit.
## Melee kinds: wander -> chase -> attack. Bandits: patrol -> keep distance, strafe, shoot.

enum S { WANDER, CHASE, ATTACK, HURT, ALERT, DEAD }

const KINDS := {
	"mutant": {"model": "enemy_zombie", "alt": "enemy_mutant", "hp": 100.0,
		"retarget": [["enemy_hazmat", {"idle": "Zombie_Idle", "attack": "Zombie_Skill", "alert": "Zombie_EnemySpotted"}],
			["enemy_bandit", {"run": "Running (1)"}]], "use": {"walk": "ANIMATION ZOMBIE"}, "walk": 1.3, "run": 4.7, "dmg": 13.0, "sight": 24.0, "reach": 1.7, "cd": 1.4, "bleed": 0.3, "radius": 0.38, "height": 1.8},
	"hazmat": {"model": "enemy_hazmat", "hp": 190.0, "walk": 1.0, "run": 2.9, "dmg": 18.0, "sight": 20.0, "reach": 1.8, "cd": 1.7, "bleed": 0.2, "rad_aura": 1.2, "radius": 0.4, "height": 1.8},
	"dog": {"model": "enemy_dog", "hp": 45.0, "walk": 2.2, "run": 7.6, "dmg": 8.0, "sight": 30.0, "reach": 1.5, "cd": 0.9, "bleed": 0.45, "radius": 0.32, "height": 0.8},
	"bandit": {"model": "enemy_bandit", "alt": "survivor_npc", "hp": 90.0, "walk": 1.5, "run": 4.4, "dmg": 9.0, "sight": 40.0, "reach": 1.6, "cd": 1.2, "bleed": 0.35,
		"ranged": true, "range": 30.0, "keep": 14.0, "rof": 0.7, "acc": 0.38, "radius": 0.38, "height": 1.8},
}

const BANDIT_GUN_ROT := Vector3(0, 90, -90)
const BANDIT_GUN_POS := Vector3(0.0, 0.08, 0.02)

var kind := "mutant"
var cfg: Dictionary
var max_hp := 100.0
var hp := 100.0
var damage := 13.0
var home := Vector3.ZERO
var state := S.WANDER
var level_ref: Node = null

var model: Node3D
var anim: AnimationPlayer
var _anims := {}
var _target := Vector3.ZERO
var _repath := 0.0
var _attack_cd := 0.0
var _attack_hit_at := -1.0
var _growl_t := 3.0
var _hurt_t := 0.0
var _stuck_t := 0.0
var _side := 1.0
var _strafe_t := 0.0
var _player: Player
var _bob := 0.0
var _muzzle: OmniLight3D
var _weapon: Node3D  # the rifle in the bandit's hand (muzzle position for flash / tracer)
var _aim_t := 0.0
var _skel: Skeleton3D
var _flinch: HitFlinch
var _ragdoll: Ragdoll
var _alert_t := 0.0
var _head_bone := -1

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


static func model_for(k: String) -> String:
	var c: Dictionary = KINDS.get(k, KINDS.mutant)
	if Assets.has_model(c.model):
		return c.model
	if c.has("alt") and Assets.has_model(c.alt):
		return c.alt
	return ""


func _ready() -> void:
	cfg = KINDS.get(kind, KINDS.mutant)
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = cfg.radius
	cap.height = maxf(cfg.height, cfg.radius * 2.0 + 0.05)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	if kind == "dog":
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.45, 0.75, 1.1)
		cs.shape = bs
		cs.position.y = 0.4
	add_child(cs)
	var mid := model_for(kind)
	model = Assets.model(mid if mid != "" else "enemy_mutant")
	add_child(model)
	anim = Assets.find_animation_player(model)
	_skel = AnimRetarget.find_skeleton(model)
	if anim and mid == cfg.model:
		for rt in cfg.get("retarget", []):
			var got := AnimRetarget.import_anims(model, anim, String(rt[0]), rt[1])
			for k in got:
				_anims[k] = got[k]
		for k in cfg.get("use", {}):
			if anim.has_animation(cfg.use[k]):
				_anims[k] = cfg.use[k]
	if anim:
		_map_animations()
	if _skel:
		_flinch = HitFlinch.attach(_skel)
		for i in _skel.get_bone_count():
			if AnimRetarget.norm(_skel.get_bone_name(i)) == "head":
				_head_bone = i
				break
	if kind == "bandit":
		_attach_weapon("weapon_rifle")
	if cfg.get("ranged", false):
		_muzzle = OmniLight3D.new()
		_muzzle.light_color = Color(1.0, 0.75, 0.4)
		_muzzle.omni_range = 7.0
		_muzzle.light_energy = 0.0
		_muzzle.position = Vector3(0.25, 1.4, 0.5)
		add_child(_muzzle)
	max_hp *= cfg.hp / 100.0
	hp = max_hp
	damage = cfg.dmg * (damage / 13.0)
	home = global_position
	_pick_wander()
	_play("idle")


func _map_animations() -> void:
	var names := anim.get_animation_list()
	var keys := {
		"idle": ["idle", "iddle", "breath", "stand"],
		"walk": ["walk"],
		"run": ["run", "sprint", "chase", "gallop"],
		"attack": ["attack", "atk", "punch", "bite", "hit_", "swipe", "slash", "skill", "fight"],
		"shoot": ["shoot", "fire", "aim"],
		"death": ["death", "die", "dying", "dead", "fallingback", "fall"],
		"hurt": ["hurt", "damage", "react"],
		"alert": ["spotted", "alert", "scream", "roar"],
	}
	# bandits: prefer the rifle animation set (we attach a rifle to the hand)
	if kind == "bandit":
		for n in names:
			var low := String(n).to_lower()
			if low.contains("t-pose") or low.contains("jump"):
				continue
			if low.contains("rifle"):
				if low.contains("aim") and not _anims.has("shoot"):
					_anims["shoot"] = n
				elif low.contains("run") and not _anims.has("run"):
					_anims["run"] = n
				elif low.contains("walk") and not _anims.has("walk"):
					_anims["walk"] = n
				elif low.contains("idle") and not _anims.has("idle"):
					_anims["idle"] = n
	for pass_i in 2:
		for k in keys:
			for n in names:
				var low := String(n).to_lower()
				if low.contains("t-pose"):
					continue
				if pass_i == 0 and k in ["walk", "run"] and not low.contains("inplace"):
					continue
				if k == "attack" and low.contains("idle"):
					continue
				for kw in keys[k]:
					if low.contains(kw) and not _anims.has(k) and not low.begins_with("rt/"):
						_anims[k] = n
	if not names.is_empty():
		var first: String = names[0]
		for k in ["idle", "walk", "run"]:
			if not _anims.has(k):
				_anims[k] = _anims.get("walk", _anims.get("idle", first))
	if not _anims.has("shoot") and _anims.has("attack"):
		_anims["shoot"] = _anims.attack
	for k in ["idle", "walk", "run", "shoot"]:
		if not _anims.has(k):
			continue
		var a := anim.get_animation(_anims[k])
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
			_strip_root_motion(a)
	for k in ["attack", "alert", "hurt"]:
		if _anims.has(k):
			var a := anim.get_animation(_anims[k])
			if a:
				a.loop_mode = Animation.LOOP_NONE
				_strip_root_motion(a)


## Puts a weapon model in the right hand bone (Mixamo-style rigs).
func _attach_weapon(id: String) -> void:
	var skel := _find_skeleton(model)
	if skel == null or not Assets.has_model(id):
		return
	var bone := -1
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i).to_lower()
		if bn.contains("righthand") and not bn.contains("thumb") and not bn.contains("index") and not bn.contains("middle") and not bn.contains("ring") and not bn.contains("pinky"):
			bone = i
			break
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = bone
	skel.add_child(att)
	var w := Assets.model(id)
	att.add_child(w)
	_weapon = w
	# skeleton scale compensation: keep the rifle ~0.9 m in world space
	# the skeleton's world scale already includes the model normalisation
	var sc := maxf(skel.global_transform.basis.get_scale().x if skel.is_inside_tree() else 1.0, 0.0001)
	w.scale = Vector3.ONE / sc
	w.rotation_degrees = BANDIT_GUN_ROT
	w.position = BANDIT_GUN_POS / sc


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null


## Locks the hip/root translation on X/Z so clips play in place (the body moves).
func _strip_root_motion(a: Animation) -> void:
	if a.has_meta("in_place"):
		return
	a.set_meta("in_place", true)
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(a.track_get_path(t)).to_lower()
		if not (path.contains("hips") or path.contains("pelvis") or path.contains("root")):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var p0: Vector3 = a.track_get_key_value(t, 0)
		for i in n:
			var p: Vector3 = a.track_get_key_value(t, i)
			a.track_set_key_value(t, i, Vector3(p0.x, p.y, p0.z))
		break


func _play(k: String, speed := 1.0, blend := 0.25) -> void:
	if anim == null or not _anims.has(k):
		return
	var n: String = _anims[k]
	if anim.current_animation != n:
		anim.play(n, blend, speed)
	else:
		anim.speed_scale = speed


## Locomotion clip with playback synced to the real ground speed (no foot sliding).
func _locomote(k: String, ref_speed: float) -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	_play(k, clampf(v / maxf(ref_speed, 0.1), 0.55, 2.4))


func _pick_wander() -> void:
	var a := randf() * TAU
	_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 14.0)
	_repath = randf_range(4.0, 9.0)


func hear(pos: Vector3, radius: float) -> void:
	if state == S.DEAD:
		return
	if global_position.distance_to(pos) < radius and state == S.WANDER:
		_spot()


## Wander -> chase, with a scream / alert clip first for the creatures.
func _spot() -> void:
	if kind != "bandit" and _anims.has("alert") and randf() < 0.75:
		state = S.ALERT
		var a := anim.get_animation(_anims.alert)
		_alert_t = minf(a.length if a else 1.2, 1.8)
		_play("alert", 1.15, 0.15)
		Audio.sfx_at("creature_growl", global_position + Vector3.UP, 4.0, 45.0, 0.1)
	else:
		state = S.CHASE
		Audio.sfx_at("creature_growl" if kind != "bandit" else "reload", global_position + Vector3.UP, 2.0, 40.0)


func is_headshot(pos: Vector3) -> bool:
	if _skel and _head_bone >= 0:
		var h := _skel.global_transform * _skel.get_bone_global_pose(_head_bone).origin
		return pos.distance_to(h + Vector3.UP * 0.06) < 0.2
	return pos.y > global_position.y + float(cfg.height) * 0.82


## Returns true when this hit killed the enemy. impulse: direction * strength of the hit.
func take_hit(amount: float, from: Vector3, hit_pos := Vector3.INF, impulse := Vector3.ZERO) -> bool:
	if state == S.DEAD:
		return false
	hp -= amount
	var push := global_position - from
	push.y = 0
	var dir := push.normalized()
	if impulse == Vector3.ZERO:
		impulse = dir * 1.5
	if hit_pos == Vector3.INF:
		hit_pos = global_position + Vector3.UP * float(cfg.height) * 0.65
	velocity += dir * (3.0 if kind == "dog" else 1.6)
	Audio.sfx_at("creature_growl" if kind != "bandit" else "melee_hit", global_position + Vector3.UP, -2.0, 30.0, 0.2)
	if _flinch:
		_flinch.kick(dir, clampf(amount / 40.0, 0.25, 1.2))
	if hp <= 0.0:
		_die(hit_pos, impulse)
		return true
	if state in [S.WANDER, S.ALERT]:
		state = S.CHASE
	elif state != S.ATTACK:
		state = S.HURT
		_hurt_t = 0.22
	if _anims.has("hurt") and amount > 25.0:
		_play("hurt", 1.2, 0.08)
	return false


func _die(hit_pos := Vector3.INF, impulse := Vector3.ZERO) -> void:
	state = S.DEAD
	State.stats["kills"] = int(State.stats.get("kills", 0)) + 1
	collision_layer = 0
	collision_mask = 1
	var vel := velocity
	velocity = Vector3.ZERO
	if _flinch:
		_flinch.active = false
	if kind == "bandit" and level_ref and level_ref.has_method("drop_loot"):
		level_ref.drop_loot(global_position, {"ammo_9mm": randi_range(4, 12), "ammo_762": randi_range(0, 14), "bandage": randi_range(0, 2), "canned_beans": randi_range(0, 1), "water_bottle": randi_range(0, 1)})
	# humanoids: physical ragdoll pushed by the killing blow
	if _skel and kind != "dog":
		_ragdoll = Ragdoll.build(_skel, self)
	# corpses go away once the player has moved on (they are never freed otherwise)
	get_tree().create_timer(45.0).timeout.connect(_try_vanish)
	if _ragdoll:
		if anim:
			anim.pause()
		_ragdoll.start(Vector3(vel.x, 0, vel.z) * 0.6, hit_pos, impulse)
		if Game.args.has("trace"):
			for i in 6:
				await get_tree().create_timer(0.2).timeout
				if is_instance_valid(self):
					_ragdoll.debug_dump("t%d" % i)
		get_tree().create_timer(8.0).timeout.connect(func() -> void:
			if is_instance_valid(self) and _ragdoll:
				_ragdoll.settle())
	elif _anims.has("death"):
		var a := anim.get_animation(_anims.death)
		if a:
			a.loop_mode = Animation.LOOP_NONE
		_play("death", 1.0, 0.1)
	else:
		if anim:
			anim.stop()
		var tw := create_tween()
		tw.tween_property(model, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return


func _try_vanish() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var p := Game.player as Node3D
	if p and is_instance_valid(p) and p.global_position.distance_to(global_position) < 22.0:
		get_tree().create_timer(5.0).timeout.connect(_try_vanish)
		return
	queue_free()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if state == S.DEAD:
		if _ragdoll == null:
			velocity.x = move_toward(velocity.x, 0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0, delta * 8.0)
			move_and_slide()
		return
	if _player == null:
		_player = Game.player as Player
	if _player == null:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if _muzzle:
		_muzzle.light_energy = maxf(_muzzle.light_energy - delta * 40.0, 0.0)
	var to_player := _player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()
	if cfg.has("rad_aura") and dist < 5.0 and level_ref:
		level_ref.extra_rad += float(cfg.rad_aura) * (1.0 - dist / 5.0)
	match state:
		S.WANDER:
			_repath -= delta
			if _repath <= 0.0 or global_position.distance_to(_target) < 1.0:
				_pick_wander()
			_move_to(_target, cfg.walk, delta)
			_locomote("walk", float(cfg.walk))
			if (dist < cfg.sight and _can_see()) or dist < 5.0:
				_spot()
		S.ALERT:
			velocity.x = move_toward(velocity.x, 0, delta * 10.0)
			velocity.z = move_toward(velocity.z, 0, delta * 10.0)
			_face(to_player, delta)
			_alert_t -= delta
			if _alert_t <= 0.0 or dist < cfg.reach * 1.5:
				state = S.CHASE
		S.CHASE:
			if cfg.get("ranged", false):
				_ranged(delta, to_player, dist)
			else:
				_move_to(_player.global_position, cfg.run, delta)
				if _anims.get("run") == _anims.get("walk"):
					_locomote("run", float(cfg.walk) * (1.0 if kind == "dog" else 1.6))
				else:
					_locomote("run", float(cfg.run) * 0.92)
				_growl_t -= delta
				if _growl_t <= 0.0:
					_growl_t = randf_range(3.0, 6.0)
					Audio.sfx_at("creature_growl", global_position + Vector3.UP, 0.0, 35.0, 0.15 if kind != "dog" else 0.4)
				if dist < cfg.reach:
					state = S.ATTACK
			if dist > cfg.sight * 1.8:
				state = S.WANDER
				home = global_position
		S.ATTACK:
			velocity.x = move_toward(velocity.x, 0, delta * 10.0)
			velocity.z = move_toward(velocity.z, 0, delta * 10.0)
			_face(to_player, delta)
			if _attack_cd <= 0.0:
				_attack_cd = cfg.cd
				_attack_hit_at = 0.35 if kind == "dog" else 0.45
				if anim and _anims.has("attack") and anim.current_animation == _anims.attack:
					anim.seek(0.0, true)
				_play("attack", 1.25, 0.12)
				Audio.sfx_at("creature_attack" if kind != "bandit" else "melee_swing", global_position + Vector3.UP, 0.0, 30.0, 0.3 if kind == "dog" else 0.1)
			if _attack_hit_at > 0.0:
				_attack_hit_at -= delta
				if _attack_hit_at <= 0.0 and dist < cfg.reach + 0.7:
					_player.take_hit(damage, global_position, cfg.bleed)
			if dist > cfg.reach + 0.8 and _attack_cd < cfg.cd * 0.6:
				state = S.CHASE
		S.HURT:
			velocity.x = move_toward(velocity.x, 0, delta * 6.0)
			velocity.z = move_toward(velocity.z, 0, delta * 6.0)
			_hurt_t -= delta
			if _hurt_t <= 0.0:
				state = S.CHASE
	move_and_slide()
	if anim == null:
		_bob += delta * Vector2(velocity.x, velocity.z).length() * 3.0
		model.position.y = absf(sin(_bob)) * 0.06


func _ranged(delta: float, to_player: Vector3, dist: float) -> void:
	var keep: float = cfg.keep
	var see := _can_see()
	var dir := to_player.normalized()
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.8)
		_side = -_side if randf() < 0.6 else _side
	var move := Vector3.ZERO
	if dist > keep + 5.0 or not see:
		move = dir
	elif dist < keep - 5.0:
		move = -dir
	else:
		move = dir.rotated(Vector3.UP, PI * 0.5 * _side) * 0.7
	var spd: float = cfg.run if (dist > keep + 8.0 or not see) else cfg.walk * 1.4
	velocity.x = lerpf(velocity.x, move.x * spd, minf(delta * 5.0, 1.0))
	velocity.z = lerpf(velocity.z, move.z * spd, minf(delta * 5.0, 1.0))
	_face(dir, delta)
	if spd > cfg.walk * 1.5:
		_locomote("run", float(cfg.run) * 0.9)
	else:
		_locomote("walk", float(cfg.walk))
	if dist < cfg.reach:
		state = S.ATTACK
		return
	if see and dist < cfg.range:
		_aim_t += delta
		if _attack_cd <= 0.0 and _aim_t > 0.7:
			_attack_cd = cfg.rof * randf_range(0.8, 1.8)
			_shoot(dist)
	else:
		_aim_t = 0.0


func _shoot(dist: float) -> void:
	_play("shoot", 1.0)
	var chest := _player.global_position + Vector3.UP * 1.3
	var muzzle := _muzzle_pos(chest)
	var scene := get_tree().current_scene
	# flash at the real muzzle, a tracer along the shot and the recoil through the spine
	if _muzzle:
		_muzzle.global_position = muzzle
		_muzzle.light_energy = 5.0
	FX.muzzle_flash(scene, muzzle, 0.22)
	if _flinch:
		_flinch.kick((global_position - _player.global_position).normalized(), 0.3)
	Audio.sfx_at("gunshot_rifle", muzzle, 2.0, 110.0, 0.08)
	var hit_chance: float = cfg.acc * clampf(1.15 - dist / cfg.range, 0.15, 1.0)
	var pv := Vector2(_player.velocity.x, _player.velocity.z).length()
	if pv > 4.0:
		hit_chance *= 0.55
	if _player.crouching:
		hit_chance *= 0.65
	if randf() < hit_chance:
		FX.tracer(scene, muzzle, chest + Vector3(randf_range(-0.15, 0.15), randf_range(-0.2, 0.1), randf_range(-0.15, 0.15)))
		_player.take_hit(damage * randf_range(0.8, 1.25), global_position, cfg.bleed)
	else:
		var miss := _player.global_position + Vector3(randf_range(-1.5, 1.5), randf_range(0.2, 2.0), randf_range(-1.5, 1.5))
		FX.tracer(scene, muzzle, miss + (miss - muzzle).normalized() * 6.0)
		Audio.sfx_at("metal_impact", miss, -6.0, 20.0, 0.3)


## The rifle's muzzle: 0.55 m from the trigger hand toward the target (world space).
func _muzzle_pos(toward: Vector3) -> Vector3:
	var hand := global_position + Vector3.UP * 1.3
	if _weapon and is_instance_valid(_weapon) and _weapon.is_inside_tree():
		hand = _weapon.global_position
	var dir := (toward - hand).normalized()
	return hand + dir * 0.55


func _can_see() -> bool:
	if _player == null:
		return false
	var space := get_world_3d().direct_space_state
	var eye: float = 0.6 if kind == "dog" else 1.6
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * eye, _player.global_position + Vector3.UP * 1.5, 1)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func _move_to(p: Vector3, speed: float, delta: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.2:
		velocity.x = 0
		velocity.z = 0
		return
	var dir := d.normalized()
	if is_on_wall():
		_stuck_t += delta
		if _stuck_t > 0.3:
			dir = dir.rotated(Vector3.UP, _side * PI * 0.5)
		if _stuck_t > 1.6:
			_stuck_t = 0.0
			_side = -_side
	else:
		_stuck_t = maxf(_stuck_t - delta, 0.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, minf(delta * 6.0, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, minf(delta * 6.0, 1.0))
	_face(dir, delta)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(delta * 8.0, 1.0))
