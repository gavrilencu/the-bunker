class_name InventoryPanel
extends UIPanel
## STALKER-style inventory: character/equipment | item grid (backpack / stash) | details.

const FILTERS := [["Toate", ""], ["Hrană", "food"], ["Medicale", "med"], ["Materiale", "res"], ["Echipament", "gear"], ["Arme", "weapon"], ["Semințe", "seed"]]
const EQUIP := [["gas_mask", "MASCĂ"], ["hazmat_suit", "COSTUM"], ["axe", "ARMĂ 1"], ["pistol", "ARMĂ 2"], ["flashlight", "LANTERNĂ"], ["geiger", "DOZIMETRU"]]


class ItemCell extends Control:
	var item := ""
	var n := 0
	var selected := false
	var hover := false
	var big := false
	var dim := false
	## Drag source / drop target: "pack", "stash" or "equip" (set by the panel).
	var src := ""
	var panel: InventoryPanel
	signal picked(id: String)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(item)
			Audio.ui("ui_click")

	# --- drag & drop: the whole stack, or one piece with Shift held
	func _get_drag_data(_at: Vector2) -> Variant:
		if item == "" or dim or panel == null or src == "":
			return null
		var take := 1 if (Input.is_key_pressed(KEY_SHIFT) or src == "equip") else maxi(n, 1)
		var pv := ItemCell.new()
		pv.item = item
		pv.big = true
		pv.n = take
		pv.custom_minimum_size = Vector2(96, 96)
		pv.size = Vector2(96, 96)
		pv.modulate = Color(1, 1, 1, 0.85)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_drag_preview(pv)
		return {"id": item, "n": take, "from": src}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return panel != null and data is Dictionary and panel.can_drop(data, _drop_target())

	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel.drop(data, _drop_target())

	func _drop_target() -> String:
		return "equip:" + item if src == "equip" else src

	func _process(_d: float) -> void:
		if item != "" and IconFactory.get_icon(item) != null and not has_meta("icon_ok"):
			set_meta("icon_ok", true)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := Color(0.07, 0.075, 0.07, 0.92)
		draw_rect(r, bg)
		var grad_top := Color(1, 1, 1, 0.04)
		draw_rect(Rect2(0, 0, size.x, size.y * 0.5), grad_top)
		var bc := UITheme.ACCENT if selected else (Color(1, 1, 1, 0.35) if hover else Color(1, 1, 1, 0.08))
		draw_rect(r, bc, false, 2.0 if selected else 1.0)
		if item == "":
			return
		var tex := IconFactory.get_icon(item)
		var ir := r.grow(-(10.0 if not big else 16.0))
		if not big:
			ir.size.y -= 12
		var a := 0.45 if dim else 1.0
		if tex:
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, a))
		else:
			HudIcons.draw(self, HudIcons.for_item(item), ir.grow(-ir.size.x * 0.18), Color(UITheme.TEXT, 0.85 * a), 2.0 if not big else 3.0)
		if not big:
			var f := Assets.font("mono")
			if n > 1:
				var t := "×%d" % n
				draw_string(f, Vector2(size.x - 6 - f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, 16), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.ACCENT)
			var nm: String = ItemDB.item_name(item)
			var fb := Assets.font("body")
			draw_string(fb, Vector2(5, size.y - 6), nm, HORIZONTAL_ALIGNMENT_LEFT, size.x - 10, 12, Color(UITheme.TEXT_DIM, a))


## The item grid and its scroll area accept drops for the view they show.
class DropGrid extends GridContainer:
	var panel: InventoryPanel
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return panel != null and data is Dictionary and panel.can_drop(data, panel.view)
	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel.drop(data, panel.view)


class DropScroll extends ScrollContainer:
	var panel: InventoryPanel
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return panel != null and data is Dictionary and panel.can_drop(data, panel.view)
	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel.drop(data, panel.view)


## RUCSAC / DEPOZIT tab: dropping an item on it moves the item there.
class DropTab extends Button:
	var panel: InventoryPanel
	var target := ""
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return panel != null and data is Dictionary and panel.can_drop(data, target)
	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel.drop(data, target)

var view := "pack"  # pack | stash
var filter := ""
var selected := ""
var grid: GridContainer
var tabs: HBoxContainer
var filter_row: HBoxContainer
var char_box: VBoxContainer
var detail_box: VBoxContainer
var weight_label: Label
var weight_bar: ProgressBar
var equip_cells := {}  # item id -> ItemCell (equipment slots)


