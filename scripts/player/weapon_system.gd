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
	var ik := {}                     # arm IK data (empty-hand rig), see _setup_ik
	var grips := {}                  # prop key -> {fingers: [[bone, rel]], prop: rel} (Blender grip solver)
	var rest_xf := Transform3D()     # melee rest lean about the fist (view space)
	var fire_len := 0.3
	var reload_len := {}            # key -> seconds


signal fired(id: String)

const VM_LAYER := 1 << 19
var vm_fill: OmniLight3D

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
var stowed := false  ## arms hidden (lying in bed)
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
	# fill light that only touches the viewmodel (its own render layer): hands and guns
	# never turn into black silhouettes in the shade or against a bright sky
	vm_fill = OmniLight3D.new()
	vm_fill.name = "ViewmodelFill"
	vm_fill.position = Vector3(-0.35, 0.3, 0.15)
	vm_fill.omni_range = 1.6
	vm_fill.omni_attenuation = 0.5
	vm_fill.light_color = Color(0.92, 0.93, 1.0)
	vm_fill.light_specular = 0.25
	vm_fill.light_cull_mask = VM_LAYER
	vm_fill.shadow_enabled = false
	add_child(vm_fill)
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
	if held != "" and id != "hands":
		put_away(id)
		return
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


## Puts every mesh of the viewmodel on the world layer + the viewmodel-light layer.
func _vm_layers(n: Node) -> void:
	Assets.for_each_geometry(n, func(g: GeometryInstance3D) -> void:
		g.layers = 1 | VM_LAYER)


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
		_vm_layers(r.anchor)
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
	_vm_layers(r.anchor)
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
	r.palm = (to_h * r.skel.get_bone_global_pose(hb)).affine_inverse() * c  # palm in hand-bone space
	_setup_ik(r, grip, to_h)


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
	elif held != "" and _hs == "wait":
		_equip = move_toward(_equip, 0.0, delta * 6.0)
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
	_use_tick(delta)
	# stronger fill outdoors in daylight (deep shade under roofs), soft in the bunker
	var fill_goal := 0.9 if State.context in ["intro", "surface"] else 0.32
	vm_fill.light_energy = lerpf(vm_fill.light_energy, fill_goal, minf(delta * 2.0, 1.0))
	_flash_t -= delta
	if _flash_t <= 0.0:
		flash_mesh.visible = false
	flash_light.light_energy = maxf(flash_light.light_energy - delta * 60.0, 0.0)
	if current == "" or not rigs.has(current):
		holder.visible = false
		cam_anim = cam_anim.lerp(Vector3.ZERO, minf(delta * 8.0, 1.0))
		return
	holder.visible = not stowed
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
	_act_apply(rig, delta)


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
		if held != "" and _hs not in ["", "wait"]:
			# the arms are placed by the IK in view space; the rig sits with its
			# shoulders lower and behind the eye (the FPS rig has them at eye height,
			# which would bring the elbows in front of the camera)
			pos = _shoulders()
			rot = Vector3.ZERO
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


# --------------------------------------------------------------------------
# Things held in the hands (DayZ-style): food, water, bandages, pills
#
# The item is taken into the hands (`hold_item`); holding the attack button uses it
# for as long as it is held (gulp after gulp, spoonful after spoonful, turn after
# turn of the bandage) and every gulp / bite applies its share of the item (see
# State.consume_part). Both arms of the empty-hand rig are placed by a two-bone IK
# (upper arm + forearm, the forearm twist spread over the twist bones) on keyframed
# grip targets in view space; the fingers keep the rig's authored grip. The props sit
# in the fists, the camera follows the motion (head back to drink, down to the arm,
# chewing) and the sounds fire on the keys.
# --------------------------------------------------------------------------

## item id -> how it is used
const HOLD_KINDS := {
	"water_bottle": "drink",
	"canned_meat": "eat", "canned_beans": "eat", "stew": "eat",
	"mushroom_soup": "bowl", "tomato_salad": "bowl",
	"crackers": "bite", "tomato": "bite", "lettuce": "bite", "potato": "bite", "mushroom": "bite", "baked_potato": "bite",
	"bandage": "bandage", "medkit": "bandage",
	"antirad": "pills",
}
## bite items -> [model, max size (m)]
const BITE_PROPS := {"crackers": ["food_cracker", 0.085], "tomato": ["food_tomato", 0.075], "potato": ["food_potato", 0.09],
	"baked_potato": ["food_potato", 0.09], "mushroom": ["mushrooms", 0.08], "lettuce": ["plant_lettuce", 0.11]}

## Grip poses: [position (view space, m), rotation (deg)]. Grip frame: Y along the
## held object, -Z where the fist points.
const _BR := [Vector3(0.17, -0.5, -0.27), Vector3(-30, 10, 0)]
const _BL := [Vector3(-0.17, -0.52, -0.27), Vector3(-30, -10, 0)]
const _DR_IDLE := [Vector3(0.115, -0.14, -0.33), Vector3(4, 0, -6)]
const _DR_TIP := [Vector3(0.07, -0.12, -0.27), Vector3(65, 0, -8), Vector3(0, 20, 0)]
const _DR_MOUTH := [Vector3(0.04, -0.11, -0.21), Vector3(125, 0, -10), Vector3(0, 40, 0)]
const _DR_GULP := [Vector3(0.04, -0.106, -0.207), Vector3(131, 0, -10), Vector3(0, 40, 0)]
const _PL_IDLE := [Vector3(0.1, -0.14, -0.32), Vector3(4, 0, -8)]
const _PL_MOUTH := [Vector3(0.04, -0.11, -0.21), Vector3(116, 0, -10), Vector3(0, 40, 0)]
const _EA_IDLE_R := [Vector3(0.11, -0.17, -0.3), Vector3(-25, 0, -18)]
const _EA_IDLE_L := [Vector3(-0.08, -0.14, -0.3), Vector3(30, 30, 10), Vector3(0, -70, 0)]
const _EA_UP_L := [Vector3(-0.076, -0.132, -0.29), Vector3(30, 30, 10), Vector3(0, -70, 0)]
const _BW_IDLE_L := [Vector3(-0.08, -0.145, -0.3), Vector3(12, 30, 6), Vector3(0, -70, 0)]
const _BW_UP_L := [Vector3(-0.076, -0.137, -0.29), Vector3(12, 30, 6), Vector3(0, -70, 0)]
const _EA_READY := [Vector3(0.05, -0.14, -0.27), Vector3(-10, 0, 25)]
const _EA_DIP := [Vector3(0.002, -0.152, -0.286), Vector3(-25, 0, 55)]
const _EA_SCOOP := [Vector3(0.006, -0.146, -0.285), Vector3(-8, 0, 44)]
const _EA_MOUTH := [Vector3(0.03, -0.1, -0.19), Vector3(40, 0, 0)]
const _BI_IDLE := [Vector3(0.11, -0.15, -0.32), Vector3(10, 0, -10)]
const _BI_NEAR := [Vector3(0.05, -0.12, -0.24), Vector3(25, 0, -10)]
const _BI_BITE := [Vector3(0.035, -0.105, -0.19), Vector3(40, 0, -8)]
const _BA_IDLE := [Vector3(0.12, -0.15, -0.32), Vector3(0, 0, -30)]
const _BA_READY := [Vector3(0.06, -0.1, -0.29), Vector3(0, 0, -40)]
const _BA_ARM := [Vector3(-0.04, -0.035, -0.35), Vector3(72, 0, -28)]
const _BA_LOOK := [Vector3(-0.045, -0.035, -0.34), Vector3(72, 45, -28)]

