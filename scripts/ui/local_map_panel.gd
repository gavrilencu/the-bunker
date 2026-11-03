class_name LocalMapPanel
extends UIPanel
## PDA-style local map: a top-down orthographic render of the real level
## (captured once per opening) with tactical overlays.

class MapView extends Control:
	var tex: Texture2D
	func _init() -> void:
		clip_contents = true
	var center := Vector2.ZERO  # world XZ at map centre
	var extent := 100.0         # metres across
	var markers: Array = []     # [{pos(Vector3), icon, color, label, small}]
	var player_pos := Vector3.ZERO
	var player_yaw := 0.0
	var labels: Array = []      # [{pos, text}]
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func w2m(p: Vector3) -> Vector2:
		var u := (p.x - (center.x - extent * 0.5)) / extent
		var v := (p.z - (center.y - extent * 0.5)) / extent
		return Vector2(u, v) * size

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.035, 0.03))
		if tex:
			draw_texture_rect(tex, r, false, Color(0.95, 1.0, 0.92))
		# tint + scanline-ish grid
		draw_rect(r, Color(0.12, 0.16, 0.1, 0.18))
		var step := size.x / 10.0
		for i in 11:
			var x := i * step
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.7, 0.9, 0.6, 0.12), 1.0)
			draw_line(Vector2(0, x), Vector2(size.x, x), Color(0.7, 0.9, 0.6, 0.12), 1.0)
		var f := Assets.font("mono")
		for i in 10:
			draw_string(f, Vector2(i * step + 4, 14), char(65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.9, 0.7, 0.6))
			draw_string(f, Vector2(4, i * step + 28), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.9, 0.7, 0.6))
		for l in labels:
			var lp := w2m(l.pos)
			draw_string(Assets.font("heading"), lp + Vector2(-80, 0), String(l.text).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(0.92, 0.9, 0.8, 0.85))
		for m in markers:
			var mp := w2m(m.pos)
			var col: Color = m.color
			var s: float = 12.0 if m.get("small", false) else 20.0
			if m.get("ring", 0.0) > 0.0:
				var rr: float = m.ring / extent * size.x
				draw_circle(mp, rr, Color(col, 0.16))
				draw_arc(mp, rr, 0, TAU, 40, Color(col, 0.6), 1.5, true)
			draw_circle(mp, s * 0.6, Color(0, 0, 0, 0.55))
			HudIcons.draw(self, m.icon, Rect2(mp - Vector2(s, s) * 0.5, Vector2(s, s)), col, 1.6)
			if m.get("label", "") != "":
				draw_string(Assets.font("bold"), mp + Vector2(-90, s * 0.5 + 14), m.label, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, col)
		# player arrow (pulsing)
		var pp := w2m(player_pos)
		var a := player_yaw
		var fwd := Vector2(-sin(a), -cos(a))
		var right := Vector2(fwd.y, -fwd.x) * -1.0
		var k := 1.0 + 0.12 * sin(_t * 5.0)
		draw_arc(pp, 16.0 * k, 0, TAU, 32, Color(UITheme.ACCENT, 0.35), 2.0, true)
		var tri := PackedVector2Array([pp + fwd * 14.0, pp - fwd * 8.0 + right * 8.0, pp - fwd * 4.0, pp - fwd * 8.0 - right * 8.0])
		draw_colored_polygon(tri, UITheme.ACCENT)
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.8), 1.5, true)
		# frame + north
		draw_rect(r, Color(UITheme.ACCENT, 0.6), false, 2.0)
		draw_string(Assets.font("heading"), Vector2(size.x - 40, 30), "N", HORIZONTAL_ALIGNMENT_CENTER, 24, 20, UITheme.ACCENT)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - 28, 36), Vector2(size.x - 22, 50), Vector2(size.x - 34, 50)]), UITheme.ACCENT)
		# scale bar (10 m)
		var px10 := 10.0 / extent * size.x
		draw_line(Vector2(20, size.y - 20), Vector2(20 + px10, size.y - 20), Color.WHITE, 2.0)
		draw_string(f, Vector2(20, size.y - 28), "10 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


var level: Node
var view: MapView
var legend: VBoxContainer


func _init(p_level: Node) -> void:
	level = p_level
	super("PDA · Harta zonei", 1240.0)


func build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	view = MapView.new()
	view.custom_minimum_size = Vector2(760, 760)
	row.add_child(view)
	legend = VBoxContainer.new()
	legend.custom_minimum_size = Vector2(400, 0)
	legend.add_theme_constant_override("separation", 8)
	row.add_child(legend)
	Audio.sfx("map_open", -4.0)
	var cfg: Dictionary = level.map_config()
	view.center = cfg.center
	view.extent = cfg.extent
	_capture(cfg)


func _capture(cfg: Dictionary) -> void:
	var cache: Texture2D = level.get_meta("map_tex") if level.has_meta("map_tex") else null
	if cache and not cfg.get("live", false):
		view.tex = cache
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.world_3d = level.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cfg.extent
	cam.near = 0.05
	cam.far = cfg.get("far", 300.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.72)
	env.ambient_light_energy = cfg.get("ambient", 0.8)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	cam.environment = env
	vp.add_child(cam)
	add_child(vp)
	cam.global_position = Vector3(cfg.center.x, cfg.height, cfg.center.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	view.tex = ImageTexture.create_from_image(img)
	level.set_meta("map_tex", view.tex)


func refresh() -> void:
	var cfg: Dictionary = level.map_config()
	view.markers = cfg.markers
	view.labels = cfg.get("labels", [])
	var p = Game.player
	if p and is_instance_valid(p):
		view.player_pos = p.global_position
		view.player_yaw = p.rotation.y
	clear(legend)
	legend.add_child(UITheme.heading(cfg.title, 24, UITheme.TEXT))
	legend.add_child(UITheme.label(cfg.get("subtitle", ""), 15, UITheme.TEXT_DIM))
	legend.add_child(UITheme.spacer(6))
	for l in cfg.get("legend", []):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var ic := InventoryPanel.IconBox.new()
		ic.icon = l[0]
		ic.col = l[1]
		ic.custom_minimum_size = Vector2(20, 20)
		r.add_child(ic)
		r.add_child(UITheme.label(l[2], 16, UITheme.TEXT))
		legend.add_child(r)
	legend.add_child(UITheme.spacer(10))
	for line in cfg.get("info", []):
		var l := UITheme.label(line, 15, UITheme.TEXT_DIM, "mono")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 390
		legend.add_child(l)
