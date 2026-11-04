extends CanvasLayer
## Persistent HUD (STALKER-2-style), overlays, loading screen and modal panel stack.


var mode := "none"
## Objective marker (Vector3) or null.
var waypoint = null
## Extra compass markers: id -> {pos, color, icon}
var markers := {}
var rad_effect := 0.0
var mask_effect := 0.0

const POST_SHADER := preload("res://shaders/post.gdshader")
const POST_BLUR_SHADER := preload("res://shaders/post_blur.gdshader")

var post_layer: CanvasLayer
var post: ColorRect
var post_mat: ShaderMaterial
var root: Control
var panel_root: Control
var top_layer: CanvasLayer
var fade_rect: ColorRect

var compass: HudWidgets.Compass
var clock: HudWidgets.Clock
var vitals: HudWidgets.Vitals
var weapon_box: HudWidgets.WeaponBox
var dosimeter: HudWidgets.Dosimeter
var systems: HudWidgets.Systems
var reticle: HudWidgets.Reticle
var prompt: HudWidgets.Prompt
var objective_w: HudWidgets.Objective
var toast_box: VBoxContainer
var subtitle_panel: PanelContainer
var subtitle_label: RichTextLabel
var banner_box: Control
var banner_title: Label
var banner_sub: Label
var banner_line: ColorRect
var alert_panel: PanelContainer
var alert_title: Label
var alert_text: Label
var perf_label: Label
var place_bar: HudWidgets.PlaceBar

# loading screen
var loading: Control
var load_title: Label
var load_tip: Label
var load_bar: ProgressBar
var load_pct: Label
var load_spinner: Control

var panels: Array[UIPanel] = []
var _sub_timer := 0.0
var _damage := 0.0
var _flash := 0.0
var _blur := 0.0
var _weapon_sig := ""
var _surface := {"filter": 360.0, "spare": 0, "rate": 0.0, "weight": 0.0, "cap": 30.0}

const TIPS := [
	"Radiația de la suprafață scade în fiecare zi. Primele zile sunt cele mai periculoase.",
	"Un filtru de mască ține aproximativ 6 minute. Ia mereu unul de rezervă.",
	"Ciupercile cresc în întuneric — nu consumă energie pentru lumină.",
	"Oprește generatorul noaptea ca să economisești motorină. Bateriile țin lumina de avarie.",
	"Bandajele opresc sângerarea. Nu pleca niciodată fără ele.",
	"Supraîncărcarea te încetinește și îți taie sprintul. Lasă prada în depozit.",
	"Jefuitorii trag de la distanță — folosește ruinele ca acoperire.",
	"Câinii mutanți atacă în haită și sunt mai rapizi decât tine.",
	"Zombii în costum de protecție emit radiație. Nu-i lăsa să se apropie.",
	"Radioul prinde mesaje noi aproape în fiecare zi. Ascultă-l.",
	"Săpatul prin dărâmături deschide camere noi, cu provizii uitate.",
]


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	State.notify.connect(toast)
	State.item_gained.connect(_item_toast)
	Settings.changed.connect(_apply_post_settings)
	_apply_post_settings()
	set_mode("none")


