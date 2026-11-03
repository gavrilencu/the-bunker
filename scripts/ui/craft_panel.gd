class_name CraftPanel
extends UIPanel

var list: VBoxContainer
var station := "bench"


func _init(p_station := "bench") -> void:
	station = p_station
	super("Aragaz de campanie" if p_station == "stove" else "Banc de lucru", 920.0)


func build() -> void:
	var txt := "Mâncarea gătită e mult mai sățioasă decât cea crudă." if station == "stove" else "Fabricarea consumă timp de joc. Materialele se iau din rucsac și din depozit."
	if station == "bench" and State.has_up("bench_2"):
		txt += "  Strung: −30% timp."
	body.add_child(UITheme.label(txt, 17, UITheme.TEXT_DIM))
	list = scroll_box(540)


func refresh() -> void:
	clear(list)
	for r in ItemDB.RECIPES:
		if r.get("station", "bench") == station:
			list.add_child(_row(r))


func _row(r: Dictionary) -> Control:
	var p := row_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var title := "%s ×%d" % [ItemDB.item_name(r.out), r.n]
	left.add_child(UITheme.label(title, 20, UITheme.TEXT, "bold"))
	var parts := []
	var ok := true
	for k in r.cost:
		var have := State.available(k)
		var need: int = r.cost[k]
		if have < need:
			ok = false
		parts.append("[color=%s]%s %d/%d[/color]" % ["#9be06a" if have >= need else "#ef5a4a", ItemDB.item_name(k), have, need])
	if r.has("needs_water"):
		var wok: bool = State.water >= float(r.needs_water)
		ok = ok and wok
		parts.append("[color=%s]apă din rezervor %.1f L[/color]" % ["#9be06a" if wok else "#ef5a4a", r.needs_water])
	var cost := RichTextLabel.new()
	cost.bbcode_enabled = true
	cost.fit_content = true
	cost.scroll_active = false
	cost.custom_minimum_size.x = 560
	cost.text = "   ·   ".join(parts)
	cost.add_theme_font_size_override("normal_font_size", 16)
	left.add_child(cost)
	var minutes := roundi(float(r.time) * State.mul("craft_time"))
	var t := UITheme.label("%d min" % minutes, 16, UITheme.TEXT_DIM, "mono")
	row.add_child(t)
	var locked: bool = r.has("req") and not State.has_up(r.req)
	var b := UITheme.button("Necesită: " + ItemDB.UPGRADES[r.req].name if locked else ("Gătește" if station == "stove" else "Fabrică"), func() -> void: _craft(r), 130)
	b.disabled = not ok or locked
	row.add_child(b)
	return p


func _craft(r: Dictionary) -> void:
	if not State.consume(r.cost):
		return
	if r.has("needs_water"):
		State.water -= float(r.needs_water)
	Audio.sfx("craft" if station != "stove" else "water_pour", -2.0)
	State.simulate(float(r.time) * State.mul("craft_time"), false)
	State.add(r.out, int(r.n))
	State.stats["crafted"] = int(State.stats.get("crafted", 0)) + 1
	refresh()