## Per kind: props per hand, the idle pose, and the clips (keys {t, r, l, cam}).
## loop: repeated while the button is held; "use" = when in the loop the share is
## consumed ("per" of a unit); bandage: "turns" loops, then "finish" applies it.
## sfx: [t, id, dB] per clip.
const HOLD := {
	"drink": {"props": {"r": "bottle"}, "verb": "Bea", "per": 0.085, "use": 0.3,
		"idle": [{"t": 0.0, "r": _DR_IDLE}],
		"start": [{"t": 0.0, "r": _DR_IDLE}, {"t": 0.3, "r": _DR_TIP, "cam": Vector3(5, 0, 0)}, {"t": 0.6, "r": _DR_MOUTH, "cam": Vector3(15, 0, 1.5)}],
		"loop": [{"t": 0.0, "r": _DR_MOUTH, "cam": Vector3(15, 0, 1.5)}, {"t": 0.31, "r": _DR_GULP, "cam": Vector3(16.5, 0, 1.5)}, {"t": 0.62, "r": _DR_MOUTH, "cam": Vector3(15, 0, 1.5)}],
		"end": [{"t": 0.0, "r": _DR_MOUTH, "cam": Vector3(15, 0, 1.5)}, {"t": 0.28, "r": _DR_TIP, "cam": Vector3(5, 0, 0)}, {"t": 0.6, "r": _DR_IDLE, "cam": Vector3.ZERO}],
		"sfx": {"start": [[0.05, "pickup", -16.0]], "loop": [[0.14, "gulp", -3.0]], "end": [[0.35, "breath_out", -9.0]]}},
	"pills": {"props": {"r": "pills"}, "verb": "Ia o pastilă", "per": 1.0, "use": 0.35,
		"idle": [{"t": 0.0, "r": _PL_IDLE}],
		"start": [{"t": 0.0, "r": _PL_IDLE}, {"t": 0.14, "r": [Vector3(0.1, -0.135, -0.32), Vector3(-8, 0, -14)]},
			{"t": 0.28, "r": [Vector3(0.1, -0.14, -0.32), Vector3(8, 0, -4)]}, {"t": 0.6, "r": [Vector3(0.07, -0.12, -0.27), Vector3(70, 0, -10), Vector3(0, 20, 0)], "cam": Vector3(4, 0, 0)},
			{"t": 0.9, "r": _PL_MOUTH, "cam": Vector3(9, 0, 0)}],
		"loop": [{"t": 0.0, "r": _PL_MOUTH, "cam": Vector3(9, 0, 0)}, {"t": 0.35, "r": [Vector3(0.04, -0.107, -0.207), Vector3(122, 0, -10), Vector3(0, 40, 0)], "cam": Vector3(10, 0, 0)}, {"t": 0.7, "r": _PL_MOUTH, "cam": Vector3(9, 0, 0)}],
		"end": [{"t": 0.0, "r": _PL_MOUTH, "cam": Vector3(9, 0, 0)}, {"t": 0.6, "r": _PL_IDLE, "cam": Vector3.ZERO}],
		"sfx": {"start": [[0.04, "pills", -4.0], [0.3, "pills", -9.0]], "loop": [[0.45, "gulp", -6.0]]}},
	"eat": {"props": {"r": "spoon", "l": "can"}, "verb": "Mănâncă", "per": 0.2, "use": 0.78, "chew": [0.85, 1.3],
		"idle": [{"t": 0.0, "r": _EA_IDLE_R, "l": _EA_IDLE_L}],
		"start": [{"t": 0.0, "r": _EA_IDLE_R, "l": _EA_IDLE_L}, {"t": 0.35, "r": _EA_READY, "l": _EA_IDLE_L, "cam": Vector3(-1, 0, 0)}],
		"loop": [{"t": 0.0, "r": _EA_READY, "l": _EA_IDLE_L, "cam": Vector3(-1, 0, 0)}, {"t": 0.26, "r": _EA_DIP, "cam": Vector3(-3, 0, 0)},
			{"t": 0.46, "r": _EA_SCOOP, "cam": Vector3(-3, 0, 0)}, {"t": 0.78, "r": _EA_MOUTH, "l": _EA_UP_L, "cam": Vector3(2, 0, 0)},
			{"t": 1.3, "r": _EA_READY, "l": _EA_IDLE_L, "cam": Vector3(-1, 0, 0)}],
		"end": [{"t": 0.0, "r": _EA_READY, "l": _EA_IDLE_L, "cam": Vector3(-1, 0, 0)}, {"t": 0.4, "r": _EA_IDLE_R, "l": _EA_IDLE_L, "cam": Vector3.ZERO}],
		"sfx": {"loop": [[0.27, "spoon_can", -6.0], [0.86, "chew", -6.0]]}},
	"bowl": {"props": {"r": "spoon", "l": "bowl"}, "verb": "Mănâncă", "per": 0.2, "use": 0.78, "chew": [0.85, 1.3],
		"idle": [{"t": 0.0, "r": _EA_IDLE_R, "l": _BW_IDLE_L}],
		"start": [{"t": 0.0, "r": _EA_IDLE_R, "l": _BW_IDLE_L}, {"t": 0.35, "r": _EA_READY, "l": _BW_IDLE_L, "cam": Vector3(-1, 0, 0)}],
		"loop": [{"t": 0.0, "r": _EA_READY, "l": _BW_IDLE_L, "cam": Vector3(-1, 0, 0)}, {"t": 0.26, "r": _EA_DIP, "cam": Vector3(-3, 0, 0)},
			{"t": 0.46, "r": _EA_SCOOP, "cam": Vector3(-3, 0, 0)}, {"t": 0.78, "r": _EA_MOUTH, "l": _BW_UP_L, "cam": Vector3(2, 0, 0)},
			{"t": 1.3, "r": _EA_READY, "l": _BW_IDLE_L, "cam": Vector3(-1, 0, 0)}],
		"end": [{"t": 0.0, "r": _EA_READY, "l": _BW_IDLE_L, "cam": Vector3(-1, 0, 0)}, {"t": 0.4, "r": _EA_IDLE_R, "l": _BW_IDLE_L, "cam": Vector3.ZERO}],
		"sfx": {"loop": [[0.27, "spoon_can", -9.0], [0.86, "chew", -6.0]]}},
	"bite": {"props": {"r": "bite"}, "verb": "Mănâncă", "per": 0.25, "use": 0.3, "chew": [0.45, 1.1],
		"idle": [{"t": 0.0, "r": _BI_IDLE}],
		"start": [{"t": 0.0, "r": _BI_IDLE}, {"t": 0.4, "r": _BI_NEAR, "cam": Vector3(2, 0, 0)}],
		"loop": [{"t": 0.0, "r": _BI_NEAR, "cam": Vector3(2, 0, 0)}, {"t": 0.3, "r": _BI_BITE, "cam": Vector3(4, 0, 0)},
			{"t": 0.48, "r": [Vector3(0.04, -0.11, -0.2), Vector3(36, 0, -9)], "cam": Vector3(3, 0, 0)}, {"t": 1.1, "r": _BI_NEAR, "cam": Vector3(2, 0, 0)}],
		"end": [{"t": 0.0, "r": _BI_NEAR, "cam": Vector3(2, 0, 0)}, {"t": 0.4, "r": _BI_IDLE, "cam": Vector3.ZERO}],
		"sfx": {"loop": [[0.28, "bite", -4.0], [0.5, "chew", -7.0]]}},
	"bandage": {"props": {"r": "roll"}, "verb": "Bandajează", "turns": 3,
		"idle": [{"t": 0.0, "r": _BA_IDLE}],
		"start": [{"t": 0.0, "r": _BA_IDLE, "l": _BL}, {"t": 0.65, "r": _BA_READY, "l": _BA_ARM, "cam": Vector3(-7, 0, 0)}],
		"loop": [{"t": 0.0, "r": _BA_READY, "l": _BA_ARM, "cam": Vector3(-7, 0, 0)}, {"t": 0.95, "r": _BA_READY, "l": _BA_ARM, "cam": Vector3(-7, 0, 0)}],
		"finish": [{"t": 0.0, "r": _BA_READY, "l": _BA_ARM, "cam": Vector3(-7, 0, 0)}, {"t": 0.22, "r": [Vector3(0.14, -0.09, -0.3), Vector3(0, 0, -55)], "cam": Vector3(-7, 0, 0)},
			{"t": 0.42, "r": [Vector3(0.18, -0.07, -0.29), Vector3(0, 0, -45)], "l": _BA_ARM, "cam": Vector3(-7, 0, 0)}, {"t": 0.95, "r": _BA_IDLE, "l": _BA_LOOK, "cam": Vector3(-5, 0, 0)}],
		"end": [{"t": 0.0, "r": _BA_READY, "l": _BA_ARM, "cam": Vector3(-7, 0, 0)}, {"t": 0.7, "r": _BA_IDLE, "l": _BL, "cam": Vector3.ZERO}],
		"sfx": {"start": [[0.08, "bandage_tear", -4.0]], "loop": [[0.05, "bandage_wrap", -3.0]], "finish": [[0.25, "bandage_tear", -6.0]]}},
}

