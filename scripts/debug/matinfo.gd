extends SceneTree
## Dev probe: prints the imported materials of a model.  -s res://scripts/debug/matinfo.gd -- --id=fps_rifle

func _init() -> void:
	var id := "fps_rifle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			id = a.substr(5)
	var ps: PackedScene = load("res://assets/models/%s/%s.glb" % [id, id])
	var n := ps.instantiate()
	_walk(n)
	quit()


func _walk(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var s := m as StandardMaterial3D
				print(mi.name, " #", i, " albedo=", s.albedo_color, " tex=", s.albedo_texture.resource_path if s.albedo_texture else "-",
					" metal=", s.metallic, " mtex=", s.metallic_texture.resource_path if s.metallic_texture else "-", " ch=", s.metallic_texture_channel,
					" rough=", s.roughness, " rch=", s.roughness_texture_channel, " normal=", s.normal_enabled, " ao=", s.ao_enabled,
					" emis=", s.emission_enabled, " rim=", s.rim_enabled, " cc=", s.clearcoat_enabled, " ss=", s.subsurf_scatter_enabled,
					" spec=", s.metallic_specular, " trans=", s.transparency, " cull=", s.cull_mode)
			else:
				print(mi.name, " #", i, " ", m)
	for c in n.get_children():
		_walk(c)