func _anchored(c: Control, preset: Control.LayoutPreset, pos: Vector2, sz: Vector2) -> Control:
	c.set_anchors_preset(preset)
	c.size = sz
	c.position = pos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _build() -> void:
	post_layer = CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	# start with the blur variant so its pipeline compiles during the menu, not on the
	# first panel; _process swaps to the cheap one right away
	post_mat.shader = POST_BLUR_SHADER
	post.material = post_mat
	post_layer.add_child(post)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)

	compass = _anchored(HudWidgets.Compass.new(), Control.PRESET_CENTER_TOP, Vector2(-380, 14), Vector2(760, 64))
	clock = _anchored(HudWidgets.Clock.new(), Control.PRESET_TOP_LEFT, Vector2(44, 22), Vector2(420, 60))
	objective_w = _anchored(HudWidgets.Objective.new(), Control.PRESET_TOP_RIGHT, Vector2(-474, 28), Vector2(440, 140))
	vitals = _anchored(HudWidgets.Vitals.new(), Control.PRESET_BOTTOM_LEFT, Vector2(44, -176), Vector2(420, 140))
	weapon_box = _anchored(HudWidgets.WeaponBox.new(), Control.PRESET_BOTTOM_RIGHT, Vector2(-384, -150), Vector2(340, 120))
	dosimeter = _anchored(HudWidgets.Dosimeter.new(), Control.PRESET_BOTTOM_RIGHT, Vector2(-384, -288), Vector2(340, 114))
	systems = _anchored(HudWidgets.Systems.new(), Control.PRESET_BOTTOM_RIGHT, Vector2(-404, -246), Vector2(360, 200))
	reticle = _anchored(HudWidgets.Reticle.new(), Control.PRESET_CENTER, Vector2(-200, -200), Vector2(400, 400))
	prompt = _anchored(HudWidgets.Prompt.new(), Control.PRESET_CENTER, Vector2(-350, 36), Vector2(700, 60))

	toast_box = VBoxContainer.new()
	toast_box.add_theme_constant_override("separation", 4)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	_anchored(toast_box, Control.PRESET_CENTER_RIGHT, Vector2(-474, -170), Vector2(440, 220))

	subtitle_panel = PanelContainer.new()
	var sb := UITheme.flat(Color(0, 0, 0, 0.55), 0, Color.TRANSPARENT, 2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	subtitle_panel.add_theme_stylebox_override("panel", sb)
	subtitle_panel.custom_minimum_size = Vector2(980, 0)
	_anchored(subtitle_panel, Control.PRESET_CENTER_BOTTOM, Vector2(-490, -250), Vector2(980, 50))
	subtitle_label = RichTextLabel.new()
	subtitle_label.bbcode_enabled = true
	subtitle_label.fit_content = true
	subtitle_label.scroll_active = false
	subtitle_label.custom_minimum_size = Vector2(936, 0)
	subtitle_label.add_theme_font_size_override("normal_font_size", 22)
	subtitle_label.add_theme_font_size_override("bold_font_size", 22)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_panel.add_child(subtitle_label)
	subtitle_panel.visible = false

	place_bar = _anchored(HudWidgets.PlaceBar.new(), Control.PRESET_CENTER_BOTTOM, Vector2(-700, -150), Vector2(1400, 110))

	# location / chapter banner
	banner_box = Control.new()
	_anchored(banner_box, Control.PRESET_CENTER, Vector2(-700, -250), Vector2(1400, 220))
	banner_line = ColorRect.new()
	banner_line.color = UITheme.ACCENT
	banner_line.position = Vector2(700 - 160, 112)
	banner_line.size = Vector2(320, 2)
	banner_box.add_child(banner_line)
	banner_title = UITheme.heading("", 72, UITheme.TEXT)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.size = Vector2(1400, 100)
	banner_title.position = Vector2(0, 8)
	banner_box.add_child(banner_title)
	banner_sub = UITheme.label("", 22, UITheme.TEXT_DIM)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.size = Vector2(1400, 80)
	banner_sub.position = Vector2(0, 124)
	banner_box.add_child(banner_sub)
	banner_box.modulate.a = 0.0

	alert_panel = PanelContainer.new()
	var asb := UITheme.flat(Color(0.1, 0.015, 0.015, 0.92), 0, UITheme.DANGER, 2)
	asb.border_width_left = 4
	asb.content_margin_left = 22
	asb.content_margin_right = 22
	asb.content_margin_top = 14
	asb.content_margin_bottom = 16
	alert_panel.add_theme_stylebox_override("panel", asb)
	alert_panel.custom_minimum_size = Vector2(660, 0)
	_anchored(alert_panel, Control.PRESET_CENTER_TOP, Vector2(-330, -260), Vector2(660, 120))
	var av := VBoxContainer.new()
	alert_panel.add_child(av)
	alert_title = UITheme.heading("", 26, UITheme.DANGER)
	av.add_child(alert_title)
	alert_text = UITheme.label("", 19, UITheme.TEXT)
	alert_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_text.custom_minimum_size.x = 610
	av.add_child(alert_text)
	alert_panel.visible = false

	perf_label = UITheme.label("", 13, UITheme.TEXT_DIM, "mono")
	perf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchored(perf_label, Control.PRESET_TOP_RIGHT, Vector2(-330, 4), Vector2(320, 90))

	panel_root = Control.new()
	panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.theme = UITheme.get_theme()
	add_child(panel_root)

	top_layer = CanvasLayer.new()
	top_layer.layer = 100
	add_child(top_layer)
	_build_loading()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(fade_rect)


class Spinner extends Control:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 26, 0, TAU, 48, Color(1, 1, 1, 0.08), 3.0, true)
		draw_arc(c, 26, t * 3.0, t * 3.0 + 1.6, 32, UITheme.ACCENT, 3.0, true)
		draw_set_transform(c, t * 0.6, Vector2.ONE)
		HudIcons.draw(self, "rad", Rect2(-14, -14, 28, 28), Color(UITheme.ACCENT, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_loading() -> void:
	loading = Control.new()
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	loading.theme = UITheme.get_theme()
	loading.visible = false
	top_layer.add_child(loading)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.016, 0.015)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.35, 0.2, 0.06, 0.35))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.2, 0.85)
	gt.fill_to = Vector2(0.9, 0.1)
	glow.texture = gt
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	loading.add_child(glow)
	var brand := UITheme.heading("Bunker · Ziua Zero", 18, UITheme.TEXT_DIM)
	brand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	brand.position = Vector2(80, 60)
	loading.add_child(brand)
	load_title = UITheme.heading("", 64, UITheme.TEXT)
	load_title.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	load_title.position = Vector2(80, -250)
	load_title.size = Vector2(1400, 90)
	loading.add_child(load_title)
	load_tip = UITheme.label("", 21, UITheme.TEXT_DIM)
	load_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load_tip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	load_tip.position = Vector2(80, -160)
	load_tip.size = Vector2(1000, 60)
	loading.add_child(load_tip)
	load_bar = UITheme.bar(UITheme.ACCENT, 3)
	load_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	load_bar.offset_left = 80
	load_bar.offset_right = -80
	load_bar.offset_top = -80
	load_bar.offset_bottom = -77
	loading.add_child(load_bar)
	load_pct = UITheme.label("", 14, UITheme.TEXT_DIM, "mono")
	load_pct.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	load_pct.position = Vector2(80, -70)
	loading.add_child(load_pct)
	load_spinner = Spinner.new()
	load_spinner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	load_spinner.size = Vector2(64, 64)
	load_spinner.position = Vector2(-150, -170)
	loading.add_child(load_spinner)