## Rig offset while something is held: shoulders down and back (anatomical), per
## kind (the arms of the FPS rig are short: less back where the hands work far out).
const HOLD_SHOULDERS := Vector3(0.01, -0.16, 0.03)
const HOLD_SHOULDERS_BY := {"bandage": Vector3(0.0, -0.13, 0.0), "eat": Vector3(0.0, -0.15, 0.03), "bowl": Vector3(0.0, -0.15, 0.03)}


func _shoulders() -> Vector3:
	return HOLD_SHOULDERS_BY.get(_held_kind, HOLD_SHOULDERS)

var held := ""                  ## item id in the hands ("" = none)
var _held_kind := ""
var _hs := ""                   # draw / idle / start / loop / finish / end / holster
var _hs_t := 0.0
var _hs_keys: Array = []
var _hs_len := 0.0
var _hs_sfx := 0
var _loops := 0
var _used_in_loop := false
var _after_holster := "__none"  # weapon to take out once the item is put away
var _next_item := ""            # item to take once the current one is put away
var _pose_r := Transform3D()    # last evaluated grips (view space) and camera
var _pose_l := Transform3D()
var _pose_has_l := false
var _pose_cam := Vector3.ZERO
var _wrap_w := 0.0
var _wrap_p := 0.0              # bandage progress 0..1 (turns done)
var _session := 0.0             # share of a unit used during this press
var _act_props := {}            # "r"/"l" -> Node3D (children of the holder)
var _act_sleeve: MeshInstance3D # bandage turns building up on the left forearm
var _act_strand: MeshInstance3D # gauze from the roll to the arm
var debug_hold := 0.0           # debug: seconds of "button held"


func using() -> bool:
	return held != ""


## Takes an item into the hands (puts the weapon away first). The same item again
## puts it away.
func hold_item(id: String) -> bool:
	if player == null or not HOLD_KINDS.has(id) or not RIGS.has("hands"):
		return false
	if State.available(id) <= 0:
		return false
	if held == id:
		put_away()
		return true
	if held != "" and _hs not in ["wait", "holster"]:
		# put the current one away first, then take this one
		_next_item = id
		put_away()
		return true
	if held != "":
		_act_clear()
	held = id
	_held_kind = HOLD_KINDS[id]
	_hs = "wait"
	_hs_t = 0.0
	_loops = 0
	_wrap_p = 0.0
	_after_holster = "__none"
	reloading = 0.0
	_swing = -1.0
	if current != "hands":
		_switching_to = "hands"
	return true


## Puts the held item back (and then takes out `then`, a weapon id, if given).
func put_away(then := "__none") -> void:
	if held == "":
		return
	_after_holster = then
	if _hs in ["wait", "holster"]:
		if _hs == "wait":
			_hold_done()
		return
	_hs_enter("holster")


## Kept for callers that want a one-shot use: hold the item and use it until done.
func use_animation(kind: String, model_id: String, done: Callable) -> bool:
	return false


func held_info() -> Dictionary:
	if held == "":
		return {}
	var H: Dictionary = HOLD[_held_kind]
	var frac := _wrap_p if _held_kind == "bandage" else State.remaining(held)
	return {"name": ItemDB.item_name(held), "count": State.available(held), "frac": frac,
		"verb": String(H.verb), "busy": _hs in ["start", "loop", "finish"], "kind": _held_kind}


