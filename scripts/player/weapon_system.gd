class_name WeaponSystem
extends Node3D
## First-person weapons with animated arm rigs.
##
## Every gun is an authored first-person rig (arms + weapon + camera bone, Cransh FPS
## packs, CC BY) driven by an AnimationTree: idle/walk/run locomotion, fire one-shot,
## reload (fast / empty), draw. On top of that sits a procedural layer: sway, bob,
## breathing, spring recoil, sprint pose, wall avoidance, equip lower/raise and melee
## swings. ADS alignment and the muzzle / ejection points are derived from the weapon
## geometry when a rig is built, so the sights always line up with the screen centre.
## The viewmodel keeps its own field of view (camera-space Z squash), independent of
## the FOV setting, which also keeps the arms out of walls.

## Arm length used to bring every rig to the same real-world size (m).
const FOREARM := 0.27
## Viewmodel field of view (vertical degrees).
const VM_FOV := 60.0

const RIGS := {
	"pistol": {"model": "fps_pistol", "body": "PBody", "relief": 0.42, "rear": [0.0, 0.35], "vm_fov": 64.0, "slide_sights": true,
		"offset": Vector3(0.04, -0.005, 0.02), "tilt": Vector3(0, 3, 0),
		"anims": {"idle": "Armature|FPS_Pistol_Idle", "walk": "Armature|FPS_Pistol_Walk", "fire": "Armature|FPS_Pistol_Fire",
			"reload": "Armature|FPS_Pistol_Reload_easy", "reload_empty": "Armature|FPS_Pistol_Reload_full"}},
	"rifle": {"model": "fps_rifle", "body": "PBody", "relief": 0.16, "rear": [0.25, 0.62],
		"offset": Vector3(0.075, -0.04, 0.03), "tilt": Vector3(0, 4, 0),
		"anims": {"idle": "Rig|AK_Idle", "draw": "Rig|AK_Draw", "walk": "Rig|AK_Walk", "run": "Rig|AK_Run", "fire": "Rig|AK_Shot",
			"reload": "Rig|AK_Reload", "reload_empty": "Rig|AK_Reload_full"}},
	"shotgun": {"model": "fps_shotgun", "body": "Saiga", "relief": 0.17, "rear": [0.25, 0.62],
		"offset": Vector3(0.06, -0.035, 0.03), "tilt": Vector3(0, 3, 0),
		"anims": {"idle": "Rig|Saiga_Idle", "walk": "Rig|Saiga_Walk", "run": "Rig|Saiga_Run", "fire": "Rig|Saiga_Fire",
			"reload": "Rig|Saiga_Reload_Fast", "reload_empty": "Rig|Saiga_Reload_Full"}},
	# melee: the pistol rig's right arm (gun hidden, left arm folded away) with the axe in the fist
	"axe": {"model": "fps_pistol", "body": "PBody", "melee": true, "attach": "weapon_axe",
		"collapse": ["Arm_L", "IK_Hand_Cntrl_L", "IK_PoleTrgt_L"],
		"offset": Vector3.ZERO, "tilt": Vector3.ZERO,
		"anims": {"idle": "Armature|FPS_Pistol_Idle", "walk": "Armature|FPS_Pistol_Walk"}},
	# empty hands (bunker, surface without a weapon): the same arm, lowered to a relaxed
	# pose; it reaches out when the player searches or uses something
	"hands": {"model": "fps_pistol", "body": "PBody", "hands": true,
		"collapse": ["Arm_L", "IK_Hand_Cntrl_L", "IK_PoleTrgt_L"],
		"offset": Vector3.ZERO, "tilt": Vector3(-10, 14, -16),
		"anims": {"idle": "Armature|FPS_Pistol_Idle", "walk": "Armature|FPS_Pistol_Walk"}},
}

## Interaction reach: 0..1 goal set by the player each tick (held E), or a short pulse.
var reach_goal := 0.0
var _reach := 0.0
var _reach_pulse := 0.0


func reach_pulse(t := 0.35) -> void:
	_reach_pulse = t


class ViewRig extends RefCounted:
	var id := ""
	var cfg: Dictionary
	var anchor: Node3D
	var root: Node3D
	var skel: Skeleton3D
	var tree: AnimationTree
	var cam_bone := -1
	var body_bone := -1
	var S := Transform3D()          # skeleton space -> rig root space
	var rest_cam := Transform3D()   # authored camera frame at idle (root space)
	var muzzle := Vector3.ZERO      # body-bone space (skeleton units)
	var eject := Vector3.ZERO
	var ads_xf := Transform3D()     # holder-space transform that lines the sights up
	var has := {}                   # anim key -> true
	var length := 0.6               # weapon length (m)
	var collapse: Array[int] = []    # bones scaled to zero (hidden limbs)
	var melee_offset := Vector3.ZERO
	var melee_pivot := Vector3(0.2, -0.22, 0.08)
	var axe: Node3D                  # the melee model (child of the hand attachment)
	var axe_desired := Transform3D() # its rest pose in (pre-offset) holder space
	var axe_hand0 := Transform3D()   # the hand bone at build time, holder space
	var palm := Vector3.ZERO         # grip point, pre-offset holder space
	var rest_xf := Transform3D()     # melee rest lean about the fist (view space)
	var fire_len := 0.3
	var reload_len := {}            # key -> seconds


signal fired(id: String)

var player: Player
var cam: Camera3D
var current := ""
var defn: Dictionary = {}
var ads := 0.0
var reloading := 0.0
var spread_now := 0.0
## extra camera rotation coming from the rig's animated camera bone (applied by Player)
var cam_anim := Vector3.ZERO

var squash: Node3D
var holder: Node3D
var rigs := {}  # id -> ViewRig
var flash_mesh: MeshInstance3D
var flash_light: OmniLight3D

var _cd := 0.0
var _reload_total := 0.0
var _reload_done := false
var _equip := 1.0  # 0 = lowered, 1 = raised
var _switching_to := "__none"
var _r_pos := Vector3.ZERO
var _r_vel := Vector3.ZERO
var _r_rot := Vector3.ZERO
var _r_rvel := Vector3.ZERO
var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _bob_t := 0.0
var _breath := 0.0
var _swing := -1.0
var _swing_hit := false
var _swing_side := false   # second swing of a combo (flat sweep)
var _since_swing := 99.0   # seconds since the last swing ended
var _hitstop := 0.0
var _burst := 0
var _burst_t := 0.0
var _wall := 0.0
var _flash_t := 0.0
var _sprint_k := 0.0
var _move_k := 0.0
var _sprinting := false
var _speed := 0.0
var _on_floor := true


