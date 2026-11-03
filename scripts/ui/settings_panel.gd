class_name SettingsPanel
extends UIPanel
## Game-style settings: tabs, presets, ◀ value ▶ switchers, live apply, descriptions.

const TABS := [["grafica", "GRAFICĂ"], ["ecran", "ECRAN"], ["audio", "AUDIO"], ["control", "CONTROL"]]

var tab := "grafica"
var tab_box: VBoxContainer
var list: VBoxContainer
var desc_title: Label
var desc_text: Label
var preset_row: HBoxContainer
var gpu_label: Label


func _init() -> void:
	super("Setări", 1240.0)


func build() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	body.add_child(cols)
	tab_box = VBoxContainer.new()
	tab_box.custom_minimum_size = Vector2(200, 0)
	tab_box.add_theme_constant_override("separation", 6)
	cols.add_child(tab_box)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(980, 0)
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	preset_row = HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	right.add_child(preset_row)
	gpu_label = UITheme.label("", 14, UITheme.TEXT_DIM, "mono")
	right.add_child(gpu_label)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(980, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _row_style())
	dp.custom_minimum_size = Vector2(980, 96)
	right.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	desc_title = UITheme.heading("", 16, UITheme.ACCENT)
	dv.add_child(desc_title)
	desc_text = UITheme.label("Treci cu mouse-ul peste o opțiune pentru detalii.", 16, UITheme.TEXT_DIM)
	desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_text.custom_minimum_size.x = 950
	dv.add_child(desc_text)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	bottom.add_child(UITheme.button("Valori implicite", func() -> void:
		Settings.reset_defaults()
		Settings._autodetect()
		refresh()))
	closed.connect(Settings.save_settings)


func refresh() -> void:
	clear(tab_box)
	for t in TABS:
		var b := UITheme.button(t[1], func() -> void:
			tab = t[0]
			refresh(), 200)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if tab == t[0]:
			b.add_theme_color_override("font_color", UITheme.ACCENT)
			b.add_theme_stylebox_override("normal", UITheme.flat(Color(0.2, 0.15, 0.07, 0.98), 1, UITheme.ACCENT, 2))
		tab_box.add_child(b)
	clear(preset_row)
	preset_row.visible = tab == "grafica"
	gpu_label.visible = tab == "grafica"
	if tab == "grafica":
		preset_row.add_child(UITheme.label("PRESET", 15, UITheme.TEXT_DIM, "heading"))
		for i in Settings.PRESETS.size():
			var pb := UITheme.button(Settings.PRESETS[i], func() -> void:
				Settings.apply_preset(i)
				refresh(), 150)
			if Settings.preset == i:
				pb.add_theme_color_override("font_color", UITheme.ACCENT)
				pb.add_theme_stylebox_override("normal", UITheme.flat(Color(0.2, 0.15, 0.07, 0.98), 1, UITheme.ACCENT, 2))
			preset_row.add_child(pb)
		if Settings.preset == Settings.CUSTOM:
			preset_row.add_child(UITheme.label("  PERSONALIZAT", 15, UITheme.ACCENT, "heading"))
		gpu_label.text = "Placă video: %s   ·   %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()]
	clear(list)
	for d in Settings.DEFS:
		if d.tab == tab:
			list.add_child(_row(d))


func _row(d: Dictionary) -> Control:
	var p := PanelContainer.new()
	var sb := _row_style()
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var l := UITheme.label(d.label, 18, UITheme.TEXT, "bold")
	l.custom_minimum_size.x = 420
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	match d.type:
		"choice", "toggle":
			var choices: Array = d.choices if d.type == "choice" else ["Dezactivat", "Activat"]
			var cur := int(Settings.opt(d.id))
			var val_l := UITheme.label(choices[clampi(cur, 0, choices.size() - 1)], 18, UITheme.ACCENT, "bold")
			val_l.custom_minimum_size.x = 260
			val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var step := func(dir: int) -> void:
				var nv := posmod(int(Settings.opt(d.id)) + dir, choices.size())
				Settings.set_opt(d.id, nv)
				val_l.text = choices[nv]
				refresh()
			var lb := UITheme.button("◀", func() -> void: step.call(-1), 44)
			var rb := UITheme.button("▶", func() -> void: step.call(1), 44)
			row.add_child(lb)
			row.add_child(val_l)
			row.add_child(rb)
			# segment indicator
			var seg := SegBar.new()
			seg.count = choices.size()
			seg.value = cur
			seg.custom_minimum_size = Vector2(120, 18)
			seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(seg)
		"slider":
			var s := HSlider.new()
			s.min_value = d.min
			s.max_value = d.max
			s.step = d.step
			s.value = float(Settings.opt(d.id))
			s.custom_minimum_size = Vector2(330, 24)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var vl := UITheme.label(_fmt(d, s.value), 17, UITheme.ACCENT, "mono")
			vl.custom_minimum_size.x = 80
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			s.value_changed.connect(func(v: float) -> void:
				Settings.set_opt(d.id, v)
				vl.text = _fmt(d, v))
			row.add_child(s)
			row.add_child(vl)
	p.mouse_entered.connect(func() -> void:
		desc_title.text = d.label.to_upper()
		desc_text.text = d.get("desc", ""))
	return p


class SegBar extends Control:
	var count := 3
	var value := 0
	func _draw() -> void:
		var w := (size.x - (count - 1) * 3.0) / count
		for i in count:
			var on := i <= value
			draw_rect(Rect2(i * (w + 3.0), size.y * 0.35, w, size.y * 0.3), UITheme.ACCENT if on else Color(1, 1, 1, 0.12))


func _fmt(d: Dictionary, v: float) -> String:
	var f: String = d.get("fmt", "%.2f")
	if f == "pct":
		return "%d%%" % roundi(v * 100.0)
	if f == "%d°":
		return "%d°" % roundi(v)
	return f % v