func _hold_wanted() -> bool:
	if debug_hold > 0.0:
		return true
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and player.can_move
	return captured and Input.is_action_pressed("attack") and not _sprinting


func _hs_enter(s: String) -> void:
	var H: Dictionary = HOLD[_held_kind]
	if Game.args.has("trace"):
		print("[hold] %s -> %s  item=%s left=%.2f count=%d food=%.1f water=%.1f" % [_hs, s, held, State.remaining(held), State.available(held), State.food, State.hydration])
	_hs = s
	_hs_t = 0.0
	_hs_sfx = 0
	_used_in_loop = false
	match s:
		"draw":
			var idle: Dictionary = (H.idle as Array)[0]
			var k0 := {"t": 0.0, "r": _BR}
			var k1 := {"t": 0.45, "r": idle.r}
			if idle.has("l"):
				k0["l"] = _BL
				k1["l"] = idle.l
			_hs_keys = [k0, k1]
		"holster":
			var k0 := {"t": 0.0, "r": _pose_arr(_pose_r), "cam": _pose_cam * (180.0 / PI)}
			var k1 := {"t": 0.42, "r": _BR, "cam": Vector3.ZERO}
			if _pose_has_l:
				k0["l"] = _pose_arr(_pose_l)
				k1["l"] = _BL
			_hs_keys = [k0, k1]
		_:
			_hs_keys = H[s]
	_hs_len = float((_hs_keys.back() as Dictionary).t)


## [pos, rot deg] of a grip transform (to start a clip from wherever the hand is).
static func _pose_arr(xf: Transform3D) -> Array:
	return [xf.origin, xf.basis.get_euler() * (180.0 / PI)]


func _use_tick(delta: float) -> void:
	if held == "":
		return
	if debug_hold > 0.0:
		debug_hold -= delta
	if _hs == "wait":
		# the hands rig comes up first (the weapon goes down)
		if current == "hands" and _switching_to == "__none" and rigs.has("hands") and _equip <= 0.02:
			_act_begin(rigs["hands"])
			_hs_enter("draw")
		return
	if current != "hands":
		_hold_done()
		return
	_hs_t += delta
	# debug: --hsfreeze=state:t holds the motion still there (screenshots)
	if Game.args.has("hsfreeze"):
		var fz := String(Game.args.hsfreeze).split(":")
		if _hs == fz[0] and _hs_t >= float(fz[1]):
			_hs_t = float(fz[1])
			if _held_kind == "bandage" and _hs == "loop":
				_wrap_p = clampf((float(_loops) + _hs_t / _hs_len) / 3.0, 0.0, 1.0)
			return
	var H: Dictionary = HOLD[_held_kind]
	var sfx: Array = (H.get("sfx", {}) as Dictionary).get(_hs, [])
	while _hs_sfx < sfx.size() and _hs_t >= float(sfx[_hs_sfx][0]):
		var s: Array = sfx[_hs_sfx]
		Audio.sfx(String(s[1]), float(s[2]), 0.06)
		_hs_sfx += 1
	var want := _hold_wanted()
	# right button: put it away
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("aim") and _hs in ["draw", "idle"]:
		put_away()
		return
	match _hs:
		"draw":
			if _hs_t >= _hs_len:
				_hs_enter("idle")
		"idle":
			if want and State.available(held) > 0:
				_session = 0.0
				_hs_enter("start")
		"start":
			if _hs_t >= _hs_len:
				_hs_enter("loop")
		"loop":
			if _held_kind == "bandage":
				_wrap_p = clampf((float(_loops) + _hs_t / _hs_len) / float(H.turns), 0.0, 1.0)
			elif not _used_in_loop and _hs_t >= float(H.use):
				_used_in_loop = true
				var before := State.available(held)
				_session += State.consume_part(held, float(H.per))
				if State.available(held) < before:
					_loops = 999   # this unit is finished
			if _hs_t >= _hs_len:
				_loops += 1
				if _held_kind == "bandage" and _loops >= int(H.turns):
					_hs_enter("finish")
				elif want and _loops < 999 and State.available(held) > 0:
					_hs_t -= _hs_len
					_hs_sfx = 0
					_used_in_loop = false
				else:
					_hs_enter("end")
		"finish":
			if not _used_in_loop and _hs_t >= 0.3:
				_used_in_loop = true
				State.consume_part(held, 1.0)
				HUD.toast("Rana e bandajată.", "good")
			if _hs_t >= _hs_len:
				_hs_enter("end")
				_hs_keys = [{"t": 0.0, "r": _BA_IDLE, "l": _BA_LOOK, "cam": Vector3(-5, 0, 0)}, {"t": 0.6, "r": _BA_IDLE, "l": _BL, "cam": Vector3.ZERO}]
				_hs_len = 0.6
		"end":
			if _held_kind == "bandage" and _wrap_p < 1.0:
				_wrap_p = maxf(_wrap_p - delta * 2.0, 0.0)   # let go: the turns unwind
			if _hs_t >= _hs_len:
				_loops = 0
				_wrap_p = 0.0
				if _session > 0.0 and _held_kind != "bandage":
					HUD.toast("%s: %d%%" % [ItemDB.item_name(held), roundi(_session * 100.0)], "info")
				_session = 0.0
				if State.available(held) > 0:
					_hs_enter("idle")
					_refresh_props()
				else:
					_hs_enter("holster")
		"holster":
			if _hs_t >= _hs_len:
				_hold_done()


func _hold_done() -> void:
	var then := _after_holster
	_act_clear()
	held = ""
	_held_kind = ""
	_hs = ""
	_wrap_p = 0.0
	_after_holster = "__none"
	_equip = 0.0   # the empty hand comes back up from below
	if then != "__none" and then != current:
		switch(then)
	elif _next_item != "":
		var nx := _next_item
		_next_item = ""
		hold_item(nx)


func _act_begin(r: ViewRig) -> void:
	_act_clear()
	var H: Dictionary = HOLD[_held_kind]
	var props: Dictionary = H.get("props", {})
	for side in props:
		var p := _act_prop(String(props[side]))
		if p:
			holder.add_child(p)
			Assets.set_shadows(p, false)
			_vm_layers(p)
			p.visible = false
			_act_props[side] = p
	if _held_kind == "bandage":
		_act_sleeve = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 20
		cm.rings = 1
		_act_sleeve.mesh = cm
		_act_sleeve.material_override = _gauze_mat()
		_act_sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_act_sleeve.layers = 1 | VM_LAYER
		_act_sleeve.visible = false
		holder.add_child(_act_sleeve)
		_act_strand = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		_act_strand.mesh = bm
		_act_strand.material_override = _gauze_mat()
		_act_strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_act_strand.layers = 1 | VM_LAYER
		_act_strand.visible = false
		holder.add_child(_act_strand)
	_refresh_props()


