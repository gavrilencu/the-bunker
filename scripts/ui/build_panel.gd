class_name BuildPanel
extends UIPanel

var list: VBoxContainer


func _init() -> void:
	super("Construcție", 900.0)


func build() -> void:
	body.add_child(UITheme.label("Alege ce construiești, apoi plasează holograma: click stânga plasează, R/rotița rotește, Esc anulează.", 17, UITheme.TEXT_DIM))
	list = scroll_box(540)


func refresh() -> void:
	clear(list)
	for id in ItemDB.BUILDABLES:
		var d: Dictionary = ItemDB.BUILDABLES[id]
		var p := row_panel()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		p.add_child(row)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		left.add_child(UITheme.label(d.name, 20, UITheme.TEXT, "bold"))
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
