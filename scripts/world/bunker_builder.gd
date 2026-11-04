class_name BunkerBuilder
extends RefCounted
## Shared bunker-look helpers (wall shader setup).

const WALL_SHADER := preload("res://shaders/bunker_wall.gdshader")


static func wall_material(paint := Color(0.2, 0.31, 0.26), band := true, grime := 0.55) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	setup_wall_material(m, paint, band, grime)
	return m


static func setup_wall_material(m: ShaderMaterial, paint := Color(0.2, 0.31, 0.26), band := true, grime := 0.55) -> void:
	# smooth cast concrete with formwork joints (the board-formed set read as wood planks)
	var dir := "res://assets/textures/bunker_wall/" if Assets.has_texture_set("bunker_wall") else "res://assets/textures/concrete_wall/"
	var alb: Texture2D = null
	var nrm: Texture2D = null
	var rgh: Texture2D = null
	for ext in [".jpg", ".png"]:
		if alb == null:
			alb = Assets.texture(dir + "albedo" + ext)
		if nrm == null:
			nrm = Assets.texture(dir + "normal" + ext)
		if rgh == null:
			rgh = Assets.texture(dir + "roughness" + ext)
	var ok := alb != null and nrm != null and rgh != null
	m.set_shader_parameter("has_textures", ok)
	if ok:
		m.set_shader_parameter("tex_albedo", alb)
		m.set_shader_parameter("tex_normal", nrm)
		m.set_shader_parameter("tex_rough", rgh)
	m.set_shader_parameter("paint_color", paint)
	m.set_shader_parameter("band_enabled", 1.0 if band else 0.0)
	m.set_shader_parameter("grime", grime)
