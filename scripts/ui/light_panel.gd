class_name LightPanel
extends UIPanel
## Settings of one DecoLight: on/off, colour, brightness, shadows; move / demolish.
## Sits on the right with a light dim so the change is visible live in the room.

var light: DecoLight
var state_btn: Button
var swatches: HBoxContainer
var color_name: Label
var level_label: Label
var shadow_btn: Button
var power_label: Label


func _init(p_light: DecoLight) -> void:
	super(p_light.title(), 560.0)
	light = p_light
	dim.color = Color(0, 0, 0, 0.12)
	blur_world = false
	# the CenterContainer holding the frame: right half of the screen
	var center := get_child(1) as Control
	center.anchor_left = 0.52


func build() -> void:
	var cfg := light.cfg
	var mount: String = light.def.get("mount", "floor")
	var info := "%s  ·  %s" % [ItemDB.MOUNT_NAMES.get(mount, ""), "baterie proprie — merge și fără curent" if light.self_powered()
		else "consum %.3f L motorină / oră la 100%%" % float(light.def.get("power", 0.012))]
	body.add_child(UITheme.label(info, 16, UITheme.TEXT_DIM))
	power_label = UITheme.label("", 16, UITheme.WARN)
	body.add_child(power_label)

	body.add_child(_caption("STARE"))
	state_btn = UITheme.button("", func() -> void:
		cfg["on"] = not bool(cfg.get("on", true))
		Audio.sfx("ui_click", -2.0, 0.0)
		_changed(), 240)
	body.add_child(state_btn)

	body.add_child(_caption("CULOARE"))
	swatches = HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 8)
	body.add_child(swatches)
	color_name = UITheme.label("", 16, UITheme.TEXT)
	body.add_child(color_name)

	body.add_child(_caption("INTENSITATE"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var s := HSlider.new()
	s.min_value = DecoLight.LEVEL_MIN
	s.max_value = DecoLight.LEVEL_MAX
	s.step = 0.05
	s.value = float(cfg.get("l", 1.0))
	s.custom_minimum_size = Vector2(400, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_label = UITheme.label("", 17, UITheme.ACCENT, "mono")
	level_label.custom_minimum_size.x = 70
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		cfg["l"] = v
		_changed())
	row.add_child(s)
	row.add_child(level_label)

	body.add_child(_caption("UMBRE"))
	shadow_btn = UITheme.button("", func() -> void:
		cfg["s"] = not bool(cfg.get("s", false))
		_changed(), 240)
	body.add_child(shadow_btn)
	var note := UITheme.label("Umbrele arată mai bine, dar costă performanță. Ține-le pornite doar la câteva lumini.", 14, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 520
	body.add_child(note)

	body.add_child(UITheme.spacer(6))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	var key: String = light.get_meta("mv_key", "")
	if key != "":
		actions.add_child(UITheme.button("Mută  [G]", func() -> void:
			close()
			Game.level.start_move.call_deferred(key), 200))
	if light.has_meta("built_index"):
		var idx: int = light.get_meta("built_index")
		actions.add_child(UITheme.button("Demontează (50% înapoi)", func() -> void:
			close()
			Game.level.demolish(idx), 280))


func refresh() -> void:
	var cfg := light.cfg
	var on := bool(cfg.get("on", true))
	state_btn.text = "PORNITĂ" if on else "OPRITĂ"
	state_btn.add_theme_color_override("font_color", UITheme.GOOD if on else UITheme.TEXT_DIM)
	clear(swatches)
	for i in DecoLight.COLORS.size():
		var c: Color = DecoLight.COLORS[i][1]
		var sel := int(cfg.get("c", 0)) == i
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 40)
		b.tooltip_text = DecoLight.COLORS[i][0]
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UITheme.flat(c, 3 if sel else (2 if st == "hover" else 0), UITheme.ACCENT if sel else Color(1, 1, 1, 0.8), 3))
		b.pressed.connect(func() -> void:
			cfg["c"] = i
			Audio.ui("ui_click")
			_changed())
		swatches.add_child(b)
	color_name.text = "Culoare: %s" % DecoLight.COLORS[clampi(int(cfg.get("c", 0)), 0, DecoLight.COLORS.size() - 1)][0]
	level_label.text = "%d%%" % roundi(float(cfg.get("l", 1.0)) * 100.0)
	var sh := bool(cfg.get("s", false))
	shadow_btn.text = "ACTIVATE" if sh else "DEZACTIVATE"
	shadow_btn.add_theme_color_override("font_color", UITheme.ACCENT if sh else UITheme.TEXT_DIM)
	var ps := State.power_state()
	if light.self_powered():
		power_label.text = ""
	elif ps == "none":
		power_label.text = "Fără curent în buncăr — lumina rămâne stinsă până pornești generatorul."
	elif ps == "battery":
		power_label.text = "Generatorul e oprit: pe baterii luminile merg la 30%."
	else:
		power_label.text = ""
	power_label.visible = power_label.text != ""


func _changed() -> void:
	light.apply()
	refresh()


func _caption(text: String) -> Label:
	return UITheme.label(text, 14, UITheme.TEXT_DIM, "heading")