func show_loading(title: String) -> void:
	load_title.text = title.to_upper()
	load_tip.text = "SFAT:  " + TIPS[randi() % TIPS.size()]
	load_bar.value = 0
	load_pct.text = "SE ÎNCARCĂ  0%"
	loading.visible = true


func set_loading_progress(p: float, what := "") -> void:
	load_bar.value = p * 100.0
	load_pct.text = "SE ÎNCARCĂ  %d%%%s" % [roundi(p * 100.0), ("  ·  " + what) if what != "" else ""]


func hide_loading() -> void:
	loading.visible = false


# --------------------------------------------------------------------------
# Modes / per-frame update
# --------------------------------------------------------------------------

## modes: none, menu, intro, bunker, surface
func set_mode(m: String) -> void:
	mode = m
	var gameplay := m in ["intro", "bunker", "surface"]
	reticle.visible = gameplay
	prompt.visible = gameplay
	compass.visible = m in ["intro", "surface"]
	clock.visible = m in ["bunker", "surface"]
	vitals.visible = m in ["bunker", "surface"]
	weapon_box.visible = m == "surface"
	dosimeter.visible = m == "surface"
	systems.visible = m == "bunker"
	objective_w.visible = gameplay
	set_placement({})
	if not gameplay:
		set_interaction("", "", false, 0.0)
		objective("")
	post_mat.set_shader_parameter("mask", 0.0)
	post_mat.set_shader_parameter("tint", Vector3.ONE)
	rad_effect = 0.0
	mask_effect = 0.0
	waypoint = null
	markers.clear()


