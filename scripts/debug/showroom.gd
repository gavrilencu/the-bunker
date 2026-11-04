extends SceneTree
## Dev probe: lines models up (fronts should face +Z = toward the camera) and renders them.
## godot --path . -s res://scripts/debug/showroom.gd -- --ids=a,b,c --out=<file.png> [--side]

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			args[a.substr(2)] = true
	root.size = Vector2i(1800, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.52, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	floor.mesh = pm
	world.add_child(floor)
	var ids: PackedStringArray = String(args.get("ids", "")).split(",")
	var cols := int(args.get("cols", "6"))
	var sp := float(args.get("spacing", "2.6"))
	for i in ids.size():
		var id := ids[i]
		var path := "res://assets/models/%s/%s.glb" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var m: Node3D = (load(path) as PackedScene).instantiate()
		world.add_child(m)
		var cx := (i % cols - (cols - 1) * 0.5) * sp
		var cz := -(i / cols) * sp * 1.1
		m.position = Vector3(cx, 0, cz)
		var l := Label3D.new()
		l.text = id
		l.font_size = 48
		l.pixel_size = 0.004
		l.position = Vector3(cx, 2.3, cz)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(0, 0, 0)
		world.add_child(l)
	var cam := Camera3D.new()
	world.add_child(cam)
	var rows := int(ceil(float(ids.size()) / cols))
	var span := cols * sp
	var dist := span * 0.75
	if args.has("side"):
		cam.position = Vector3(span * 0.55, 3.2, dist * 0.55 - rows * sp * 0.4)
		cam.look_at(Vector3(0, 0.8, -rows * sp * 0.45))
	else:
		cam.position = Vector3(0, 2.6 + rows * 0.8, dist)
		cam.look_at(Vector3(0, 0.6, -rows * sp * 0.45))
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(String(args.get("out", "user://showroom.png")))
	quit()