## A fresh unit (or what is left of the opened one): bites shrink the food.
func _refresh_props() -> void:
	if _held_kind == "bite" and _act_props.has("r"):
		var p: Node3D = _act_props.r
		if is_instance_valid(p) and p.get_child_count() > 0:
			var k := lerpf(0.5, 1.0, State.remaining(held))
			(p.get_child(0) as Node3D).scale = Vector3.ONE * float(p.get_meta("fit", 1.0)) * k


func _act_clear() -> void:
	for side in _act_props:
		var p: Node3D = _act_props[side]
		if is_instance_valid(p):
			p.queue_free()
	_act_props.clear()
	for n in [_act_sleeve, _act_strand]:
		if n and is_instance_valid(n):
			n.queue_free()
	_act_sleeve = null
	_act_strand = null
	_wrap_w = 0.0


var _gauze: StandardMaterial3D


func _gauze_mat() -> StandardMaterial3D:
	if _gauze == null:
		_gauze = StandardMaterial3D.new()
		_gauze.albedo_color = Color(0.8, 0.78, 0.72)
		# the bandage roll's own gauze texture, if the model has one
		if Assets.has_model("bandage_roll"):
			var m := Assets.model("bandage_roll")
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				var src := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
				if src and src.albedo_texture:
					_gauze.albedo_texture = src.albedo_texture
					_gauze.albedo_color = Color(0.95, 0.93, 0.88)
					if src.normal_texture:
						_gauze.normal_enabled = true
						_gauze.normal_texture = src.normal_texture
					break
			m.free()
		_gauze.uv1_scale = Vector3(2, 1, 1)
		_gauze.roughness = 0.95
		_gauze.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _gauze


## The prop and where it sits in the grip frame (Y along the object, centred on the
## fist; shifted toward the fingers so thick objects don't swallow the hand).
func _act_prop(id: String) -> Node3D:
	var model := ""
	var grip_h := 0.5      # where along its height the fist holds it (0..1)
	var fwd := 0.0         # shift toward the fingers (-Z of the grip), m
	var side := 0.0        # shift along grip X, m
	var fit := 0.0         # scale the model so its largest side is this (m)
	match id:
		"bottle":
			model = "water_bottle_m"   # 0.5 L
			grip_h = 0.42
			fwd = 0.016
			fit = 0.21
		"pills":
			model = "pill_bottle"
			grip_h = 0.4
			fwd = 0.006
		"can":
			model = "canned_food"
			grip_h = 0.38
			fwd = 0.02
			side = 0.012
		"bowl":
			model = "bowl_enamel"
		"roll":
			model = "bandage_roll"
			grip_h = 0.5
			fwd = 0.02
			fit = 0.11
		"spoon":
			model = "spoon_metal"
		"bite":
			# held at the fingertips, most of it above the fist (the part you bite)
			var bp: Array = BITE_PROPS.get(held, ["food_potato", 0.09])
			model = String(bp[0])
			fit = float(bp[1])
			grip_h = 0.12
			fwd = 0.03
	if model == "" or not Assets.has_model(model):
		return null
	var m := Assets.model(model)
	m.set_meta("model_id", model)
	var wrap := Node3D.new()
	wrap.name = "UseProp_" + id
	wrap.set_meta("prop_id", id)
	wrap.add_child(m)
	var aabb := Assets.model_aabb(m)
	var s := 1.0
	if fit > 0.0:
		s = fit / maxf(maxf(aabb.size.x, aabb.size.y), maxf(aabb.size.z, 0.001))
		m.scale = Vector3.ONE * s
		wrap.set_meta("fit", s)
	match id:
		"spoon":
			# model: long along Z, bowl at -Z -> handle down through the fist, the bowl
			# up and its hollow facing back (+Z of the grip, toward the face)
			var rot := Basis(Vector3.RIGHT, deg_to_rad(90.0))
			m.transform = Transform3D(rot, Vector3.ZERO)
			# the handle end (model +Z) sticks out 4 cm below the fist centre
			m.position = -(rot * Vector3(0, aabb.size.y * 0.5, aabb.end.z - 0.045))
		"bowl":
			# placed level in view space beside the left palm (see _act_apply)
			m.position = Vector3(0.0, -aabb.size.y * 0.55, 0.0)
		_:
			m.position = Vector3(side, -aabb.size.y * s * grip_h, -fwd)
	if id == "bottle":
		_clear_bottle(m)
	return wrap


## The bottle model is black plastic; water reads better through clear PET.
func _clear_bottle(m: Node3D) -> void:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			if src and src.resource_name.to_lower().contains("bottle"):
				var pet := StandardMaterial3D.new()
				pet.resource_name = "pet_water"
				pet.albedo_color = Color(0.74, 0.86, 0.92, 0.3)
				pet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				pet.roughness = 0.05
				pet.metallic_specular = 0.9
				pet.rim_enabled = true
				pet.rim = 0.4
				pet.rim_tint = 0.2
				if src is StandardMaterial3D and (src as StandardMaterial3D).normal_texture:
					pet.normal_enabled = true
					pet.normal_texture = (src as StandardMaterial3D).normal_texture
				(mi as MeshInstance3D).set_surface_override_material(i, pet)


## Smooth curve through the keys that have `side` (Catmull-Rom in time).
func _act_curve(keys: Array, side: String, idx: int, t: float) -> Vector3:
	var ts: Array[float] = []
	var vs: Array[Vector3] = []
	for k in keys:
		var kd: Dictionary = k
		if kd.has(side):
			ts.append(float(kd.t))
			var v = kd[side]
			if v is Array:
				vs.append((v as Array)[idx] if idx < (v as Array).size() else Vector3.ZERO)
			else:
				vs.append(v)
	var n := ts.size()
	if n == 0:
		return Vector3.ZERO
	if t <= ts[0]:
		return vs[0]
	if t >= ts[n - 1]:
		return vs[n - 1]
	var i := 0
	while i < n - 2 and t > ts[i + 1]:
		i += 1
	var ta := ts[i]
	var tb := ts[i + 1]
	var tpa := ts[i - 1] if i > 0 else ta - (tb - ta)
	var tpb := ts[i + 2] if i + 2 < n else tb + (tb - ta)
	var w := (t - ta) / maxf(tb - ta, 0.0001)
	return vs[i].cubic_interpolate_in_time(vs[i + 1], vs[maxi(i - 1, 0)], vs[mini(i + 2, n - 1)], w, tb - ta, tpa - ta, tpb - ta)


