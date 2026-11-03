extends LevelBase
## Title screen with a slow camera drift in front of the blast door.

var cam: Camera3D
var lamp: OmniLight3D
var ui: Control
var _t := 0.0
var _flicker := 0.0


func _ready() -> void:
	State.running = false
	State.context = "menu"
	HUD.set_mode("menu")
	Game.update_mouse()
	make_environment({
		"sky": false, "ambient": Color(0.09, 0.09, 0.1), "ambient_energy": 1.0,
		"fog": false, "vfog_density": 0.03,
		"vfog_albedo": Color(0.8, 0.8, 0.78), "exposure": 1.15, "glow": 0.6, "bloom": 0.05,
		"profile": {"vfog": true, "ssil": true},
	})
	_build_set()
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.current = true
	add_child(cam)
	_build_ui()
	Audio.play_music("music_menu", 3.0, -2.0)
	Audio.ambient("bg", "ambient_bunker", -10.0, 3.0)
	Settings.set_reverb(0.25, 0.7)


func _build_set() -> void:
	var wall := ShaderMaterial.new()
	wall.shader = load("res://shaders/bunker_wall.gdshader")
	BunkerBuilder.setup_wall_material(wall)
	var floor_m := Assets.pbr("concrete_floor", {"tile": 2.5, "fallback": Color(0.32, 0.32, 0.3)})
	Geo.box(self, Vector3(5, 0.3, 14), Vector3(0, -0.15, -3), floor_m)
	Geo.box(self, Vector3(5, 0.3, 14), Vector3(0, 3.35, -3), wall)
	Geo.box(self, Vector3(0.3, 3.5, 14), Vector3(-2.5, 1.6, -3), wall)
	Geo.box(self, Vector3(0.3, 3.5, 14), Vector3(2.5, 1.6, -3), wall)
	Geo.box(self, Vector3(5, 3.5, 0.3), Vector3(0, 1.6, -9.6), wall)
	var vd := Assets.vault_door(true)
	add_child(vd.root)
	# decorative face is model -Z: turn it toward the viewer, slab back on the wall
	(vd.root as Node3D).rotation.y = PI
	(vd.root as Node3D).position = Vector3(0.25, 0, -9.45 + 1.75)
	Geo.prop(self, "oil_barrel", Vector3(-1.7, 0, -6.5), 0.4)
	Geo.prop(self, "military_crate", Vector3(1.6, 0, -7.4), -0.3)
	Geo.prop(self, "fire_extinguisher", Vector3(2.1, 0, -5.0), 0.0)
	Geo.prop(self, "sandbags", Vector3(-1.4, 0, -2.5), 0.2)
	Geo.label3d(self, "OBIECTIVUL 17", Vector3(0, 3.0, -9.4), 0.0, 0.35, Color(0.9, 0.75, 0.3))
	lamp = Geo.omni(self, Vector3(0.6, 2.7, -6.8), Color(1.0, 0.78, 0.5), 3.2, 12.0)
	var fill := Geo.spot(self, Vector3(0.0, 2.9, -3.0), Vector3(0, -0.35, -1), Color(1.0, 0.85, 0.65), 2.5, 12.0, 38.0)
	fill.shadow_enabled = true
	var red := Geo.omni(self, Vector3(-1.9, 2.8, -1.0), Color(1.0, 0.12, 0.05), 0.5, 5.0)
	red.shadow_enabled = false
	Geo.prop(self, "lamp_cage", Vector3(0.6, 3.2 - 0.35, -6.8), 0.0, "none")
	Geo.dust(self, Vector3(0, 1.6, -5), Vector3(2.2, 1.5, 4.5), 220)


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	layer.add_child(ui)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.85))
	g.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size.x = 900
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(grad)

	var v := VBoxContainer.new()
	v.position = Vector2(120, 200)
	v.add_theme_constant_override("separation", 10)
	ui.add_child(v)
	var title := UITheme.heading("Bunker", 130, UITheme.TEXT)
	v.add_child(title)
	var sub := UITheme.heading("Ziua Zero", 40, UITheme.ACCENT)
	v.add_child(sub)
	v.add_child(UITheme.spacer(40))
	var cont := UITheme.button("Continuă", Game.continue_game, 340)
	cont.disabled = not State.has_save()
	v.add_child(cont)
	v.add_child(UITheme.button("Joc nou", _confirm_new, 340))
	v.add_child(UITheme.button("Setări", func() -> void: HUD.open_panel(SettingsPanel.new()), 340))
	v.add_child(UITheme.button("Comenzi", func() -> void: HUD.open_panel(ControlsPanel.new()), 340))
	v.add_child(UITheme.button("Credite", func() -> void: HUD.open_panel(CreditsPanel.new()), 340))
	v.add_child(UITheme.button("Ieșire", func() -> void: get_tree().quit(), 340))
	for b in v.get_children():
		if b is Button:
			(b as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT
	var ver := UITheme.label("v%s  ·  Godot %s" % [ProjectSettings.get_setting("application/config/version", "0.1"), Engine.get_version_info().string], 15, UITheme.TEXT_DIM, "mono")
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(120, -50)
	ui.add_child(ver)
	var tag := UITheme.label("„Ușa se închide. Lumea rămâne afară.”", 22, UITheme.TEXT_DIM)
	tag.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tag.position = Vector2(120, -100)
	ui.add_child(tag)


func _confirm_new() -> void:
	if State.has_save():
		HUD.choose("Joc nou", "Începi o poveste nouă? Salvarea existentă va fi suprascrisă la prima salvare.", [
			{"text": "Da, începe", "cb": Game.new_game},
			{"text": "Nu", "cb": func() -> void: pass},
		])
	else:
		Game.new_game()


func _process(delta: float) -> void:
	_t += delta
	cam.position = Vector3(sin(_t * 0.07) * 0.9, 1.55 + sin(_t * 0.11) * 0.08, 1.8 - sin(_t * 0.05) * 0.6)
	cam.look_at(Vector3(sin(_t * 0.05) * 0.3, 1.35, -9.0))
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = randf_range(0.04, 0.5) if randf() < 0.25 else randf_range(1.5, 5.0)
		lamp.light_energy = randf_range(0.4, 1.4) if randf() < 0.3 else 3.2