func _apply_post_settings() -> void:
	post_mat.set_shader_parameter("grain", 0.035 if int(Settings.opt("grain")) == 1 else 0.0)
	post_mat.set_shader_parameter("aberration", 0.9 if int(Settings.opt("aberration")) == 1 else 0.0)
	post_mat.set_shader_parameter("vignette", 0.38 if int(Settings.opt("vignette")) == 1 else 0.12)


func _process(delta: float) -> void:
	_damage = maxf(_damage - delta * 0.9, 0.0)
	_flash = maxf(_flash - delta * 0.6, 0.0)
	var low_hp := State.health < 25.0 and mode in ["bunker", "surface"]
	post_mat.set_shader_parameter("damage", _damage + (0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)) if low_hp else 0.0))
	post_mat.set_shader_parameter("flash", clampf(_flash, 0.0, 1.0))
	post_mat.set_shader_parameter("rad", rad_effect)
	post_mat.set_shader_parameter("mask", mask_effect)
	post_mat.set_shader_parameter("mask_fog", clampf(1.0 - State.mask_filter_left / 60.0, 0.0, 1.0) * 0.6 if mask_effect > 0.0 else 0.0)
	var want_blur := 2.2 if (has_panel() and top_panel().blur_world and mode in ["intro", "bunker", "surface", "menu"]) else 0.0
	_blur = move_toward(_blur, want_blur, delta * 10.0)
	# the mipmapped (blurrable) shader only while a panel blurs the world
	var want_shader: Shader = POST_BLUR_SHADER if _blur > 0.001 else POST_SHADER
	if post_mat.shader != want_shader:
		post_mat.shader = want_shader
	post_mat.set_shader_parameter("blur", _blur)
	post_mat.set_shader_parameter("desat", (State.radiation / 1500.0 if mode in ["bunker", "surface"] else 0.0) + (0.15 if low_hp else 0.0) + _blur * 0.08)
	_update_perf()
	if _sub_timer > 0.0:
		_sub_timer -= delta
		if _sub_timer <= 0.0:
			subtitle_panel.visible = false
	var hud_mode := int(Settings.opt("hud"))  # 0 full, 1 dynamic, 2 minimal
	objective_w.dist = -1.0
	var p = Game.player
	reticle.tick(delta)
	objective_w.tick(delta)
	if p and is_instance_valid(p):
		reticle.weapon = p.combat_enabled and p.weapons.is_gun() and p.weapons.ads < 0.5
		reticle.spread = p.spread
		reticle.visible = mode in ["intro", "bunker", "surface"] and p.weapons.ads < 0.7
	if compass.visible:
		_update_compass(p)
	if clock.visible:
		clock.day = State.day
		clock.time = State.clock_text()
		clock.night = State.is_night()
		clock.place = "Obiectivul 17" if State.context == "bunker" else ItemDB.LOCATIONS.get(State.current_location, {}).get("name", "Suprafața")
		clock.visible = hud_mode != 2 or mode == "bunker"
		clock.queue_redraw()
	if vitals.visible:
		_update_vitals(delta, p, hud_mode)
	if systems.visible:
		_update_systems()
	if weapon_box.visible or mode == "surface":
		_update_weapon(delta, p, hud_mode)
	if dosimeter.visible:
		dosimeter.has_geiger = State.count("geiger") > 0
		dosimeter.rate = _surface.rate
		dosimeter.dose = State.radiation
		dosimeter.filter_s = State.mask_filter_left
		dosimeter.spare = State.count("mask_filter")
		dosimeter.weight = State.total_weight()
		dosimeter.cap = State.carry_max
		dosimeter.queue_redraw()


func _update_compass(p) -> void:
	if p == null or not is_instance_valid(p):
		return
	var yaw: float = p.rotation.y
	compass.heading = fposmod(-rad_to_deg(yaw), 360.0)
	var list: Array = []
	var from: Vector3 = p.global_position
	var all := markers.duplicate()
	if waypoint != null:
		all["_objective"] = {"pos": waypoint, "color": UITheme.ACCENT, "icon": "objective"}
	for k in all:
		var m: Dictionary = all[k]
		var to: Vector3 = m.pos
		var d := to - from
		var bearing := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)
		list.append({"bearing": bearing, "color": m.color, "icon": m.icon, "dist": Vector2(d.x, d.z).length()})
	compass.markers = list
	objective_w.dist = from.distance_to(waypoint) if waypoint != null else -1.0
	compass.queue_redraw()


