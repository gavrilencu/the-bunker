class_name Ragdoll
extends RefCounted
## Physical ragdoll for humanoid skeletons (Mixamo or 3ds Max Biped naming).
##
## Unscaled RigidBody3D parts joined by cone-twist joints are built from the
## character's pose at the moment of death; a SkeletonModifier3D then drives the
## bones from the bodies every frame. Working in world space keeps it correct for
## models whose skeletons carry a normalisation scale (physics ignores scale).

const LAYER := 16

## key, normalized bone names (first match wins), mass (kg), radius (m), parent part
const PARTS := [
	["hips", ["hips", "pelvis"], 12.0, 0.12, ""],
	["spine", ["spine", "spine1"], 9.0, 0.11, "hips"],
	["chest", ["spine2", "ribcage"], 13.0, 0.13, "spine"],
	["head", ["head"], 5.0, 0.1, "chest"],
	["l_arm", ["leftarm", "larmupperarm"], 2.5, 0.05, "chest"],
	["l_fore", ["leftforearm", "larmforearm"], 1.8, 0.042, "l_arm"],
	["r_arm", ["rightarm", "rarmupperarm"], 2.5, 0.05, "chest"],
	["r_fore", ["rightforearm", "rarmforearm"], 1.8, 0.042, "r_arm"],
	["l_thigh", ["leftupleg", "llegthigh", "lthigh"], 8.0, 0.07, "hips"],
	["l_calf", ["leftleg", "llegcalf", "lcalf"], 4.0, 0.055, "l_thigh"],
	["r_thigh", ["rightupleg", "rlegthigh", "rthigh"], 8.0, 0.07, "hips"],
	["r_calf", ["rightleg", "rlegcalf", "rcalf"], 4.0, 0.055, "r_thigh"],
]
## cone limits (swing, twist) in degrees
const LIMITS := {"spine": [20, 10], "chest": [20, 10], "head": [38, 30], "l_arm": [70, 25], "r_arm": [70, 25],
	"l_fore": [60, 8], "r_fore": [60, 8], "l_thigh": [50, 10], "r_thigh": [50, 10], "l_calf": [60, 5], "r_calf": [60, 5]}


class Driver extends SkeletonModifier3D:
	var rd: Ragdoll

	func _process_modification_with_delta(_delta: float) -> void:
		if rd == null:
			return
		var skel := get_skeleton()
		var inv := skel.global_transform.affine_inverse()
		for key in rd.order:
			var body: RigidBody3D = rd.bodies[key]
			if not is_instance_valid(body):
				continue
			skel.set_bone_global_pose(int(rd.bone_of[key]), inv * (body.global_transform * (rd.k[key] as Transform3D)))


var skel: Skeleton3D
var bodies := {}    # key -> RigidBody3D
var bone_of := {}   # key -> bone index
var k := {}         # key -> body-space transform of the bone (keeps the skeleton scale)
var order: Array[String] = []
var driver: Driver
var _holder: Node3D


static func _find(skel: Skeleton3D, names: Array) -> int:
	for want in names:
		for i in skel.get_bone_count():
			if AnimRetarget.norm(skel.get_bone_name(i)) == want:
				return i
	return -1