func _init() -> void:
	super("Inventar", 1500.0)


# --------------------------------------------------------------------------
# Drag & drop. Equipment is whatever gear sits in the backpack, so "equip" means
# bring it into the backpack and "unequip" means send it to the stash.
# --------------------------------------------------------------------------

func can_drop(data: Dictionary, target: String) -> bool:
	var from: String = data.get("from", "")
	var id: String = data.get("id", "")
	if id == "" or from == "":
		return false
	if target.begins_with("equip:"):
		return target.trim_prefix("equip:") == id and from == "stash"
	if target == "pack":
		return from == "stash"
	if target == "stash":
		return State.context == "bunker" and from in ["pack", "equip"]
	return false


func drop(data: Dictionary, target: String) -> void:
	if not can_drop(data, target):
		return
	var id: String = data.id
	var n: int = data.n
	selected = id
	Audio.ui("ui_click")
	if target == "stash":
		State.move_to_stash(id, n)
	else:
		State.move_to_backpack(id, n)
	if target.begins_with("equip:"):
		HUD.toast("%s — echipat." % ItemDB.item_name(id), "good")


## Selection without rebuilding the grid (a rebuild would free the cell being dragged).
func _select(id: String) -> void:
	selected = id
	for c in grid.get_children():
		if c is ItemCell:
			c.selected = c.item == id and c.item != ""
			c.queue_redraw()
	for c in equip_cells.values():
		c.selected = c.item == id
		c.queue_redraw()
	_build_detail()


## Cell showing `id` (the equipment slot, or the grid cell in the current view).
func find_cell(id: String, equip: bool) -> Control:
	if equip:
		return equip_cells.get(id)
	for c in grid.get_children():
		if c is ItemCell and c.item == id:
			return c
	return null


func build() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	body.add_child(cols)
	# --- character column
	char_box = VBoxContainer.new()
	char_box.custom_minimum_size = Vector2(300, 660)
	char_box.add_theme_constant_override("separation", 8)
	cols.add_child(char_box)
	# --- grid column
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(760, 660)
	mid.add_theme_constant_override("separation", 10)
	cols.add_child(mid)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	mid.add_child(tabs)
	filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	mid.add_child(filter_row)
	var sc := DropScroll.new()
	sc.panel = self
	sc.custom_minimum_size = Vector2(760, 500)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(sc)
	var dg := DropGrid.new()
	dg.panel = self
	grid = dg
	grid.columns = 7
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	mid.add_child(UITheme.label("Trage obiectele cu mausul: rucsac ⇄ depozit ⇄ echipament (pe un slot sau pe o filă)  ·  Shift = câte o bucată", 13, UITheme.TEXT_DIM))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 10)
	mid.add_child(wrow)
	weight_label = UITheme.label("", 15, UITheme.TEXT_DIM, "mono")
	weight_label.custom_minimum_size.x = 330
	wrow.add_child(weight_label)
	weight_bar = UITheme.bar(UITheme.ACCENT, 6)
	weight_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(weight_bar)
	# --- detail column
	detail_box = VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(360, 660)
	detail_box.add_theme_constant_override("separation", 8)
	cols.add_child(detail_box)
	State.inventory_changed.connect(refresh)
	var warm: Array = State.inventory.keys() + State.stash.keys()
	IconFactory.warm_up(warm)


func _src() -> Dictionary:
	return State.stash if view == "stash" else State.inventory


