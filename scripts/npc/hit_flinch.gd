class_name HitFlinch
extends SkeletonModifier3D
## Procedural hit reaction layered over any animation: a damped spring bends the
## spine / chest / head away from the impact direction.

var bones: Array[int] = []
var weights: Array[float] = []
var _axis := Vector3.RIGHT  # skeleton space
var _ang := 0.0
var _vel := 0.0


static func attach(skel: Skeleton3D) -> HitFlinch:
	var f := HitFlinch.new()
	var want := [["spine", 0.35], ["spine1", 0.25], ["spine2", 0.3], ["ribcage", 0.3], ["neck", 0.2], ["head", 0.35]]
	for w in want:
		for i in skel.get_bone_count():
			if AnimRetarget.norm(skel.get_bone_name(i)).ends_with(String(w[0])) and AnimRetarget.norm(skel.get_bone_name(i)).length() <= String(w[0]).length() + 4:
				if not f.bones.has(i):
					f.bones.append(i)
					f.weights.append(float(w[1]))
				break
	skel.add_child(f)
	return f


## dir_world: direction the hit travels (shooter -> target).
func kick(dir_world: Vector3, strength: float) -> void:
	var skel := get_skeleton()
	if skel == null or bones.is_empty():
		return
	var d := skel.global_basis.inverse() * dir_world
	var up := skel.global_basis.inverse() * Vector3.UP
	d = (d - up.normalized() * d.dot(up.normalized()))
	if d.length() < 0.001:
		return
	_axis = up.normalized().cross(d.normalized()).normalized()
	_vel += clampf(strength, 0.0, 1.5) * 7.0


func _process_modification_with_delta(delta: float) -> void:
	_vel += (-110.0 * _ang - 13.0 * _vel) * delta
	_ang += _vel * delta
	if absf(_ang) < 0.0005 and absf(_vel) < 0.001:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	for i in bones.size():
		var b := bones[i]
		var parent := skel.get_bone_parent(b)
		var pb := skel.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
		var la := (pb.inverse() * _axis)
		if la.length() < 0.0001:
			continue
		var q := Quaternion(la.normalized(), _ang * weights[i])
		skel.set_bone_pose_rotation(b, (q * skel.get_bone_pose_rotation(b)).normalized())
