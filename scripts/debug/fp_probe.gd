extends SceneTree
## Dev probe: loads a first-person rig, prints its structure and renders frames.
## godot --path . -s res://scripts/debug/fp_probe.gd -- --id=fps_pistol --out=<dir>

var args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_run.call_deferred()


func _dump(n: Node, d: int, maxd: int) -> void:
	if d > maxd:
		return
	var extra := ""
	if n is Node3D:
		extra = " pos=%s" % str((n as Node3D).global_position.snapped(Vector3.ONE * 0.001))
	if n is MeshInstance3D:
		extra += " aabb=%s" % str((n as MeshInstance3D).get_aabb().size.snapped(Vector3.ONE * 0.001))
	if n is BoneAttachment3D:
		extra += " bone=%s" % (n as BoneAttachment3D).bone_name
	print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_dump(c, d + 1, maxd)


func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n):
		return n
	for c in n.get_children():
		var r := _find(c, pred)
		if r:
			return r
	return null


func _run() -> void:
	var id: String = args.get("id", "fps_pistol")
	var out: String = args.get("out", "user://")
	root.size = Vector2i(1280, 720)
	var ps: PackedScene = load(args.get("path", "res://assets/models/%s/%s.glb" % [id, id]))
	var rig: Node3D = ps.instantiate()
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(rig)
	await process_frame
	if args.has("strip"):
		_strip(rig, String(args.strip))
	_dump(rig, 0, int(args.get("depth", "7")))
	var skel: Skeleton3D = _find(rig, func(n: Node) -> bool: return n is Skeleton3D)
	if skel:
		var names := []
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
		print("BONES ", names)
		print("skel global scale ", skel.global_transform.basis.get_scale())
	var ap: AnimationPlayer = _find(rig, func(n: Node) -> bool: return n is AnimationPlayer)
	print("ANIMS ", ap.get_animation_list() if ap else [])
	var camnode: Node3D = _find(rig, func(n: Node) -> bool: return n is Node3D and String(n.name) == "Camera")
	var cam_bone := -1
	if skel:
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower().begins_with("head_cam") and not skel.get_bone_name(i).to_lower().contains("end"):
				cam_bone = i
		if ap and ap.get_animation_list().size() > 0:
			ap.play(ap.get_animation_list()[0])
			ap.seek(0.0, true)
		await process_frame
		for key in ["Head_Cam", "Hand_R", "Hand_L", "Body", "Root", "Arm_R", "Forearm_R", "Mag"]:
			for i in skel.get_bone_count():
				if skel.get_bone_name(i).begins_with(key + "_") or skel.get_bone_name(i) == key:
					var gt: Transform3D = skel.global_transform * skel.get_bone_global_pose(i)
					print("BONE ", skel.get_bone_name(i), " o=", gt.origin.snapped(Vector3.ONE * 0.001), " x=", gt.basis.x.normalized().snapped(Vector3.ONE * 0.01), " y=", gt.basis.y.normalized().snapped(Vector3.ONE * 0.01), " z=", gt.basis.z.normalized().snapped(Vector3.ONE * 0.01))
					break
	var cam_axis: String = args.get("axis", "y")
	# lights
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.37, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.62)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = float(args.get("sun", "1.6"))
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = float(args.get("fov", "60"))
	cam.near = 0.01
	world.add_child(cam)
	cam.current = true
	var anims: Array = ap.get_animation_list() if ap and not args.has("noshots") else []
	var times := [0.0, 0.3, 0.6] if not args.has("one") else [0.0]
	var shots := 0
	for an in anims:
		var a := ap.get_animation(an)
		for f in times:
			ap.play(an)
			ap.seek(a.length * f, true)
			ap.pause()
			await process_frame
			if camnode:
				cam.global_transform = camnode.global_transform.orthonormalized()
			elif cam_bone >= 0:
				var gt: Transform3D = (skel.global_transform * skel.get_bone_global_pose(cam_bone)).orthonormalized()
				var fwd: Vector3 = {"y": gt.basis.y, "-y": -gt.basis.y, "z": gt.basis.z, "-z": -gt.basis.z, "x": gt.basis.x, "-x": -gt.basis.x}[cam_axis]
				var up: Vector3 = {"y": gt.basis.z, "-y": gt.basis.z, "z": gt.basis.y, "-z": gt.basis.y, "x": gt.basis.y, "-x": gt.basis.y}[cam_axis]
				if args.has("flipup"):
					up = -up
				cam.global_transform = Transform3D(Basis.looking_at(fwd, up), gt.origin)
			if shots == 0:
				print("CAM ", cam.global_transform)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.save_jpg("%s/%s_%s_%d.jpg" % [out, id, String(an).replace("|", "_"), int(f * 10)], 0.85)
			shots += 1
	quit()



func _strip(n: Node, what: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				match what:
					"albedo": d.albedo_texture = null
					"metal": d.metallic_texture = null
					"rough": d.roughness_texture = null
					"ao": d.ao_enabled = false
					"normal": d.normal_enabled = false
				print("strip ", what, " rough_tex=", (m as StandardMaterial3D).roughness_texture, " ao_tex=", (m as StandardMaterial3D).ao_texture, " ao_ch=", (m as StandardMaterial3D).ao_texture_channel)
				mi.set_surface_override_material(i, d)
	for c in n.get_children():
		_strip(c, what)