func refresh() -> void:
	if not is_inside_tree():
		return
	if view == "stash" and State.context != "bunker":
		view = "pack"
	_build_tabs()
	_build_char()
	clear(grid)
	var src := _src()
	var ids: Array = src.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ca: String = ItemDB.item(a).get("cat", "")
		var cb: String = ItemDB.item(b).get("cat", "")
		return ca < cb if ca != cb else ItemDB.item_name(a) < ItemDB.item_name(b))
	var shown := 0
	for id in ids:
		var cat: String = ItemDB.item(id).get("cat", "")
		if filter != "" and not (cat == filter or (filter == "gear" and cat in ["gear", "tool", "ammo"]) or (filter == "food" and cat in ["food", "drink"]) or (filter == "res" and cat in ["res", "fuel"])):
			continue
		var cell := ItemCell.new()
		cell.item = id
		cell.n = int(src[id])
		cell.selected = id == selected
		cell.src = view
		cell.panel = self
		cell.custom_minimum_size = Vector2(102, 108)
		cell.picked.connect(_select)
		grid.add_child(cell)
		shown += 1
	for i in maxi(0, 28 - shown):
		var empty := ItemCell.new()
		empty.custom_minimum_size = Vector2(102, 108)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(empty)
	var w := State.total_weight()
	var over := w > State.carry_max
	weight_label.text = "RUCSAC  %.1f / %d kg%s" % [w, int(State.carry_max), "   SUPRAÎNCĂRCAT" if over else ""]
	weight_label.add_theme_color_override("font_color", UITheme.DANGER if over else UITheme.TEXT_DIM)
	weight_bar.max_value = State.carry_max * 1.5
	weight_bar.value = w
	weight_bar.add_theme_stylebox_override("fill", UITheme.flat(UITheme.DANGER if over else UITheme.ACCENT, 0, Color.TRANSPARENT, 1))
	if view == "stash":
		weight_label.text += "    ·    DEPOZIT  %.1f kg" % State.stash_weight()
	_build_detail()


func _build_tabs() -> void:
	clear(tabs)
	var specs := [["pack", "RUCSAC  (%d)" % State.inventory.size()]]
	if State.context == "bunker":
		specs.append(["stash", "DEPOZIT  (%d)" % State.stash.size()])
	for s in specs:
		var b := DropTab.new()
		b.panel = self
		b.target = s[0]
		b.text = s[1]
		b.custom_minimum_size.x = 200
		b.pressed.connect(func() -> void:
			Audio.ui("ui_click")
			view = s[0]
			selected = ""
			refresh())
		if view == s[0]:
			b.add_theme_color_override("font_color", UITheme.ACCENT)
			b.add_theme_stylebox_override("normal", UITheme.flat(Color(0.2, 0.15, 0.07, 0.98), 1, UITheme.ACCENT, 2))
		tabs.add_child(b)
	if State.context == "bunker":
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(sp)
		tabs.add_child(UITheme.button("Descarcă rucsacul în depozit", func() -> void:
			var n := State.unload_to_stash()
			HUD.toast("%d obiecte mutate în depozit." % n, "info")
			refresh()))
	clear(filter_row)
	for f in FILTERS:
		var fb := UITheme.button(f[0], func() -> void:
			filter = f[1]
			refresh())
		fb.add_theme_font_size_override("font_size", 15)
		if filter == f[1]:
			fb.add_theme_color_override("font_color", UITheme.ACCENT)
		filter_row.add_child(fb)