## Grip frame target (view space) of one hand at time t.
func _act_grip(keys: Array, side: String, t: float) -> Transform3D:
	var p := _act_curve(keys, side, 0, t)
	var e := _act_curve(keys, side, 1, t) * (PI / 180.0)
	var spin := _act_curve(keys, side, 2, t).y * (PI / 180.0)
	# debug: --posedbg=r:x,y,z:rx,ry,rz:spin (and/or l:...) replaces a grip pose
	if Game.args.has("posedbg") and _hs in ["loop", "idle"]:
		for part in String(Game.args.posedbg).split("/"):
			var f := part.split(":")
			if f.size() >= 3 and f[0] == side:
				var pv := f[1].split_floats(",")
				var rv := f[2].split_floats(",")
				p = Vector3(pv[0], pv[1], pv[2])
				e = Vector3(rv[0], rv[1], rv[2]) * (PI / 180.0)
				spin = deg_to_rad(float(f[3])) if f.size() > 3 else 0.0
	return Transform3D(Basis.from_euler(e) * Basis(Vector3.UP, spin), p)


## Camera motion that goes with the hands (head back to drink, down to the arm, chewing).
func use_cam() -> Vector3:
	if held == "" or _hs in ["", "wait"]:
		return Vector3.ZERO
	return _pose_cam


## 0..1..0 over [a, b] with soft edges.
static func _act_window(t: float, a: float, b: float) -> float:
	return smoothstep(a, a + 0.12, t) * (1.0 - smoothstep(b - 0.12, b, t))


## Poses the arms for what is in the hands (after the rig's animation and _compose).
func _act_apply(r: ViewRig, delta: float) -> void:
	if held == "" or _hs in ["", "wait"] or r.skel == null or r.ik.is_empty() or _hs_keys.is_empty():
		return
	var H: Dictionary = HOLD[_held_kind]
	var keys := _hs_keys
	var t := minf(_hs_t, _hs_len)
	var to_h := r.anchor.transform * r.root.transform * r.S
	var from_h := to_h.affine_inverse()
	var ik_r: Dictionary = r.ik.r
	var ik_l: Dictionary = r.ik.l
	var vh := Transform3D(Basis(), -_shoulders())   # view space -> holder space
	# camera
	var cam := _act_curve(keys, "cam", 0, t)
	if H.has("chew") and _hs == "loop":
		var cw: Array = H.chew
		var w := _act_window(t, float(cw[0]), float(cw[1]))
		cam.x += maxf(sin((t - float(cw[0])) * TAU * 2.6), 0.0) * 0.8 * w
	_pose_cam = cam * (PI / 180.0)
	# left arm first: the right hand may work on it
	var arm_l := {}
	_pose_has_l = (keys[0] as Dictionary).has("l")
	if _pose_has_l:
		for cb in r.collapse:
			r.skel.set_bone_pose_scale(cb, Vector3.ONE)
		_pose_l = _act_grip(keys, "l", t)
		_pose_l.origin += Vector3(sin(_breath * 1.3) * 0.002, sin(_breath * 2.1) * 0.002, 0.0)
		var hand_l := vh * _pose_l * (ik_l.gh as Transform3D).affine_inverse()
		arm_l = _ik_arm(r, ik_l, hand_l, to_h, from_h, ik_l.pole_h)
		var gl_fit := _grip_for(r, "l")
		if not gl_fit.is_empty() and _held_kind != "bowl":
			_apply_grip(r, gl_fit, hand_l, from_h)
			_place_fitted("l", hand_l * (gl_fit.prop as Transform3D))
		arm_l.elbow = vh.affine_inverse() * (arm_l.elbow as Vector3)
		arm_l.wrist = vh.affine_inverse() * (arm_l.wrist as Vector3)
	var gr := _act_grip(keys, "r", t)
	if _hs == "idle":
		gr.origin += Vector3(sin(_breath * 1.1) * 0.0025, sin(_breath * 2.2) * 0.003, 0.0)
	# bandage: the right fist goes round the forearm while the turns build up
	_wrap_w = move_toward(_wrap_w, 1.0 if _hs == "loop" and _held_kind == "bandage" else 0.0, delta * 5.0)
	if _wrap_w > 0.0 and not arm_l.is_empty():
		gr = gr.interpolate_with(_act_wrap(arm_l, t), _wrap_w)
	_pose_r = gr
	var hand_r := vh * gr * (ik_r.gh as Transform3D).affine_inverse()
	_ik_arm(r, ik_r, hand_r, to_h, from_h, ik_r.pole_h)
	var gr_fit := _grip_for(r, "r")
	if not gr_fit.is_empty():
		_apply_grip(r, gr_fit, hand_r, from_h)
		_place_fitted("r", hand_r * (gr_fit.prop as Transform3D))
	# props follow the grips
	for side in _act_props:
		var p: Node3D = _act_props[side]
		if not is_instance_valid(p):
			continue
		if side == "l" and not _pose_has_l:
			p.visible = false
			continue
		if p.has_meta("fitted_xf"):
			p.transform = p.get_meta("fitted_xf")
			p.remove_meta("fitted_xf")
		elif side == "l" and _held_kind == "bowl":
			# a bowl stays level (soup!), tipped a little toward the eyes, resting in the
			# left hand on the side toward the centre of the view
			p.transform = vh * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(16.0)), _pose_l.origin + Vector3(0.055, 0.012, -0.012))
		else:
			p.transform = vh * (gr if side == "r" else _pose_l)
		p.visible = true
	if _act_sleeve:
		_act_bandage_fx(gr, arm_l)
		_act_sleeve.transform = vh * _act_sleeve.transform
		_act_strand.transform = vh * _act_strand.transform


## A prop placed by its Blender grip: the model itself takes the whole transform.
func _place_fitted(side: String, xf: Transform3D) -> void:
	var p: Node3D = _act_props.get(side)
	if p == null or not is_instance_valid(p) or p.get_child_count() == 0:
		return
	var m := p.get_child(0) as Node3D
	# bites take the food down to half its size
	var k := lerpf(0.5, 1.0, State.remaining(held)) if _held_kind == "bite" else 1.0
	m.transform = Transform3D(Basis().scaled(Vector3.ONE * k), Vector3.ZERO)
	p.set_meta("fitted_xf", xf)