func _update_vitals(delta: float, p, hud_mode: int) -> void:
	vitals.hp = State.health / 100.0
	vitals.stamina = (p.stamina / 100.0) if p and is_instance_valid(p) else 1.0
	vitals.needs = {"food": State.food / 100.0, "water": State.hydration / 100.0, "energy": State.energy / 100.0}
	vitals.dynamic = hud_mode >= 1
	vitals.show_needs = hud_mode != 2
	var st: Array = []
	var add := func(icon: String, lvl: int, value = null) -> void:
		var e := {"icon": icon, "level": lvl}
		if value != null:
			e["value"] = value
		st.append(e)
	if State.bleeding > 0.0:
		add.call("bleed", 2, "×%d" % ceili(State.bleeding))
	if State.radiation > 80.0:
		add.call("rad", 2 if State.radiation > 250.0 else 1, roundi(State.radiation))
	if State.food < 35.0:
		add.call("food", 2 if State.food < 15.0 else 1)
	if State.hydration < 35.0:
		add.call("water", 2 if State.hydration < 15.0 else 1)
	if State.energy < 30.0:
		add.call("fatigue", 2 if State.energy < 12.0 else 1)
	var over := State.overweight()
	if over > 0.0:
		add.call("weight", 2 if over >= 15.0 else 1, "%d" % roundi(State.total_weight()))
	if State.context == "bunker" and State.air_quality < 45.0:
		add.call("air", 2 if State.air_quality < 30.0 else 1, "%d%%" % roundi(State.air_quality))
	if State.context == "surface" and State.mask_filter_left < 60.0:
		add.call("filter", 2, "%ds" % int(State.mask_filter_left))
	vitals.statuses = st
	var active: bool = State.health < 99.0 or not st.is_empty() or (p and is_instance_valid(p) and p.stamina < 99.0) or vitals.needs.values().any(func(x) -> bool: return x < 0.55)
	vitals.update_fade(delta, active, hud_mode >= 1, 5.0)
	vitals.tick(delta)
	weapon_box.tick(delta)


func _update_systems() -> void:
	var ps := State.power_state()
	var rows: Array = []
	rows.append({"icon": "fuel", "label": "MOTORINĂ", "value": State.fuel / State.FUEL_MAX, "text": "%.1f L" % State.fuel, "level": 2 if State.fuel < 4.0 else (1 if State.fuel < 10.0 else 0)})
	rows.append({"icon": "power", "label": "GENERATOR", "value": 1.0 if ps == "gen" else 0.0, "text": "PORNIT" if ps == "gen" else "OPRIT", "level": 0 if ps == "gen" else 2})
	rows.append({"icon": "battery", "label": "BATERII", "value": State.battery / State.battery_max, "text": "%d%%" % roundi(State.battery / State.battery_max * 100.0), "level": 0 if State.battery > 30.0 else (1 if State.battery > 10.0 else 2)})
	rows.append({"icon": "water", "label": "APĂ", "value": State.water / State.WATER_MAX, "text": "%d L" % roundi(State.water), "level": 2 if State.water < 15.0 else (1 if State.water < 40.0 else 0)})
	rows.append({"icon": "air", "label": "AER", "value": State.air_quality / 100.0, "text": "%d%%" % roundi(State.air_quality), "level": 2 if State.air_quality < 30.0 else (1 if State.air_quality < 50.0 else 0)})
	rows.append({"icon": "filter", "label": "FILTRU FVU", "value": State.air_filter / 100.0, "text": "%d%%" % roundi(State.air_filter), "level": 2 if State.air_filter < 15.0 else (1 if State.air_filter < 30.0 else 0)})
	systems.rows = rows
	systems.queue_redraw()