func _stat(parent: Control, icon: String, label: String, v: float, text: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic := IconBox.new()
	ic.icon = icon
	ic.col = col
	ic.custom_minimum_size = Vector2(20, 20)
	row.add_child(ic)
	var l := UITheme.label(label, 15, UITheme.TEXT, "bold")
	l.custom_minimum_size.x = 92
	row.add_child(l)
	var b := UITheme.bar(col, 6)
	b.value = v * 100.0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	var t := UITheme.label(text, 14, UITheme.TEXT_DIM, "mono")
	t.custom_minimum_size.x = 56
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(t)
	parent.add_child(row)


class IconBox extends Control:
	var icon := ""
	var col := Color.WHITE
	func _draw() -> void:
		HudIcons.draw(self, icon, Rect2(Vector2.ZERO, size), col, 1.6)


func _build_char() -> void:
	clear(char_box)
	char_box.add_child(UITheme.heading("Alex Moraru", 22, UITheme.TEXT))
	char_box.add_child(UITheme.label("Inginer · Obiectivul 17", 14, UITheme.TEXT_DIM))
	char_box.add_child(UITheme.spacer(6))
	_stat(char_box, "health", "SĂNĂTATE", State.health / 100.0, "%d" % roundi(State.health), UITheme.DANGER if State.health < 30 else Color(0.85, 0.84, 0.8))
	_stat(char_box, "food", "HRANĂ", State.food / 100.0, "%d" % roundi(State.food), UITheme.WARN if State.food < 35 else Color(0.85, 0.7, 0.45))
	_stat(char_box, "water", "APĂ", State.hydration / 100.0, "%d" % roundi(State.hydration), UITheme.WARN if State.hydration < 35 else UITheme.RADIO)
	_stat(char_box, "energy", "ENERGIE", State.energy / 100.0, "%d" % roundi(State.energy), UITheme.WARN if State.energy < 30 else Color(0.9, 0.85, 0.5))
	_stat(char_box, "rad", "RADIAȚIE", clampf(State.radiation / 1000.0, 0, 1), "%d" % roundi(State.radiation), UITheme.DANGER if State.radiation > 250 else UITheme.GOOD)
	if State.bleeding > 0.0:
		char_box.add_child(UITheme.label("SÂNGERARE ×%d — folosește un bandaj" % ceili(State.bleeding), 14, UITheme.DANGER, "bold"))
	char_box.add_child(UITheme.spacer(8))
	char_box.add_child(UITheme.heading("Echipament", 16, UITheme.ACCENT))
	var eg := GridContainer.new()
	eg.columns = 3
	eg.add_theme_constant_override("h_separation", 6)
	eg.add_theme_constant_override("v_separation", 6)
	char_box.add_child(eg)
	equip_cells.clear()
	for e in EQUIP:
		var v := VBoxContainer.new()
		var cell := ItemCell.new()
		cell.item = e[0]
		cell.big = true
		cell.dim = State.count(e[0]) <= 0
		cell.selected = e[0] == selected
		cell.src = "equip"
		cell.panel = self
		cell.custom_minimum_size = Vector2(92, 80)
		cell.picked.connect(_select)
		equip_cells[e[0]] = cell
		v.add_child(cell)
		var l := UITheme.label(e[1], 11, UITheme.TEXT_DIM if cell.dim else UITheme.TEXT, "heading")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		eg.add_child(v)
	char_box.add_child(UITheme.label("Filtre de mască: %d   ·   Cartușe 9 mm: %d" % [State.count("mask_filter"), State.count("ammo_9mm")], 14, UITheme.TEXT_DIM, "mono"))


func _build_detail() -> void:
	clear(detail_box)
	if selected == "" or (State.count(selected) <= 0 and State.stash_count(selected) <= 0):
		detail_box.add_child(UITheme.label("Selectează un obiect.", 17, UITheme.TEXT_DIM))
		return
	var it := ItemDB.item(selected)
	var big := ItemCell.new()
	big.item = selected
	big.big = true
	big.custom_minimum_size = Vector2(360, 240)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_child(big)
	detail_box.add_child(UITheme.heading(it.name, 24, UITheme.TEXT))
	detail_box.add_child(UITheme.label(ItemDB.CAT_NAMES.get(it.get("cat", ""), "").to_upper(), 13, UITheme.ACCENT, "heading"))
	var d := UITheme.label(it.get("desc", ""), 16, UITheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 350
	detail_box.add_child(d)
	var lines: Array = []
	if it.get("food", 0) != 0:
		lines.append("Hrană  %+d" % it.food)
	if it.get("water", 0) != 0:
		lines.append("Apă  %+d" % it.water)
	if it.get("heal", 0) != 0:
		lines.append("Sănătate  +%d" % it.heal)
	if it.get("rad", 0) != 0:
		lines.append("Radiație  −%d mSv" % it.rad)
	if it.get("dmg", 0) != 0:
		lines.append("Daune  %d" % it.dmg)
	lines.append("Greutate  %.2f kg" % float(it.get("w", 0.1)))
	lines.append("În rucsac  %d   ·   În depozit  %d" % [State.count(selected), State.stash_count(selected)])
	for l in lines:
		detail_box.add_child(UITheme.label(l, 15, UITheme.TEXT, "mono"))
	detail_box.add_child(UITheme.spacer(6))
	var cat: String = it.get("cat", "")
	if cat in ["food", "drink", "med", "fuel"]:
		detail_box.add_child(UITheme.button("Folosește", func() -> void:
			State.use_item(selected)
			refresh()))
	if State.context == "bunker":
		if view == "pack" and State.count(selected) > 0:
			detail_box.add_child(UITheme.button("Mută 1 în depozit", func() -> void:
				State.move_to_stash(selected, 1)
				refresh()))
			detail_box.add_child(UITheme.button("Mută tot în depozit", func() -> void:
				State.move_to_stash(selected, State.count(selected))
				refresh()))
		elif view == "stash" and State.stash_count(selected) > 0:
			detail_box.add_child(UITheme.button("Ia 1 în rucsac", func() -> void:
				State.move_to_backpack(selected, 1)
				refresh()))
			detail_box.add_child(UITheme.button("Ia tot în rucsac", func() -> void:
				State.move_to_backpack(selected, State.stash_count(selected))
				refresh()))
