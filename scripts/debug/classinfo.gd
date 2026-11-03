extends SceneTree
func _init() -> void:
	for c in ["Skeleton3D", "ConeTwistJoint3D"]:
		var ms := []
		for m in ClassDB.class_get_method_list(c, true):
			if String(m.name).contains("global_pose") or String(m.name).contains("param") or String(m.name).contains("flag"):
				ms.append(m.name)
		print(c, ": ", ms)
	quit()