func setup(p: Player) -> void:
	player = p
	cam = p.cam
	squash = Node3D.new()
	squash.name = "ViewmodelFov"
	add_child(squash)
	holder = Node3D.new()
	squash.add_child(holder)
	flash_mesh = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.2, 0.2)
	flash_mesh.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_texture = FX.flash_texture()
	fm.albedo_color = Color(1.0, 0.85, 0.6)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.no_depth_test = true
	flash_mesh.material_override = fm
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.visible = false
	add_child(flash_mesh)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.72, 0.38)
	flash_light.omni_range = 7.0
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	add_child(flash_light)
	_switching_to = "hands"
	if State.flags.has("pistol_mag"):
		State.flags["mag_pistol"] = State.flags.pistol_mag
		State.flags.erase("pistol_mag")


func mag(id := "") -> int:
	return int(State.flags.get("mag_" + (current if id == "" else id), 0))


func set_mag(v: int) -> void:
	State.flags["mag_" + current] = v


func reserve() -> int:
	return State.count(defn.get("ammo", "")) if defn.get("type", "") == "gun" else 0


func is_gun() -> bool:
	return defn.get("type", "") == "gun"


# --------------------------------------------------------------------------
# Equip / switch
# --------------------------------------------------------------------------

func switch(id: String) -> void:
	if id != "" and id != "hands" and State.count(id) <= 0:
		HUD.toast("Nu ai %s." % ItemDB.item_name(id).to_lower(), "warn")
		return
	if id == current and _switching_to == "__none":
		return
	_switching_to = id
	reloading = 0.0
	_swing = -1.0


func best_weapon() -> String:
	for id in ["rifle", "shotgun", "pistol", "axe"]:
		if State.count(id) > 0:
			return id
	return "hands"