## The right fist circling the left forearm (the roll's axis along the arm), passing
## over it and behind it; the turns move toward the wrist.
func _act_wrap(arm_l: Dictionary, t: float) -> Transform3D:
	var elbow: Vector3 = arm_l.elbow
	var wrist: Vector3 = arm_l.wrist
	var ax := (wrist - elbow).normalized()
	var u := Vector3.UP - ax * Vector3.UP.dot(ax)
	u = u.normalized() if u.length() > 0.01 else Vector3.BACK
	var v := ax.cross(u)
	var turns := float(_loops) + t / maxf(_hs_len, 0.01)
	var c := elbow.lerp(wrist, lerpf(0.7, 0.92, clampf(_wrap_p, 0.0, 1.0)))
	var phi := turns * TAU + PI * 0.35
	var radial := u * cos(phi) + v * sin(phi)
	var pos := c + radial * 0.085
	var gy := ax
	var gz := radial
	var gx := gy.cross(gz).normalized()
	gz = gx.cross(gy).normalized()
	return Transform3D(Basis(gx, gy, gz), pos)


func _act_bandage_fx(gr: Transform3D, arm_l: Dictionary) -> void:
	if arm_l.is_empty():
		_act_sleeve.visible = false
		_act_strand.visible = false
		return
	var elbow: Vector3 = arm_l.elbow
	var wrist: Vector3 = arm_l.wrist
	var ax := (wrist - elbow).normalized()
	var flen := elbow.distance_to(wrist)
	var a := elbow.lerp(wrist, 0.68)
	var b := elbow.lerp(wrist, lerpf(0.68, 0.94, _wrap_p))
	var length := a.distance_to(b)
	_act_sleeve.visible = length > 0.004
	if _act_sleeve.visible:
		# over the jacket cuff (the gauze would vanish inside the sleeve)
		var rad := lerpf(0.056, 0.05, a.distance_to(elbow) / maxf(flen, 0.01))
		var bz := ax.cross(Vector3.UP)
		bz = bz.normalized() if bz.length() > 0.1 else Vector3.BACK
		var bx := ax.cross(bz).normalized()
		_act_sleeve.transform = Transform3D(Basis(bx * rad, ax * length, bz * rad), (a + b) * 0.5)
	_act_strand.visible = _wrap_w > 0.3
	if _act_strand.visible:
		var d := b - gr.origin
		var len := d.length()
		if len < 0.005:
			_act_strand.visible = false
			return
		var y := d / len
		var x := y.cross(Vector3.FORWARD)
		x = x.normalized() if x.length() > 0.1 else Vector3.RIGHT
		var z := x.cross(y).normalized()
		_act_strand.transform = Transform3D(Basis(x * 0.045, y * len, z * 0.0015), (gr.origin + b) * 0.5)


## Two-bone IK for one arm in holder space: puts the hand at `hand_t` (by moving its IK
## control bone), bends the elbow toward the rig's pole target and spreads the forearm
## twist over the twist bones. Returns {elbow, wrist} (holder space).
func _ik_arm(r: ViewRig, ik: Dictionary, hand_t: Transform3D, to_h: Transform3D, from_h: Transform3D, pole_h: Vector3) -> Dictionary:
	var sk := r.skel
	var U := to_h * sk.get_bone_global_pose(ik.up)
	var F := to_h * sk.get_bone_global_pose(ik.fore)
	var C := to_h * sk.get_bone_global_pose(ik.ctrl)
	var Hb := to_h * sk.get_bone_global_pose(ik.hand)
	var P := pole_h
	# the twist bones as animated, before anything moves (their parent is the forearm)
	var tws: Array = ik.tw
	var T_old: Array[Transform3D] = []
	for bi in tws:
		T_old.append(to_h * sk.get_bone_global_pose(int(bi)))
	# hand: move the IK control so the hand lands on the target
	var c_new := hand_t * (C.affine_inverse() * Hb).affine_inverse()
	sk.set_bone_global_pose(ik.ctrl, from_h * c_new)
	var s := U.origin
	var a: float = ik.a
	var b: float = ik.b
	var tgt := hand_t.origin
	var to_t := tgt - s
	var dist := to_t.length()
	var dir := to_t / maxf(dist, 0.0001)
	var d := clampf(dist, absf(a - b) + 0.002, (a + b) * 0.9995)
	var pv := P - s
	var n := pv - dir * pv.dot(dir)
	n = n.normalized() if n.length() > 0.0001 else Vector3.DOWN
	var ca := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := s + dir * (a * ca) + n * (a * sqrt(1.0 - ca * ca))
	var wrist := s + dir * d
	# upper arm: carry the old (direction, bend plane) frame onto the new one
	var u0 := (F.origin - s).normalized()
	var f0 := (Hb.origin - F.origin).normalized()
	var u1 := (elbow - s).normalized()
	var f1 := (wrist - elbow).normalized()
	var rot_up := Basis(Quaternion(u0, u1))
	var n0 := u0.cross(f0)
	var n1 := u1.cross(f1)
	if n0.length() > 0.001 and n1.length() > 0.001:
		rot_up = _ik_frame(u1, n1.normalized()) * _ik_frame(u0, n0.normalized()).inverse()
	var U1 := Transform3D(rot_up * U.basis, s)
	sk.set_bone_global_pose(ik.up, from_h * U1)
	# forearm: rides on the upper arm, then bends at the elbow onto the wrist
	var F1 := U1 * (U.affine_inverse() * F)
	var fdir := (rot_up * f0).normalized()
	var bend := Basis(Quaternion(fdir, f1)) if fdir.cross(f1).length() > 0.00001 else Basis()
	F1 = Transform3D(bend * F1.basis, elbow)
	sk.set_bone_global_pose(ik.fore, from_h * F1)
	# forearm twist: the roll the hand asks for (vs. the authored hand-to-forearm
	# relation) goes 1/3, 2/3, 3/3 onto the twist bones
	var rel: Basis = ik.rel
	var want := hand_t.basis.orthonormalized() * rel.inverse()
	var q := (want * F1.basis.orthonormalized().inverse()).get_rotation_quaternion()
	var tw := wrapf(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(f1), q.w), -PI, PI)
	# the forearm only rolls so far (pronation / supination); beyond that the skin
	# would wring into a flat ribbon — the rest is taken at the wrist, under the cuff
	tw = clampf(tw, -0.7, 0.7)
	var prev := F
	var prev_new := F1
	for i in tws.size():
		var bi: int = tws[i]
		var T: Transform3D = T_old[i]
		var T1 := prev_new * (prev.affine_inverse() * T)
		prev = T
		T1.basis = Basis(f1, tw * float(i + 1) / float(tws.size())) * T1.basis
		sk.set_bone_global_pose(bi, from_h * T1)
		prev_new = T1
	return {"elbow": elbow, "wrist": wrist}


## Orthonormal frame from a direction and a normal (columns: dir, normal, dir x normal).
static func _ik_frame(d: Vector3, nrm: Vector3) -> Basis:
	return Basis(d, nrm, d.cross(nrm).normalized())