func _update_weapon(delta: float, p, hud_mode: int) -> void:
	if p == null or not is_instance_valid(p) or mode != "surface":
		weapon_box.visible = false
		return
	var info: Dictionary = p.weapons.hud_info()
	weapon_box.visible = hud_mode != 2 or int(info.mag) >= 0
	var w: String = p.weapon
	weapon_box.slot = int(info.slot)
	weapon_box.name_text = info.name
	weapon_box.mag = int(info.mag)
	weapon_box.mag_max = int(p.weapons.defn.get("mag", 0))
	weapon_box.reserve = int(info.reserve)
	weapon_box.reloading = p.weapons.reloading > 0.0
	weapon_box.reload_p = (1.0 - p.weapons.reloading / maxf(p.weapons._reload_total, 0.01)) if p.weapons.reloading > 0.0 else -1.0
	weapon_box.icon_item = p.weapons.current if p.weapons.current not in ["", "hands"] else ""
	weapon_box.bandages = State.count("bandage") + State.count("medkit")
	weapon_box.flashlight = p.flashlight.visible
	var sig := "%s%d%d%s" % [w, weapon_box.mag, weapon_box.reserve, str(weapon_box.reloading)]
	var changed := sig != _weapon_sig
	_weapon_sig = sig
	weapon_box.update_fade(delta, changed or Input.is_action_pressed("aim"), hud_mode >= 1, 5.0)
	weapon_box.queue_redraw()


func _update_perf() -> void:
	var lvl := int(Settings.opt("show_fps"))
	perf_label.visible = lvl > 0
	if lvl == 0:
		return
	var fps := Engine.get_frames_per_second()
	var txt := "%d FPS  ·  %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]
	if lvl >= 2:
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var vram := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
		txt += "\n%d apeluri  ·  %.1fM triunghiuri\nVRAM %d MB  ·  %s\n%s" % [dc, prims / 1.0e6, vram / 1048576, Settings.PRESETS[Settings.preset] if Settings.preset < Settings.PRESETS.size() else "Personalizat", RenderingServer.get_video_adapter_name()]
	perf_label.text = txt


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

## alt: secondary actions [[key, text], ...] (e.g. [G] move, [X] demolish)
func set_interaction(title: String, action: String, hold: bool, progress: float, alt: Array = []) -> void:
	prompt.title = title
	prompt.action = action
	prompt.hold = hold
	prompt.alt = alt
	prompt.queue_redraw()
	reticle.active = action != ""
	reticle.progress = progress


func set_prompt(text: String, progress: float) -> void:
	set_interaction("", text, false, progress)


func hitmarker(kill := false) -> void:
	reticle.hitmarker(kill)


## Shows a red arc pointing at the world position the damage came from.
func damage_from(world_pos: Vector3) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var cam: Camera3D = p.cam
	var local := cam.global_transform.affine_inverse() * world_pos
	reticle.add_damage(atan2(local.x, -local.z))


func set_marker(id: String, pos: Vector3, color: Color, icon := "objective") -> void:
	markers[id] = {"pos": pos, "color": color, "icon": icon}


func clear_marker(id: String) -> void:
	markers.erase(id)


func set_surface_status(filter_s: float, spare: int, dose_rate: float, weight: float, cap: float, _weapon: String) -> void:
	_surface = {"filter": filter_s, "spare": spare, "rate": maxf(dose_rate, 0.0), "weight": weight, "cap": cap}


func toast(text: String, kind := "info") -> void:
	var icon: String = {"good": "objective", "warn": "weight", "danger": "skull", "radio": "radio", "item": "res"}.get(kind, "objective")
	_push_toast(text, kind, icon)


func _item_toast(id: String, n: int, to_stash: bool) -> void:
	var it := ItemDB.item(id)
	var txt := "+%d  %s" % [n, it.get("name", id)]
	if to_stash:
		txt += "   → depozit"
	_push_toast(txt, "item", HudIcons.for_item(id))


class ToastRow extends Control:
	var text := ""
	var col := Color.WHITE
	var icon := "res"
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(0, 0, 3, size.y), col)
		HudIcons.draw(self, icon, Rect2(12, 7, size.y - 14, size.y - 14), col, 1.6)
		var f := Assets.font("bold")
		draw_string(f, Vector2(size.y + 10, size.y * 0.5 + 7), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - size.y - 18, 17, Color(0.93, 0.92, 0.88))