func _apply_switch() -> void:
	var id := _switching_to
	_switching_to = "__none"
	if id == "__none" or (id != "" and id != "hands" and not ItemDB.WEAPONS.has(id)):
		return
	for k in rigs:
		var r: ViewRig = rigs[k]
		r.anchor.visible = false
		if r.tree:
			r.tree.active = false
	current = id
	defn = ItemDB.WEAPONS.get(id, {})
	if id == "":
		return
	if not rigs.has(id):
		rigs[id] = _build_rig(id)
	var rig: ViewRig = rigs[id]
	rig.anchor.visible = true
	if rig.tree:
		rig.tree.active = true
		if rig.has.has("draw"):
			rig.tree.set("parameters/draw/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if id != "hands":
		Audio.sfx("weapon_equip", -8.0, 0.05)


# --------------------------------------------------------------------------
# Rig construction
# --------------------------------------------------------------------------

func _find_bone(skel: Skeleton3D, prefix: String) -> int:
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		if n.begins_with(prefix) and not n.to_lower().contains("end"):
			return i
	return -1


func _build_rig(id: String) -> ViewRig:
	var cfg: Dictionary = RIGS.get(id, {})
	var r := ViewRig.new()
	r.id = id
	r.cfg = cfg
	r.anchor = Node3D.new()
	r.anchor.name = "Rig_" + id
	holder.add_child(r.anchor)
	r.root = Assets.model(cfg.get("model", ""))
	r.anchor.add_child(r.root)
	Assets.set_shadows(r.root, false)
	r.skel = _find_skel(r.root)
	if r.skel == null:
		return r
	r.cam_bone = _find_bone(r.skel, "Head_Cam")
	r.body_bone = _find_bone(r.skel, String(cfg.get("body", "PBody")))
	# skeleton -> rig root, from the local chain (exact, independent of the parents)
	var chain := Transform3D()
	var n: Node = r.skel
	while n and n != r.root:
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	r.S = chain
	_make_tree(r)
	r.tree.advance(0.0)
	# real-world size from the forearm length
	var fa := _bone_pos(r, "Forearm_R")
	var hand := _bone_pos(r, "Hand_R")
	var len_units := fa.distance_to(hand)
	var s := FOREARM / len_units if len_units > 0.0001 else 1.0
	r.anchor.scale = Vector3.ONE * s
	r.rest_cam = _cam_frame(r)
	r.root.transform = r.rest_cam.affine_inverse()
	for bn in cfg.get("collapse", []):
		var cb := _find_bone(r.skel, String(bn))
		if cb >= 0:
			r.collapse.append(cb)
	if Game.args.has("vmstrip"):
		_debug_strip(r.root, String(Game.args.vmstrip))
	if cfg.get("melee", false):
		_hide_weapon_meshes(r)
		_attach_melee(r, String(cfg.get("attach", "weapon_axe")))
	elif cfg.get("hands", false):
		_hide_weapon_meshes(r)
		_place_hands(r)
	else:
		_probe_geometry(r)
	return r


## Where the empty fist rests in the view (holder space).
const HAND_REST := Vector3(0.19, -0.165, -0.38)


## Empty hands: put the fist of the pistol rig at HAND_REST, whatever the model's own
## placement (the weapon probe that normally positions a rig is skipped).
func _place_hands(r: ViewRig) -> void:
	var hb := _find_bone(r.skel, "Hand_R")
	if hb < 0:
		return
	var to_h := r.anchor.transform * r.root.transform * r.S
	var grip := _pistol_grip(r, to_h)
	var c: Vector3 = grip.get("center", (to_h * r.skel.get_bone_global_pose(hb)).origin)
	var tilt := Basis.from_euler((r.cfg.get("tilt", Vector3.ZERO) as Vector3) * (PI / 180.0))
	r.melee_offset = HAND_REST - tilt * c - (r.cfg.get("offset", Vector3.ZERO) as Vector3)


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skel(c)
		if s:
			return s
	return null


func _bone_pos(r: ViewRig, prefix: String) -> Vector3:
	var b := _find_bone(r.skel, prefix)
	if b < 0:
		return Vector3.ZERO
	return (r.S * r.skel.get_bone_global_pose(b)).origin


## Authored camera frame in rig-root space (camera looks along the bone's +Z).
func _cam_frame(r: ViewRig) -> Transform3D:
	if r.cam_bone < 0:
		return Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var c := r.S * r.skel.get_bone_global_pose(r.cam_bone)
	return Transform3D(c.basis.orthonormalized() * Basis(Vector3.UP, PI), c.origin)


func _make_tree(r: ViewRig) -> void:
	var ap := Assets.find_animation_player(r.root)
	var names: Dictionary = r.cfg.get("anims", {})
	var bt := AnimationNodeBlendTree.new()
	var avail := {}
	for k in names:
		if ap and ap.has_animation(names[k]):
			avail[k] = names[k]
			r.has[k] = true
	var idle: String = avail.get("idle", "")
	var walk: String = avail.get("walk", idle)
	var run: String = avail.get("run", walk)
	for k in ["idle", "walk", "run"]:
		var a: Animation = ap.get_animation(avail.get(k, idle)) if ap and avail.has(k) else null
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	# locomotion blend space: 0 idle, 1 walk, 2 run
	# (a blend-tree output can feed only one input, so the fire branch gets its own copy)
	for suffix in ["", "_b"]:
		var bs := AnimationNodeBlendSpace1D.new()
		bs.min_space = 0.0
		bs.max_space = 2.0
		for p in [[idle, 0.0, "idle"], [walk, 1.0, "walk"], [run, 2.0, "run"]]:
			var an := AnimationNodeAnimation.new()
			an.animation = p[0]
			bs.add_blend_point(an, p[1], -1, p[2])
		bt.add_node("loco" + suffix, bs, Vector2(0, 0))
		bt.add_node("loco_speed" + suffix, AnimationNodeTimeScale.new(), Vector2(200, 0))
		bt.connect_node("loco_speed" + suffix, 0, "loco" + suffix)
	var last := "loco_speed"
	if avail.has("fire"):
		var fa := AnimationNodeAnimation.new()
		fa.animation = avail.fire
		bt.add_node("fire_anim", fa, Vector2(200, 200))
		var fts := AnimationNodeTimeScale.new()
		bt.add_node("fire_speed", fts, Vector2(300, 200))
		bt.connect_node("fire_speed", 0, "fire_anim")
		var os := AnimationNodeOneShot.new()
		os.fadein_time = 0.025
		os.fadeout_time = 0.12
		bt.add_node("fire", os, Vector2(400, 0))
		bt.connect_node("fire", 0, "loco_speed_b")
		bt.connect_node("fire", 1, "fire_speed")
		var mix := AnimationNodeBlend2.new()
		bt.add_node("fire_mix", mix, Vector2(600, 0))
		bt.connect_node("fire_mix", 0, last)
		bt.connect_node("fire_mix", 1, "fire")
		last = "fire_mix"
		var fanim := ap.get_animation(avail.fire)
		r.fire_len = fanim.length if fanim else 0.3
	if avail.has("reload"):
		var ra := AnimationNodeAnimation.new()
		ra.animation = avail.reload
		bt.add_node("reload_anim", ra, Vector2(600, 200))
		var rts := AnimationNodeTimeScale.new()
		bt.add_node("reload_speed", rts, Vector2(700, 200))
		bt.connect_node("reload_speed", 0, "reload_anim")
		var os2 := AnimationNodeOneShot.new()
		os2.fadein_time = 0.18
		os2.fadeout_time = 0.25
		bt.add_node("reload", os2, Vector2(800, 0))
		bt.connect_node("reload", 0, last)
		bt.connect_node("reload", 1, "reload_speed")
		last = "reload"
		for k in ["reload", "reload_empty"]:
			if avail.has(k):
				var a := ap.get_animation(avail[k])
				r.reload_len[k] = a.length if a else 2.0
	if avail.has("draw"):
		var da := AnimationNodeAnimation.new()
		da.animation = avail.draw
		bt.add_node("draw_anim", da, Vector2(800, 200))
		var os3 := AnimationNodeOneShot.new()
		os3.fadein_time = 0.0
		os3.fadeout_time = 0.15
		bt.add_node("draw", os3, Vector2(1000, 0))
		bt.connect_node("draw", 0, last)
		bt.connect_node("draw", 1, "draw_anim")
		last = "draw"
	bt.connect_node("output", 0, last)
	var tree := AnimationTree.new()
	tree.tree_root = bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	r.root.add_child(tree)
	if ap:
		tree.anim_player = tree.get_path_to(ap)
		ap.active = false
	tree.root_node = tree.get_path_to(r.root)
	for suffix in ["", "_b"]:
		tree.set("parameters/loco%s/blend_position" % suffix, 0.0)
		tree.set("parameters/loco_speed%s/scale" % suffix, 1.0)
	if avail.has("fire"):
		tree.set("parameters/fire_mix/blend_amount", 1.0)
		tree.set("parameters/fire_speed/scale", 1.0)
	if avail.has("reload"):
		tree.set("parameters/reload_speed/scale", 1.0)
	tree.active = true
	r.tree = tree


## Meshes skinned mostly to arm bones are the arms; everything else is the weapon.
func _is_arm_bone(n: String) -> bool:
	return n.begins_with("Arm_") or n.begins_with("UpArm") or n.begins_with("Forearm") or n.begins_with("Hand_") \
		or n.begins_with("Bone_") or n.begins_with("BoneTwist") or n.begins_with("IK_")


func _mesh_points(r: ViewRig, mi: MeshInstance3D, max_pts := 3500) -> Array:
	# -> [[bone, point_in_skeleton_space], ...] using each vertex's dominant bone
	var out: Array = []
	var skin := mi.skin
	if mi.mesh == null or skin == null:
		return out
	var bind_bone := PackedInt32Array()
	for b in skin.get_bind_count():
		var bb := skin.get_bind_bone(b)
		if bb < 0:
			bb = r.skel.find_bone(skin.get_bind_name(b))
		bind_bone.append(bb)
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if verts.is_empty() or arr[Mesh.ARRAY_BONES] == null:
			continue
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		var step := maxi(1, verts.size() / max_pts)
		for vi in range(0, verts.size(), step):
			var best := 0
			var bw := -1.0
			for k in per:
				var w := weights[vi * per + k]
				if w > bw:
					bw = w
					best = bones[vi * per + k]
			if best < 0 or best >= bind_bone.size():
				continue
			var bone := bind_bone[best]
			if bone < 0:
				continue
			var p: Vector3 = r.skel.get_bone_global_pose(bone) * (skin.get_bind_pose(best) * verts[vi])
			out.append([bone, p])
	return out


func _weapon_meshes(r: ViewRig) -> Array:
	var res: Array = []
	for c in r.skel.get_children():
		if not (c is MeshInstance3D):
			continue
		var pts := _mesh_points(r, c, 400)
		var arm := 0
		for e in pts:
			if _is_arm_bone(r.skel.get_bone_name(int(e[0]))):
				arm += 1
		if pts.size() > 0 and float(arm) / pts.size() < 0.5:
			res.append(c)
	return res


func _hide_weapon_meshes(r: ViewRig) -> void:
	for mi in _weapon_meshes(r):
		(mi as MeshInstance3D).visible = false


## Muzzle, ejection port and the iron-sight line, from the weapon's own vertices.
func _probe_geometry(r: ViewRig) -> void:
	var to_holder := r.anchor.transform * r.root.transform * r.S   # skeleton -> holder
	var pts: Array[Vector3] = []
	var body_votes := {}
	var all: Array = []
	for mi in _weapon_meshes(r):
		for e in _mesh_points(r, mi):
			all.append(e)
			body_votes[int(e[0])] = int(body_votes.get(int(e[0]), 0)) + 1
	if r.body_bone < 0:
		var best := -1
		for b in body_votes:
			if best < 0 or int(body_votes[b]) > int(body_votes[best]):
				best = int(b)
		r.body_bone = best
	if r.body_bone < 0 or all.is_empty():
		return
	for e in all:
		if int(e[0]) == r.body_bone:
			pts.append(to_holder * (e[1] as Vector3))
	if pts.size() < 20:
		for e in all:
			pts.append(to_holder * (e[1] as Vector3))
	var body_xf := to_holder * r.skel.get_bone_global_pose(r.body_bone)
	# barrel axis = body-bone axis closest to the view direction; up = closest to +Y
	var axes := [body_xf.basis.x.normalized(), body_xf.basis.y.normalized(), body_xf.basis.z.normalized()]
	var fwd := Vector3.FORWARD
	var best_d := -1.0
	for a in axes:
		var d := absf((a as Vector3).dot(Vector3.FORWARD))
		if d > best_d:
			best_d = d
			fwd = a if (a as Vector3).dot(Vector3.FORWARD) > 0.0 else -a
	var up := Vector3.UP - fwd * Vector3.UP.dot(fwd)
	var best_u := -1.0
	for a in axes:
		var av: Vector3 = a
		if absf(av.dot(fwd)) > 0.7:
			continue
		var d := absf(av.dot(Vector3.UP))
		if d > best_u:
			best_u = d
			up = av if av.dot(Vector3.UP) > 0.0 else -av
	up = (up - fwd * up.dot(fwd)).normalized()
	var right := up.cross(-fwd)
	var tmin := INF
	var tmax := -INF
	for p in pts:
		var t := p.dot(fwd)
		tmin = minf(tmin, t)
		tmax = maxf(tmax, t)
	var length := tmax - tmin
	r.length = length
	# muzzle: centre of the front-most slice
	var acc := Vector3.ZERO
	var n := 0
	for p in pts:
		if p.dot(fwd) > tmax - length * 0.025:
			acc += p
			n += 1
	var muzzle := acc / maxf(n, 1)
	# sights: highest point in the front slice and in the rear window
	var rear_w: Array = r.cfg.get("rear", [0.25, 0.62])
	var front := Vector3.ZERO
	var rear := Vector3.ZERO
	var fh := -INF
	var rh := -INF
	var ej := Vector3.ZERO
	var eh := -INF
	for p in pts:
		var t := (p.dot(fwd) - tmin) / maxf(length, 0.001)
		var h := p.dot(up)
		if t > 0.86 and h > fh:
			fh = h
			front = p
		if not r.cfg.get("slide_sights", false) and t >= float(rear_w[0]) and t <= float(rear_w[1]) and h > rh:
			rh = h
			rear = p
		if t > 0.35 and t < 0.6 and p.dot(right) > eh:
			eh = p.dot(right)
			ej = p
	if r.cfg.get("slide_sights", false):
		# pistols: both sights sit on the slide (everything above the bore line); the rear
		# sight is the highest point of the slide's back end, the front one of its front end
		var bore_h := muzzle.dot(up)
		var smin := INF
		var smax := -INF
		for p in pts:
			if p.dot(up) > bore_h + 0.004:
				smin = minf(smin, p.dot(fwd))
				smax = maxf(smax, p.dot(fwd))
		var slen := maxf(smax - smin, 0.01)
		fh = -INF
		for p in pts:
			var h := p.dot(up)
			if h <= bore_h + 0.004:
				continue
			var ts := (p.dot(fwd) - smin) / slen
			if ts < 0.22 and h > rh:
				rh = h
				rear = p
			if ts > 0.85 and h > fh:
				fh = h
				front = p
	# the sight line runs through both sight tops; centre it laterally on the bore
	var bore_side := muzzle.dot(right)
	front += right * (bore_side - front.dot(right))
	rear += right * (bore_side - rear.dot(right))
	var sd := (front - rear).normalized()
	var su := (up - sd * up.dot(sd)).normalized()
	var src := Basis(su.cross(-sd), su, -sd)
	var rot := src.inverse()
	var relief: float = r.cfg.get("relief", 0.16)
	var off := Vector3(0, 0, -relief) - rot * rear
	r.ads_xf = Transform3D(rot, off)
	var tw: float = r.cfg.get("ads_translate", 1.0)
	if tw < 1.0:
		# arms that start at the eye would cross the view if the rig moved up fully:
		# move part of the way, then pivot about the eye so the rear sight is centred
		var x := Transform3D(rot, off * tw)
		var r1 := (x * rear).normalized()
		var axis := r1.cross(Vector3.FORWARD)
		if axis.length() > 0.0001:
			var ang := r1.angle_to(Vector3.FORWARD)
			x = Transform3D(Basis(axis.normalized(), ang), Vector3.ZERO) * x
		r.ads_xf = x
	var inv_body := body_xf.affine_inverse()
	r.muzzle = inv_body * (muzzle + fwd * 0.01)
	r.eject = inv_body * (ej + up * 0.01)
	if Game.args.has("trace"):
		print("[weapon] %s len=%.2f muzzle=%s front=%s rear=%s body=%s" % [r.id, length, muzzle, front, rear, r.skel.get_bone_name(r.body_bone)])
	if Game.args.has("sightdbg"):
		# debug: markers on the detected sights, riding on the weapon bone
		var att := BoneAttachment3D.new()
		r.skel.add_child(att)
		att.bone_name = r.skel.get_bone_name(r.body_bone)
		var to_bone := (to_holder * r.skel.get_bone_global_pose(r.body_bone)).affine_inverse()
		for e in [[front, Color.GREEN], [rear, Color.MAGENTA], [muzzle, Color.YELLOW]]:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.004 / r.anchor.scale.x
			sm.height = sm.radius * 2.0
			mi.mesh = sm
			var mm := StandardMaterial3D.new()
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.no_depth_test = true
			mm.albedo_color = e[1]
			mi.material_override = mm
			att.add_child(mi)
			mi.position = r.skel.get_bone_global_pose(r.body_bone).affine_inverse() * (r.S.affine_inverse() * (r.root.transform.affine_inverse() * (r.anchor.transform.affine_inverse() * (e[0] as Vector3))))


## Melee: the axe handle runs exactly through the fist of the pistol rig — along the axis
## of the pistol grip the fingers are posed around — with the blade edge forward. At rest
## the arm leans the axe toward the centre of the view; a swing is the arm rotating about
## the shoulder while the wrist cocks the axe back over it and snaps it through.
const AXE_GRIP := Vector3(0.24, -0.2, -0.45)    # where the fist sits in the view (holder space)
const AXE_GRIP_Z := -0.36                         # grip point along the model's long axis (head end +Z, butt at -0.58)
## rest pose: handle leaning up-left toward the centre, edge facing forward
const REST_SHAFT := Vector3(-0.2, 0.75, -0.6)
const REST_EDGE := Vector3(-0.3, 0.0, -1.0)
## [time, fist position, handle direction (head end), blade edge direction] in view space:
## wind-up over the right shoulder, diagonal chop through the centre, follow-through, recover
const SWING_KEYS := [
	[0.0, AXE_GRIP, REST_SHAFT, REST_EDGE],
	[0.12, Vector3(0.3, -0.01, -0.42), Vector3(0.3, 0.85, 0.3), Vector3(0.1, 0.2, 1.0)],
	[0.19, Vector3(0.2, -0.06, -0.5), Vector3(-0.2, 0.75, -0.65), Vector3(-0.25, -0.35, -0.9)],
	[0.25, Vector3(0.13, -0.2, -0.52), Vector3(-0.65, 0.05, -0.75), Vector3(0.0, -1.0, -0.15)],
	[0.34, Vector3(0.11, -0.29, -0.48), Vector3(-0.6, -0.45, -0.65), Vector3(0.1, -0.7, 0.6)],
	[0.62, AXE_GRIP, REST_SHAFT, REST_EDGE],
]
## second swing of a combo: pulled back to the right, flat sweep through the centre
const SWING_KEYS_SIDE := [
	[0.0, AXE_GRIP, REST_SHAFT, REST_EDGE],
	[0.11, Vector3(0.38, -0.06, -0.36), Vector3(0.8, 0.45, 0.25), Vector3(0.05, 0.2, -1.0)],
	[0.19, Vector3(0.26, -0.12, -0.5), Vector3(0.2, 0.25, -0.95), Vector3(-1.0, 0.0, -0.15)],
	[0.25, Vector3(0.14, -0.16, -0.52), Vector3(-0.45, 0.15, -0.88), Vector3(-0.9, -0.05, 0.45)],
	[0.34, Vector3(0.06, -0.2, -0.46), Vector3(-0.9, 0.0, -0.3), Vector3(-0.3, -0.1, 0.95)],
	[0.62, AXE_GRIP, REST_SHAFT, REST_EDGE],
]
const SWING_HIT := 0.25
const SWING_END := 0.62
const COMBO_WINDOW := 0.45   # seconds after a swing in which the next one alternates
const HITSTOP := 0.07        # the axe bites: the swing nearly stops for a moment on impact


## Orthonormal frame of the axe: z = handle (head end), x = blade edge.
static func _frame(shaft: Vector3, edge: Vector3) -> Basis:
	var sh := shaft.normalized()
	var ed := (edge - sh * edge.dot(sh)).normalized()
	return Basis(ed, sh.cross(ed), sh)


## Fist position and axe frame (view space) at time `t` of the swing.
func _swing_pose(t: float) -> Array:
	var keys: Array = SWING_KEYS_SIDE if _swing_side else SWING_KEYS
	var k := 0
	while k < keys.size() - 2 and t > float(keys[k + 1][0]):
		k += 1
	var a: Array = keys[k]
	var b: Array = keys[k + 1]
	var f := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var qa := _frame(a[2], a[3]).get_rotation_quaternion()
	var qb := _frame(b[2], b[3]).get_rotation_quaternion()
	return [(a[1] as Vector3).lerp(b[1], f), Basis(qa.slerp(qb, f))]


## Barrel / up axes of a weapon from its body bone (holder space).
func _weapon_axes(body_xf: Transform3D) -> Array:
	var axes := [body_xf.basis.x.normalized(), body_xf.basis.y.normalized(), body_xf.basis.z.normalized()]
	var fwd := Vector3.FORWARD
	var best_d := -1.0
	for ax in axes:
		var d := absf((ax as Vector3).dot(Vector3.FORWARD))
		if d > best_d:
			best_d = d
			fwd = ax if (ax as Vector3).dot(Vector3.FORWARD) > 0.0 else -ax
	var up := Vector3.UP
	var best_u := -1.0
	for ax in axes:
		var av: Vector3 = ax
		if absf(av.dot(fwd)) > 0.7:
			continue
		var d := absf(av.dot(Vector3.UP))
		if d > best_u:
			best_u = d
			up = av if av.dot(Vector3.UP) > 0.0 else -av
	return [fwd, (up - fwd * up.dot(fwd)).normalized()]


## The pistol grip inside the fist: centre, axis (toward the slide) and barrel direction,
## from the pistol's own vertices (holder space).
func _pistol_grip(r: ViewRig, to_h: Transform3D) -> Dictionary:
	if r.body_bone < 0:
		return {}
	var pts: Array[Vector3] = []
	for mi in _weapon_meshes(r):
		for e in _mesh_points(r, mi, 2000):
			pts.append(to_h * (e[1] as Vector3))
	if pts.size() < 30:
		return {}
	var ax := _weapon_axes(to_h * r.skel.get_bone_global_pose(r.body_bone))
	var fwd: Vector3 = ax[0]
	var up: Vector3 = ax[1]
	var hmin := INF
	var hmax := -INF
	var tmin := INF
	var tmax := -INF
	for p in pts:
		hmin = minf(hmin, p.dot(up))
		hmax = maxf(hmax, p.dot(up))
		tmin = minf(tmin, p.dot(fwd))
		tmax = maxf(tmax, p.dot(fwd))
	# below the slide and behind the trigger guard
	var grip: Array[Vector3] = []
	for p in pts:
		if p.dot(up) < hmax - (hmax - hmin) * 0.42 and p.dot(fwd) < tmin + (tmax - tmin) * 0.45:
			grip.append(p)
	if grip.size() < 10:
		return {}
	var gmin := INF
	var gmax := -INF
	for p in grip:
		gmin = minf(gmin, p.dot(up))
		gmax = maxf(gmax, p.dot(up))
	var center := Vector3.ZERO
	var top := Vector3.ZERO
	var bot := Vector3.ZERO
	var nt := 0
	var nb := 0
	for p in grip:
		center += p
		var h := p.dot(up)
		if h > gmax - (gmax - gmin) * 0.3:
			top += p
			nt += 1
		elif h < gmin + (gmax - gmin) * 0.3:
			bot += p
			nb += 1
	center /= grip.size()
	var axis := (top / maxi(nt, 1) - bot / maxi(nb, 1)).normalized()
	if Game.args.has("trace"):
		print("[weapon] grip centre=%s axis=%s fwd=%s (%d pts)" % [center, axis, fwd, grip.size()])
	return {"center": center, "axis": axis, "fwd": fwd}


func _attach_melee(r: ViewRig, model_id: String) -> void:
	var hb := _find_bone(r.skel, "Hand_R")
	if hb < 0 or not Assets.has_model(model_id):
		return
	var to_h := r.anchor.transform * r.root.transform * r.S
	var hand_h := to_h * r.skel.get_bone_global_pose(hb)
	var grip := _pistol_grip(r, to_h)
	if grip.is_empty():
		grip = {"center": hand_h.origin, "axis": Vector3(0.0, 1.0, -0.25).normalized(), "fwd": Vector3.FORWARD}
	var c: Vector3 = grip.center
	var axis: Vector3 = grip.axis
	var edge: Vector3 = grip.fwd
	edge = (edge - axis * edge.dot(axis)).normalized()
	# model axes: head end +Z, blade edge on -X (the hooked pick on +X)
	var x := -edge
	var desired := Transform3D(Basis(x, axis.cross(x), axis), c - axis * AXE_GRIP_Z)
	var att := BoneAttachment3D.new()
	r.skel.add_child(att)
	att.bone_name = r.skel.get_bone_name(hb)
	var w := Assets.model(model_id)
	att.add_child(w)
	Assets.set_shadows(w, false)
	w.transform = hand_h.affine_inverse() * desired
	r.axe = w
	r.axe_desired = desired
	r.axe_hand0 = hand_h
	r.palm = c
	r.melee_offset = AXE_GRIP - c
	var sh := _find_bone(r.skel, "UpArm_R")
	r.melee_pivot = ((to_h * r.skel.get_bone_global_pose(sh)).origin if sh >= 0 else c + Vector3(0.1, 0.15, 0.35)) + r.melee_offset
	# at rest the arm turns about the fist so the axe takes the rest pose
	var rb := _frame(REST_SHAFT, REST_EDGE) * _frame(axis, edge).inverse()
	r.rest_xf = Transform3D(rb, AXE_GRIP - rb * AXE_GRIP)


# --------------------------------------------------------------------------
# Input hooks (called by Player)
# --------------------------------------------------------------------------

func add_sway(rel: Vector2) -> void:
	_sway_vel += -rel * 0.00012 * (0.35 if ads > 0.5 else 1.0)


func land(impact: float) -> void:
	_r_vel += Vector3(0, -impact * 1.6, 0)


func reload() -> void:
	if not is_gun() or reloading > 0.0 or _switching_to != "__none":
		return
	if mag() >= int(defn.mag) or reserve() <= 0:
		return
	var empty := mag() == 0
	var rig: ViewRig = rigs.get(current)
	var key := "reload_empty" if empty and rig and rig.reload_len.has("reload_empty") else "reload"
	var mul := State.mul("reload")
	if rig and rig.tree and rig.reload_len.has(key):
		var bt := rig.tree.tree_root as AnimationNodeBlendTree
		(bt.get_node("reload_anim") as AnimationNodeAnimation).animation = rig.cfg.anims[key]
		_reload_total = float(rig.reload_len[key]) * mul
		rig.tree.set("parameters/reload_speed/scale", 1.0 / mul)
		rig.tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		_reload_total = float(defn.reload) * mul
	reloading = _reload_total
	_reload_done = false
	Audio.sfx(defn.get("reload_sound", "reload"), -3.0, 0.03)


# --------------------------------------------------------------------------
# Per physics tick: gameplay (firing, reload timing, melee timing)
# --------------------------------------------------------------------------

func tick(delta: float, sprinting: bool, moving_speed: float, on_floor: bool) -> void:
	_sprinting = sprinting
	_speed = moving_speed
	_on_floor = on_floor
	_cd = maxf(_cd - delta, 0.0)
	_burst_t -= delta
	if _burst_t <= 0.0:
		_burst = 0
	if _switching_to != "__none":
		_equip = move_toward(_equip, 0.0, delta * 6.0)
		if _equip <= 0.0:
			_apply_switch()
	else:
		_equip = move_toward(_equip, 1.0, delta * 4.0)
	# reload: ammo goes in near the end of the animation
	if reloading > 0.0:
		reloading -= delta
		if not _reload_done and reloading <= _reload_total * 0.18:
			_reload_done = true
			var need := int(defn.mag) - mag()
			var take := mini(need, reserve())
			State.remove(defn.ammo, take)
			set_mag(mag() + take)
		if reloading <= 0.0:
			reloading = 0.0
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.can_move
	var want_ads := (captured and Input.is_action_pressed("aim") or Game.args.has("ads")) and is_gun() and reloading <= 0.0 and not sprinting and _equip > 0.9
	ads = move_toward(ads, 1.0 if want_ads else 0.0, delta * 6.5)
	if captured and current != "" and _equip > 0.95 and not sprinting and player.combat_enabled:
		if is_gun():
			var trig := Input.is_action_pressed("attack") if defn.auto else Input.is_action_just_pressed("attack")
			if trig and _cd <= 0.0 and reloading <= 0.0:
				_fire()
		elif defn.get("type", "") == "melee" and Input.is_action_just_pressed("attack") and _swing < 0.0 and _cd <= 0.0:
			_start_swing()
	_since_swing += delta
	if _swing >= 0.0:
		var rate := 1.0
		if _hitstop > 0.0:
			_hitstop -= delta
			rate = 0.12
		_swing += delta * rate
		if Game.args.has("swingt"):
			_swing = float(Game.args.swingt)
		if not _swing_hit and _swing > SWING_HIT:
			_swing_hit = true
			_melee_hit()
		if _swing > SWING_END:
			_swing = -1.0
			_since_swing = 0.0
	var spd := clampf(moving_speed / 6.0, 0.0, 1.2) if on_floor else 0.0
	if is_gun():
		var base: float = lerpf(defn.spread, defn.ads_spread, ads)
		spread_now = base * (1.0 + spd * 1.5 + _burst * 0.08 + (0.0 if on_floor else 1.5))
	else:
		spread_now = 0.0


# --------------------------------------------------------------------------
# Per rendered frame: animation + procedural layer
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if holder == null:
		return
	_flash_t -= delta
	if _flash_t <= 0.0:
		flash_mesh.visible = false
	flash_light.light_energy = maxf(flash_light.light_energy - delta * 60.0, 0.0)
	if current == "" or not rigs.has(current):
		holder.visible = false
		cam_anim = cam_anim.lerp(Vector3.ZERO, minf(delta * 8.0, 1.0))
		return
	holder.visible = true
	# viewmodel FOV: squash camera-space depth so the rig projects as if seen with VM_FOV
	var vm_fov := float(rigs[current].cfg.get("vm_fov", VM_FOV)) * lerpf(1.0, 0.88, ads)
	var k := tan(deg_to_rad(vm_fov) * 0.5) / tan(deg_to_rad(maxf(cam.fov, 1.0)) * 0.5)
	squash.scale = Vector3(1, 1, clampf(k, 0.2, 2.0))
	var rig: ViewRig = rigs[current]
	_sprint_k = lerpf(_sprint_k, 1.0 if _sprinting and _swing < 0.0 else 0.0, minf(delta * 8.0, 1.0))
	var mv := clampf(_speed / 3.4, 0.0, 1.0) if _on_floor else 0.0
	_move_k = lerpf(_move_k, mv, minf(delta * 6.0, 1.0))
	if rig.tree:
		var loco := _move_k * (1.0 - ads * 0.85)
		if rig.has.has("run"):
			loco = lerpf(loco, 2.0, _sprint_k)
		for suffix in ["", "_b"]:
			rig.tree.set("parameters/loco%s/blend_position" % suffix, loco)
			rig.tree.set("parameters/loco_speed%s/scale" % suffix, 1.0 + 0.35 * _sprint_k * (0.0 if rig.has.has("run") else 1.0))
		if rig.has.has("fire"):
			rig.tree.set("parameters/fire_mix/blend_amount", lerpf(1.0, 0.35, ads))
		rig.tree.advance(delta)
		for cb in rig.collapse:
			rig.skel.set_bone_pose_scale(cb, Vector3.ZERO)
		var camf := _cam_frame(rig)
		rig.root.transform = camf.affine_inverse()
		# authored camera motion (reload / fire shake) also moves the real camera, gently
		var d := rig.rest_cam.affine_inverse() * camf
		var e := d.basis.get_euler()
		cam_anim = cam_anim.lerp(e * lerpf(0.6, 0.15, ads), minf(delta * 20.0, 1.0))
	_springs(delta)
	_compose(delta, rig)


func _springs(delta: float) -> void:
	var k := 140.0
	var d := 15.0
	_r_vel += (-k * _r_pos - d * _r_vel) * delta
	_r_pos += _r_vel * delta
	_r_rvel += (-k * _r_rot - d * _r_rvel) * delta
	_r_rot += _r_rvel * delta
	_sway_vel += (-60.0 * _sway - 9.0 * _sway_vel) * delta
	_sway += _sway_vel * delta
	_sway = _sway.limit_length(0.06)
	_breath += delta
	var spd := clampf(_speed / 6.0, 0.0, 1.2) if _on_floor else 0.0
	_bob_t += delta * (4.0 + spd * 7.0)
	# wall avoidance
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 0.9, 1)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	var wall_target := 0.0
	if not hit.is_empty():
		wall_target = clampf(1.0 - cam.global_position.distance_to(hit.position) / 0.85, 0.0, 1.0)
	_wall = lerpf(_wall, wall_target, minf(delta * 10.0, 1.0))


