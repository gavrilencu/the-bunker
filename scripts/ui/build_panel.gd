class_name BuildPanel
extends UIPanel

static var tab := "mobilier"
var tabs: HBoxContainer
var list: VBoxContainer


func _init() -> void:
	super("Construcție", 900.0)


func build() -> void:
	body.add_child(UITheme.label("Alege ce construiești, apoi plasează holograma: click stânga plasează, rotița / R rotește, T aliniere, click dreapta anulează.", 17, UITheme.TEXT_DIM))
	var tip := UITheme.label("Sfat: țintește orice obiect din buncăr și apasă [G] ca să-l muți. Luminile se reglează cu [E].", 15, UITheme.ACCENT)
	body.add_child(tip)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	list = scroll_box(500)


func refresh() -> void:
	clear(tabs)
	for t in ItemDB.BUILD_CATS:
		var n := 0
		for id in ItemDB.BUILDABLES:
			if ItemDB.BUILDABLES[id].get("cat", "") == t[0]:
				n += 1
		var b := UITheme.button("%s  (%d)" % [t[1], n], func() -> void:
			tab = t[0]
			refresh(), 200)
		if tab == t[0]:
			b.add_theme_color_override("font_color", UITheme.ACCENT)
			b.add_theme_stylebox_override("normal", UITheme.flat(Color(0.2, 0.15, 0.07, 0.98), 1, UITheme.ACCENT, 2))
		tabs.add_child(b)
	clear(list)
	for id in ItemDB.BUILDABLES:
		var d: Dictionary = ItemDB.BUILDABLES[id]
		if d.get("cat", "") != tab:
			continue
		var p := row_panel()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		p.add_child(row)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		left.add_child(head)
		head.add_child(UITheme.label(d.name, 20, UITheme.TEXT, "bold"))
		if d.has("mount") or d.get("wall", false):
			var where: String = ItemDB.MOUNT_NAMES.get(d.get("mount", "floor"), "")
			if d.get("wall", false):
				where = "Lângă perete"
			var ml := UITheme.label(where.to_upper(), 13, UITheme.RADIO, "heading")
			ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(ml)
		var dl := UITheme.label(d.desc, 15, UITheme.TEXT_DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 560
		left.add_child(dl)
		var ok := State.has_all(d.cost)
		var locked: bool = d.has("req") and not State.has_up(d.req)
		var ctext := ItemDB.cost_text(d.cost)
		if locked:
			ctext = "Necesită îmbunătățirea: " + ItemDB.UPGRADES[d.req].name
		elif d.has("comfort"):
			ctext += "   ·   confort +%d" % int(d.comfort)
		var cl := UITheme.label(ctext, 15, UITheme.WARN if locked else (UITheme.GOOD if ok else UITheme.DANGER))
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size.x = 560
		left.add_child(cl)
		var b := UITheme.button("Construiește", func() -> void:
			close()
			Game.start_build(id), 150)
		b.disabled = not ok or locked
		row.add_child(b)
		list.add_child(p)