func _push_toast(text: String, kind: String, icon: String) -> void:
	var col: Color = {"item": Color(0.86, 0.85, 0.8), "good": UITheme.GOOD, "warn": UITheme.WARN, "danger": UITheme.DANGER, "radio": UITheme.RADIO}.get(kind, UITheme.ACCENT)
	var row := ToastRow.new()
	row.text = text
	row.col = col
	row.icon = icon
	row.custom_minimum_size = Vector2(440, 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(row)
	while toast_box.get_child_count() > 6:
		toast_box.get_child(0).free()
	row.modulate.a = 0.0
	row.position.x = 60
	var tw := row.create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.18)
	tw.tween_interval(4.2)
	tw.tween_property(row, "modulate:a", 0.0, 0.6)
	tw.tween_callback(row.queue_free)
	if kind in ["danger", "warn"]:
		Audio.ui("ui_hover")


func subtitle(speaker: String, text: String, duration := 5.0) -> void:
	subtitle_panel.visible = true
	if speaker != "":
		subtitle_label.text = "[color=#f5a838][b]%s[/b][/color]   %s" % [speaker.to_upper(), text]
	else:
		subtitle_label.text = text
	_sub_timer = duration


func objective(text: String) -> void:
	objective_w.set_text(text)


func banner(title: String, sub := "", duration := 4.0) -> void:
	banner_title.text = title.to_upper()
	banner_sub.text = sub
	banner_line.scale.x = 0.0
	banner_line.pivot_offset = Vector2(160, 1)
	var tw := banner_box.create_tween()
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(banner_line, "scale:x", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(banner_box, "modulate:a", 0.0, 1.2)


func alert(title: String, text: String, duration := 7.0) -> void:
	alert_title.text = title
	alert_text.text = text
	alert_panel.visible = true
	alert_panel.position.y = -260
	var tw := alert_panel.create_tween()
	tw.tween_property(alert_panel, "position:y", 100.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(alert_panel, "position:y", -260.0, 0.4)
	tw.tween_callback(func() -> void: alert_panel.visible = false)


## Build / move placement feedback ({} hides it). See HudWidgets.PlaceBar.
func set_placement(info: Dictionary) -> void:
	place_bar.info = info
	place_bar.queue_redraw()


func hurt(amount: float) -> void:
	_damage = clampf(_damage + amount / 30.0, 0.0, 1.0)


func flash(intensity := 1.0) -> void:
	_flash = maxf(_flash, intensity)


func set_post(param: String, value) -> void:
	post_mat.set_shader_parameter(param, value)


func fade_to(alpha: float, time := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, time)
	await tw.finished


func fade_color(c: Color) -> void:
	fade_rect.color = Color(c.r, c.g, c.b, fade_rect.color.a)


# --------------------------------------------------------------------------
# Panels
# --------------------------------------------------------------------------

func open_panel(p: UIPanel) -> UIPanel:
	panel_root.add_child(p)
	panels.append(p)
	Game.push_ui()
	Audio.ui("ui_click")
	return p


func close_panel(p: UIPanel) -> void:
	if not panels.has(p):
		return
	panels.erase(p)
	p.closed.emit()
	p.queue_free()
	Game.pop_ui()


func close_all_panels() -> void:
	for p in panels.duplicate():
		close_panel(p)


func has_panel() -> bool:
	return not panels.is_empty()


func top_panel() -> UIPanel:
	return panels.back() if not panels.is_empty() else null


## Quick list-of-choices dialog. options: [{text, cb, enabled(opt), desc(opt)}]
func choose(title: String, info: String, options: Array) -> UIPanel:
	return open_panel(ChoicePanel.new(title, info, options))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if has_panel():
			top_panel().close()
			get_viewport().set_input_as_handled()
		elif mode in ["intro", "bunker", "surface"] and not Game.build_mode_active:
			open_panel(PauseMenu.new())
			get_viewport().set_input_as_handled()
