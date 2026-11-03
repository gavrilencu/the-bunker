class_name AnimRetarget
extends RefCounted
## Runtime animation retargeting between humanoid rigs that share bone naming
## (Mixamo-style). Rotations are transferred relative to each rig's rest pose, the
## hips translation is converted through model space and rescaled.

static var _cache := {}  # "src|tgt-signature" -> AnimationLibrary


static func norm(n: String) -> String:
	var s := n.to_lower()
	for p in ["mixamorig:", "mixamorig_", "mixamorig"]:
		s = s.replace(p, "")
	var re := RegEx.create_from_string("_\\d+$")
	return re.sub(s, "")


static func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := find_skeleton(c)
		if r:
			return r
	return null


static func _chain(from: Node, to: Node) -> Transform3D:
	var t := Transform3D()
	var n := from
	while n and n != to:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _height(skel: Skeleton3D, model_xf: Transform3D) -> float:
	var lo := INF
	var hi := -INF
	for i in skel.get_bone_count():
		var y := (model_xf * skel.get_bone_global_rest(i)).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return maxf(hi - lo, 0.01)


## Adds the source model's clips (wanted: new_name -> source clip name) to the target
## AnimationPlayer as library "rt". Returns {new_name: "rt/new_name"} for clips that worked.
static func import_anims(target_root: Node3D, target_ap: AnimationPlayer, source_model_id: String, wanted: Dictionary) -> Dictionary:
	var tskel := find_skeleton(target_root)
	if tskel == null or target_ap == null or not Assets.has_model(source_model_id):
		return {}
	var src_root := Assets.model(source_model_id)
	var sap := Assets.find_animation_player(src_root)
	var sskel := find_skeleton(src_root)
	if sap == null or sskel == null:
		src_root.free()
		return {}
	var tmap := {}
	for i in tskel.get_bone_count():
		tmap[norm(tskel.get_bone_name(i))] = i
	var s_model := _chain(sskel, src_root)
	var t_model := _chain(tskel, target_root)
	var ratio := _height(tskel, t_model) / _height(sskel, s_model)
	var anim_root: Node = target_ap.get_node_or_null(target_ap.root_node)
	if anim_root == null:
		anim_root = target_root
	var skel_path := String(anim_root.get_path_to(tskel))
	var lib: AnimationLibrary
	if target_ap.has_animation_library("rt"):
		lib = target_ap.get_animation_library("rt")
	else:
		lib = AnimationLibrary.new()
		target_ap.add_animation_library("rt", lib)
	var out := {}
	for new_name in wanted:
		var src_name: String = wanted[new_name]
		if not sap.has_animation(src_name):
			continue
		var a := sap.get_animation(src_name)
		var na := Animation.new()
		na.length = a.length
		na.loop_mode = a.loop_mode
		for t in a.get_track_count():
			var tp := a.track_get_type(t)
			if tp != Animation.TYPE_ROTATION_3D and tp != Animation.TYPE_POSITION_3D:
				continue
			var bone_name := String(a.track_get_path(t).get_concatenated_subnames())
			var sb := sskel.find_bone(bone_name)
			if sb < 0:
				continue
			var key := norm(bone_name)
			if not tmap.has(key):
				continue
			var tb: int = tmap[key]
			var path := NodePath(skel_path + ":" + tskel.get_bone_name(tb))
			if tp == Animation.TYPE_ROTATION_3D:
				var nt := na.add_track(Animation.TYPE_ROTATION_3D)
				na.track_set_path(nt, path)
				na.track_set_interpolation_type(nt, Animation.INTERPOLATION_LINEAR)
				var rs := sskel.get_bone_rest(sb).basis.get_rotation_quaternion()
				var rt := tskel.get_bone_rest(tb).basis.get_rotation_quaternion()
				for k in a.track_get_key_count(t):
					var q: Quaternion = a.track_get_key_value(t, k)
					na.rotation_track_insert_key(nt, a.track_get_key_time(t, k), (rt * (rs.inverse() * q)).normalized())
			elif key == "hips":
				var nt := na.add_track(Animation.TYPE_POSITION_3D)
				na.track_set_path(nt, path)
				var sp := sskel.get_bone_parent(sb)
				var tpb := tskel.get_bone_parent(tb)
				var s_par := s_model.basis * (sskel.get_bone_global_rest(sp).basis if sp >= 0 else Basis())
				var t_par := t_model.basis * (tskel.get_bone_global_rest(tpb).basis if tpb >= 0 else Basis())
				var s_rest := sskel.get_bone_rest(sb).origin
				var t_rest := tskel.get_bone_rest(tb).origin
				var conv := t_par.inverse() * s_par
				for k in a.track_get_key_count(t):
					var p: Vector3 = a.track_get_key_value(t, k)
					na.position_track_insert_key(nt, a.track_get_key_time(t, k), t_rest + conv * (p - s_rest) * ratio)
		if lib.has_animation(new_name):
			lib.remove_animation(new_name)
		lib.add_animation(new_name, na)
		out[new_name] = "rt/" + new_name
	src_root.free()
	return out