## Returns null when the skeleton isn't a recognizable humanoid. owner: node the bodies live under.
static func build(p_skel: Skeleton3D, owner: Node) -> Ragdoll:
	var idx := {}
	for p in PARTS:
		idx[p[0]] = _find(p_skel, p[1])
	for key in ["hips", "chest", "head", "l_thigh", "r_thigh", "l_calf", "r_calf", "l_arm", "r_arm"]:
		if int(idx[key]) < 0:
			return null
	var r := Ragdoll.new()
	r.skel = p_skel
	r._holder = Node3D.new()
	r._holder.name = "RagdollBodies"
	r._holder.top_level = true
	owner.add_child(r._holder)
	var sk := p_skel.global_transform
	var world := func(b: int) -> Transform3D:
		return sk * p_skel.get_bone_global_pose(b)
	var wp := func(key: String) -> Vector3:
		var b: int = idx.get(key, -1)
		return (world.call(b) as Transform3D).origin if b >= 0 else Vector3.ZERO
	var head_p: Vector3 = wp.call("head")
	var hips_p: Vector3 = wp.call("hips")
	var up := (head_p - hips_p).normalized()
	var la: Vector3 = wp.call("l_arm")
	var ra: Vector3 = wp.call("r_arm")
	var neck := _find(p_skel, ["neck"])
	for p in PARTS:
		var key: String = p[0]
		var b: int = idx[key]
		if b < 0:
			continue
		var a: Vector3 = wp.call(key)
		var e := a
		match key:
			"hips":
				a = wp.call("l_thigh")
				e = wp.call("r_thigh")
			"spine":
				e = wp.call("chest")
			"chest":
				e = (world.call(neck) as Transform3D).origin if neck >= 0 else head_p
			"head":
				e = a + up * 0.22
			"l_arm":
				e = wp.call("l_fore")
			"r_arm":
				e = wp.call("r_fore")
			"l_thigh":
				e = wp.call("l_calf")
			"r_thigh":
				e = wp.call("r_calf")
			_:
				var ch := p_skel.get_bone_children(b)
				e = (world.call(ch[0]) as Transform3D).origin if ch.size() > 0 else a - up * 0.25
		var axis := e - a
		var length := axis.length()
		if length < 0.02:
			continue
		var y := axis / length
		var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var x := ref.cross(y).normalized()
		var z := x.cross(y).normalized()
		var basis := Basis(x, y, z)
		if key == "chest":
			var across := (ra - la).normalized()
			var zz := across.cross(y).normalized()
			basis = Basis(y.cross(zz).normalized(), y, zz)
		var body := RigidBody3D.new()
		body.name = "RB_" + key
		body.mass = float(p[2])
		var pm := PhysicsMaterial.new()
		pm.friction = 0.9
		pm.bounce = 0.0
		body.physics_material_override = pm
		body.linear_damp = 0.1
		body.angular_damp = 2.0
		body.collision_layer = LAYER
		body.collision_mask = 1
		body.continuous_cd = key in ["head", "l_fore", "r_fore", "l_calf", "r_calf"]
		var cs := CollisionShape3D.new()
		var radius: float = p[3]
		if key == "chest":
			var bs := BoxShape3D.new()
			bs.size = Vector3(maxf(la.distance_to(ra) * 0.85, radius * 2.0), length * 1.05, 0.22)
			cs.shape = bs
		elif key == "hips":
			var cap := CapsuleShape3D.new()
			cap.radius = radius
			cap.height = length + radius * 2.0
			cs.shape = cap
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = radius
			cap.height = maxf(length + radius * 0.5, radius * 2.05)
			cs.shape = cap
		body.add_child(cs)
		r._holder.add_child(body)
		body.global_transform = Transform3D(basis, (a + e) * 0.5)
		r.bodies[key] = body
		r.bone_of[key] = b
		r.k[key] = body.global_transform.affine_inverse() * (world.call(b) as Transform3D)
		r.order.append(key)
	# joints at the anatomical pivots, twist axis (X) along the child bone
	for p in PARTS:
		var key: String = p[0]
		var parent: String = p[4]
		if parent == "" or not r.bodies.has(key):
			continue
		while parent != "" and not r.bodies.has(parent):
			parent = _parent_of(parent)
		if parent == "":
			continue
		var child_b: RigidBody3D = r.bodies[key]
		var pivot := (world.call(int(r.bone_of[key])) as Transform3D).origin
		var dir := child_b.global_transform.basis.y
		var ref2 := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var jz := dir.cross(ref2).normalized()
		var jy := jz.cross(dir).normalized()
		var j := ConeTwistJoint3D.new()
		r._holder.add_child(j)
		j.global_transform = Transform3D(Basis(dir, jy, jz), pivot)
		var lim: Array = LIMITS.get(key, [30, 10])
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(float(lim[0])))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(float(lim[1])))
		j.node_a = j.get_path_to(r.bodies[parent])
		j.node_b = j.get_path_to(child_b)
	# no self-collision between parts of the same body
	var list: Array = r.bodies.values()
	for i in list.size():
		for jj in range(i + 1, list.size()):
			(list[i] as PhysicsBody3D).add_collision_exception_with(list[jj])
	r.driver = Driver.new()
	r.driver.rd = r
	p_skel.add_child(r.driver)
	return r


static func _parent_of(key: String) -> String:
	for p in PARTS:
		if p[0] == key:
			return p[4]
	return ""


## Starts the simulation. impulse: world-space push (m/s scale) applied at hit_pos.
func start(velocity: Vector3, hit_pos: Vector3, impulse: Vector3) -> void:
	var nearest: RigidBody3D = null
	var nd := INF
	for key in bodies:
		var b: RigidBody3D = bodies[key]
		b.linear_velocity = velocity
		var d := b.global_position.distance_to(hit_pos)
		if d < nd:
			nd = d
			nearest = b
	if nearest and impulse.length() > 0.0:
		nearest.apply_central_impulse(impulse * nearest.mass * 2.0)
		for key in bodies:
			var b: RigidBody3D = bodies[key]
			if b != nearest:
				b.apply_central_impulse(impulse * b.mass * 0.4)


## Freezes the bodies once they've settled (saves CPU; the pose stays).
func settle() -> void:
	for key in bodies:
		var b: RigidBody3D = bodies[key]
		if is_instance_valid(b):
			b.freeze = true


func center() -> Vector3:
	if bodies.has("hips") and is_instance_valid(bodies.hips):
		return (bodies.hips as Node3D).global_position
	return skel.global_position


func debug_dump(tag: String) -> void:
	var line := "[ragdoll] %s " % tag
	for key in bodies:
		line += "%s=%s " % [key, (bodies[key] as Node3D).global_position.snapped(Vector3.ONE * 0.01)]
	print(line)