func _compose(delta: float, rig: ViewRig) -> void:
	var cfg := rig.cfg
	var e := 1.0 - pow(1.0 - _equip, 3.0)
	var spd := clampf(_speed / 6.0, 0.0, 1.2) if _on_floor else 0.0
	var authored_loco := rig.tree != null and rig.has.has("walk")
	var bob_amp := spd * (0.25 if ads > 0.5 else 1.0) * float(Settings.val("headbob")) * (0.35 if authored_loco else 1.0)
	var bob := Vector3(sin(_bob_t) * 0.01, -absf(cos(_bob_t)) * 0.012, 0) * bob_amp
	var breath := Vector3(sin(_breath * 1.1) * 0.0012, sin(_breath * 2.2) * 0.0016, 0) * (0.3 if ads > 0.5 else 1.0)
	var a := smoothstep(0.0, 1.0, ads)
	var pos: Vector3 = ((cfg.get("offset", Vector3.ZERO) as Vector3) + rig.melee_offset) * (1.0 - a)
	var rot: Vector3 = (cfg.get("tilt", Vector3.ZERO) as Vector3) * (1.0 - a)
	# equip: comes up from below, rotated
	pos += Vector3(0.04, -0.28, 0.06) * (1.0 - e)
	rot += Vector3(-38, 14, 8) * (1.0 - e)
	# sprint pose for rigs without a run animation
	if not rig.has.has("run"):
		pos += Vector3(0.02, -0.05, 0.03) * _sprint_k
		rot += Vector3(-14, 28, 12) * _sprint_k
	# reaching for something (held E, or a pulse on use): the empty hand goes out toward
	# the centre of the view; a weapon just dips aside
	_reach_pulse -= delta
	_reach = move_toward(_reach, maxf(reach_goal, 1.0 if _reach_pulse > 0.0 else 0.0), delta * (7.0 if _reach_pulse > 0.0 or reach_goal > 0.0 else 4.0))
	var rk := smoothstep(0.0, 1.0, _reach)
	if cfg.get("hands", false):
		pos += Vector3(-0.09, 0.05, -0.16) * rk
		rot += Vector3(4, -16, 14) * rk
	else:
		pos += Vector3(0.03, -0.07, 0.03) * rk
		rot += Vector3(-12, 10, 4) * rk
	# melee swing: keyframed fist position + axe direction (wind-up over the shoulder,
	# diagonal chop through the centre, recover); the rig follows rigidly
	var swing_xf := Transform3D()
	if rig.cfg.get("melee", false) and rig.axe:
		# where the axe must be (rotation from its rest pose, fist position)
		var q := Basis()
		var fist := AXE_GRIP
		if _swing >= 0.0:
			var sp := _swing_pose(_swing)
			fist = sp[0]
			q = (sp[1] as Basis) * _frame(REST_SHAFT, REST_EDGE).inverse()
		# the arm swings about the shoulder (which stays put, out of view) to bring the
		# fist there; the elbow takes up any change in reach...
		var pivot := rig.rest_xf * rig.melee_pivot
		var v0 := AXE_GRIP - pivot
		var v1 := fist - pivot
		var arm := Basis()
		if v0.cross(v1).length() > 0.00001:
			arm = Basis(Quaternion(v0.normalized(), v1.normalized()))
		var arm_xf := Transform3D(arm, pivot - arm * pivot)
		arm_xf.origin += fist - arm_xf * AXE_GRIP
		swing_xf = arm_xf * rig.rest_xf
		# ...the wrist turns the axe the rest of the way, about the grip
		var off := Transform3D(Basis(), rig.melee_offset)
		var target := Transform3D(q, fist - q * AXE_GRIP)
		var wh := off.affine_inverse() * rig.rest_xf.affine_inverse() * arm_xf.affine_inverse() * target * rig.rest_xf * off
		rig.axe.transform = rig.axe_hand0.affine_inverse() * wh * rig.axe_desired
	# wall avoidance (hip only)
	pos += Vector3(0.0, -0.05, 0.12) * _wall * (1.0 - ads)
	rot += Vector3(-22, 26, 0) * _wall * (1.0 - ads)
	var motion := bob + breath + Vector3(_sway.x, _sway.y, 0) * lerpf(1.0, 0.4, ads) + _r_pos
	var proc := Transform3D(Basis.from_euler((rot + Vector3(-_sway.y * 240.0, _sway.x * 240.0, _sway.x * 110.0) * lerpf(1.0, 0.4, ads) + _r_rot) * (PI / 180.0)), pos + motion)
	var ads_t := Transform3D().interpolate_with(rig.ads_xf, a)
	holder.transform = swing_xf * proc * ads_t