## IK data for the empty-hand rig: bone indices, arm lengths, the authored
## hand-to-forearm relation and the grip frame in each hand's space (the pistol grip:
## Y up the grip, -Z where the barrel points).
func _setup_ik(r: ViewRig, grip: Dictionary, to_h: Transform3D) -> void:
	if grip.is_empty():
		return
	var gy: Vector3 = (grip.axis as Vector3).normalized()
	var fwd: Vector3 = grip.fwd
	var gz := -(fwd - gy * fwd.dot(gy)).normalized()
	var gx := gy.cross(gz).normalized()
	var G := Transform3D(Basis(gx, gy, gz), grip.center)
	var out := {}
	for side in ["R", "L"]:
		var ik := {}
		ik.up = _find_bone(r.skel, "UpArm_" + side)
		ik.fore = _find_bone(r.skel, "Forearm_" + side)
		ik.ctrl = _find_bone(r.skel, "IK_Hand_Cntrl_" + side)
		ik.hand = _find_bone(r.skel, "Hand_" + side)
		ik.pole = _find_bone(r.skel, "IK_PoleTrgt_" + side)
		var tw: Array[int] = []
		for k in ["BoneTwist_03." + side, "BoneTwist_02." + side, "BoneTwist_01." + side]:
			var bi := _find_bone(r.skel, k)
			if bi >= 0:
				tw.append(bi)
		ik.tw = tw
		if int(ik.up) < 0 or int(ik.fore) < 0 or int(ik.ctrl) < 0 or int(ik.hand) < 0 or int(ik.pole) < 0:
			return
		var U := to_h * r.skel.get_bone_global_pose(ik.up)
		var F := to_h * r.skel.get_bone_global_pose(ik.fore)
		var Hb := to_h * r.skel.get_bone_global_pose(ik.hand)
		ik.a = U.origin.distance_to(F.origin)
		ik.b = F.origin.distance_to(Hb.origin)
		ik.rel = F.basis.orthonormalized().inverse() * Hb.basis.orthonormalized()
		# grip frame: the pistol grip for the right fist; for the left hand (which wraps
		# round the right one on the pistol) the same frame moved into its own palm
		var Gs := G
		if side == "L":
			Gs = Transform3D(G.basis, Hb.origin + Hb.basis.y.normalized() * 0.075 + Hb.basis.x.normalized() * 0.01)
		ik.gh = Hb.affine_inverse() * Gs
		# elbow hint (holder space): out to the side, down and well behind the eye
		ik.pole_h = Vector3(0.45 if side == "R" else -0.45, -1.4, 0.35)
		out[side.to_lower()] = ik
	r.ik = out
	_load_grips(r)
	if Game.args.has("dumpgrips"):
		_dump_grips(r, to_h)


## Finger poses and prop placements solved in Blender for each held object
## (tools/blender/grip_fit.py): transforms relative to the hand bone, skeleton space.
const GRIPS_FILE := "res://assets/data/hand_grips.json"


func _load_grips(r: ViewRig) -> void:
	if not FileAccess.file_exists(GRIPS_FILE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(GRIPS_FILE))
	if not (data is Dictionary):
		return
	for key in data:
		var g: Dictionary = data[key]
		var fingers: Array = []
		for bn in g.get("fingers", {}):
			var bi := r.skel.find_bone(String(bn))
			if bi >= 0:
				fingers.append([bi, _arr_xf(g.fingers[bn])])
		fingers.sort_custom(func(a, b) -> bool: return int(a[0]) < int(b[0]))   # parents first
		r.grips[key] = {"fingers": fingers, "prop": _arr_xf(g.prop)}


static func _arr_xf(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))


## The grip (Blender-solved) for what a hand holds, or {}.
func _grip_for(r: ViewRig, side: String) -> Dictionary:
	if not _act_props.has(side):
		return {}
	var id := String((_act_props[side] as Node3D).get_meta("prop_id", ""))
	var key := ("bite_" + held) if id == "bite" else id
	return r.grips.get(key, {})


## Fingers round the object, from the hand's current (IK) pose.
func _apply_grip(r: ViewRig, grip: Dictionary, hand_h: Transform3D, from_h: Transform3D) -> void:
	var hand_s := from_h * hand_h
	for f in grip.fingers:
		r.skel.set_bone_global_pose(int(f[0]), hand_s * (f[1] as Transform3D))


## Dev: writes where each held prop sits relative to the hands, in skeleton space at the
## rig's authored frame (for the Blender grip solver, tools/blender/grip_fit.py).
func _dump_grips(r: ViewRig, to_h: Transform3D) -> void:
	var from_h := to_h.affine_inverse()
	var out := {"bones": {}, "props": {}}
	for bi in r.skel.get_bone_count():
		out.bones[r.skel.get_bone_name(bi)] = {"pose": _xf_arr(r.skel.get_bone_global_pose(bi)), "rest": _xf_arr(r.skel.get_bone_global_rest(bi)), "parent": r.skel.get_bone_parent(bi)}
	var saved := held
	for spec in [["bottle", "r", "water_bottle"], ["pills", "r", "antirad"], ["roll", "r", "bandage"], ["spoon", "r", "canned_meat"],
			["bite", "r", "tomato"], ["bite", "r", "potato"], ["bite", "r", "crackers"], ["can", "l", "canned_meat"]]:
		held = String(spec[2])
		var w := _act_prop(String(spec[0]))
		if w == null:
			continue
		var m := w.get_child(0) as Node3D
		var ik: Dictionary = r.ik[spec[1]]
		var hand_h := to_h * r.skel.get_bone_global_pose(ik.hand)
		var grip_h := hand_h * (ik.gh as Transform3D)
		var prop_skel := from_h * grip_h * m.transform
		var key := String(spec[0]) if spec[0] != "bite" else "bite_" + held
		out.props[key] = {"side": spec[1], "xf": _xf_arr(prop_skel), "grip": _xf_arr(from_h * grip_h), "model_scale": m.scale.x, "model": String(m.get_meta("model_id", "")), "aabb": [Assets.model_aabb(m).size.x, Assets.model_aabb(m).size.y, Assets.model_aabb(m).size.z]}
		w.free()
	held = saved
	var f := FileAccess.open(String(Game.args.dumpgrips), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("[grips] wrote ", Game.args.dumpgrips)


static func _xf_arr(x: Transform3D) -> Array:
	return [x.basis.x.x, x.basis.x.y, x.basis.x.z, x.basis.y.x, x.basis.y.y, x.basis.y.z, x.basis.z.x, x.basis.z.y, x.basis.z.z, x.origin.x, x.origin.y, x.origin.z]


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