# --------------------------------------------------------------------------
# Guns
# --------------------------------------------------------------------------

func muzzle_world() -> Vector3:
	var rig: ViewRig = rigs.get(current)
	if rig == null or rig.skel == null or rig.body_bone < 0:
		return cam.global_position - cam.global_basis.z * 0.6
	return rig.skel.global_transform * (rig.skel.get_bone_global_pose(rig.body_bone) * rig.muzzle)


func _eject_world() -> Vector3:
	var rig: ViewRig = rigs.get(current)
	if rig == null or rig.skel == null or rig.body_bone < 0:
		return cam.global_position + cam.global_basis.x * 0.15 - cam.global_basis.z * 0.3
	return rig.skel.global_transform * (rig.skel.get_bone_global_pose(rig.body_bone) * rig.eject)


func _fire() -> void:
	if mag() <= 0:
		_cd = 0.3
		Audio.sfx("dry_fire", -4.0, 0.02)
		if reserve() > 0:
			reload()
		return
	set_mag(mag() - 1)
	_cd = float(defn.rate)
	_burst += 1
	_burst_t = 0.35
	Audio.sfx(defn.sound, 0.0 if current != "shotgun" else 2.0, 0.05)
	var rig: ViewRig = rigs.get(current)
	var authored := rig != null and rig.tree != null and rig.has.has("fire")
	if authored:
		# rapid fire restarts the clip faster so it stays readable
		rig.tree.set("parameters/fire_speed/scale", clampf(rig.fire_len / maxf(float(defn.rate), 0.05), 1.0, 2.6))
		rig.tree.set("parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var mz := muzzle_world()
	flash_mesh.global_position = mz
	flash_mesh.scale = Vector3.ONE * randf_range(0.75, 1.3) * (1.6 if current == "shotgun" else 1.0)
	flash_mesh.rotation.z = randf() * TAU
	flash_mesh.visible = true
	_flash_t = 0.045
	flash_light.global_position = mz
	flash_light.light_energy = 7.0
	# recoil: the clip carries the big motion, springs add variation
	var rm := State.mul("recoil") * (0.6 if ads > 0.5 else 1.0) * (0.45 if authored else 1.0)
	var kick: float = defn.kick
	_r_vel += Vector3(randf_range(-0.2, 0.2) * kick, kick * 2.0, kick * 14.0) * rm
	_r_rvel += Vector3(kick * 420.0, randf_range(-1.0, 1.0) * kick * 120.0, randf_range(-1.0, 1.0) * kick * 160.0) * rm
	var climb: float = defn.recoil * State.mul("recoil") * (0.6 if ads > 0.5 else 1.0)
	player.set_pitch(player.pitch + climb * randf_range(0.8, 1.2))
	player.rotate_y(randf_range(-1.0, 1.0) * climb * 0.35)
	player.add_shake(0.12 + kick)
	FX.shell(get_tree().current_scene, _eject_world(), cam.global_basis.x, current == "shotgun")
	# rays
	var space := player.get_world_3d().direct_space_state
	var from := cam.global_position
	var fwd := -cam.global_basis.z
	var scene := get_tree().current_scene
	var killed_any := false
	var hit_any := false
	for i in int(defn.pellets):
		var s := spread_now
		var dir := (fwd + cam.global_basis.x * randf_range(-s, s) + cam.global_basis.y * randf_range(-s, s)).normalized()
		var to := from + dir * float(defn.range)
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
		q.exclude = [player.get_rid()]
		var r := space.intersect_ray(q)
		var end := to
		if not r.is_empty():
			end = r.position
			var col = r.collider
			var dist := from.distance_to(r.position)
			if col and col.has_method("take_hit"):
				var falloff := clampf(1.25 - dist / float(defn.range), 0.3, 1.0)
				var headshot: bool = col.has_method("is_headshot") and col.is_headshot(r.position)
				var dmg: float = float(defn.dmg) * falloff * (2.2 if headshot else 1.0)
				if col.take_hit(dmg, player.global_position, r.position, dir * (2.5 if current == "shotgun" else 1.6)):
					killed_any = true
				hit_any = true
				FX.impact(scene, r.position, r.normal, "flesh")
			elif i < 4:
				FX.impact(scene, r.position, r.normal, FX.surface_of(col, r.normal))
		if defn.get("tracer", false) and randf() < 0.45:
			FX.tracer(scene, mz, end)
	if hit_any:
		HUD.hitmarker(killed_any)
	if Game.level and Game.level.has_method("noise"):
		Game.level.noise(player.global_position, 55.0 if current != "pistol" else 42.0)
	fired.emit(current)


# --------------------------------------------------------------------------
# Melee
# --------------------------------------------------------------------------

func _start_swing() -> void:
	var cost: float = defn.get("stamina", 8.0) if current != "" else 6.0
	if player.stamina < cost:
		return
	player.use_stamina(cost)
	# swings chained quickly alternate: diagonal chop, flat sweep, chop...
	_swing_side = (not _swing_side) if _since_swing < COMBO_WINDOW else false
	_swing = 0.0
	_swing_hit = false
	_hitstop = 0.0
	_cd = float(defn.get("rate", 0.6))
	Audio.sfx("melee_swing", -5.0, 0.08)


func _melee_hit() -> void:
	var reach: float = defn.get("reach", 1.6)
	var dmg: float = defn.get("dmg", 10.0)
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.55
	q.shape = sph
	q.transform = Transform3D(Basis(), cam.global_position - cam.global_basis.z * (reach * 0.6))
	q.collision_mask = 4
	q.exclude = [player.get_rid()]
	var killed := false
	var hit := false
	for h in space.intersect_shape(q, 4):
		var e = h.collider
		if e and e.has_method("take_hit"):
			var at: Vector3 = e.global_position + Vector3.UP * 1.3
			if e.take_hit(dmg, player.global_position, at, -cam.global_basis.z * 2.0):
				killed = true
			hit = true
			FX.impact(get_tree().current_scene, at, (player.global_position - e.global_position).normalized(), "flesh")
	if hit:
		Audio.sfx("melee_hit", -2.0)
		player.add_shake(0.25)
		_r_rvel += Vector3(-200, 0, 80)
		_hitstop = HITSTOP
		HUD.hitmarker(killed)
	else:
		var rq := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * reach, 1)
		rq.exclude = [player.get_rid()]
		var r := space.intersect_ray(rq)
		if not r.is_empty():
			FX.impact(get_tree().current_scene, r.position, r.normal, FX.surface_of(r.collider, r.normal))
			_r_rvel += Vector3(-260, 0, 60)
			player.add_shake(0.2)
			# solid surface: a longer stop and the axe rebounds a little
			_hitstop = HITSTOP * 1.4
			_swing = maxf(_swing - 0.03, SWING_HIT - 0.02)


func fov_mult() -> float:
	return lerpf(1.0, float(defn.get("ads_fov", 1.0)), ads) if is_gun() else 1.0


func hud_info() -> Dictionary:
	if current == "" or current == "hands":
		return {"name": "Mâini goale", "mag": -1, "reserve": 0, "slot": 0}
	return {"name": ItemDB.item_name(current), "mag": mag() if is_gun() else -1, "reserve": reserve(), "slot": int(defn.get("slot", 1))}


func _debug_strip(n: Node, what: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				for w in what.split("+"):
					match w:
						"albedo": d.albedo_texture = null
						"metal": d.metallic_texture = null; d.metallic = 0.0
						"rough": d.roughness_texture = null
						"ao": d.ao_enabled = false
						"normal": d.normal_enabled = false
				mi.set_surface_override_material(i, d)
	for c in n.get_children():
		_debug_strip(c, what)
