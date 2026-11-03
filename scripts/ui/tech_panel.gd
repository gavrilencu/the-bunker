class_name TechPanel
extends UIPanel
## Bunker development tree: 6 branches x 3 tiers, custom-drawn, with detail pane.

class TreeView extends Control:
	const COLS := 6
	const CARD := Vector2(184, 132)
	var selected := ""
	var hover := ""
	var _t := 0.0
	var rects := {}
	signal picked(id: String)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _layout() -> void:
		rects.clear()
		var colw := size.x / COLS
		for id in ItemDB.UPGRADES:
			var u: Dictionary = ItemDB.UPGRADES[id]
			var col := 0
			for i in ItemDB.BRANCHES.size():
				if ItemDB.BRANCHES[i][0] == u.branch:
					col = i
			var x := col * colw + (colw - CARD.x) * 0.5
			var y := 56.0 + (int(u.tier) - 1) * 170.0
			rects[id] = Rect2(Vector2(x, y), CARD)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var h := ""
			for id in rects:
				if (rects[id] as Rect2).has_point(e.position):
					h = id
			if h != hover:
				hover = h
				if h != "":
					Audio.ui("ui_hover")
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hover != "":
			selected = hover
			picked.emit(hover)
			Audio.ui("ui_click")

	func _txt(p: Vector2, s: String, sz: int, col: Color, kind := "body", align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		draw_string(Assets.font(kind), p, s, align, w, sz, col)

	func _draw() -> void:
		_layout()
		var colw := size.x / COLS
		# column bands + headers
		for i in ItemDB.BRANCHES.size():
			var x := i * colw
			draw_rect(Rect2(x + 4, 0, colw - 8, size.y), Color(1, 1, 1, 0.025 if i % 2 == 0 else 0.04))
			_txt(Vector2(x, 30), ItemDB.BRANCHES[i][1], 17, UITheme.ACCENT, "heading", HORIZONTAL_ALIGNMENT_CENTER, colw)
			draw_line(Vector2(x + 30, 40), Vector2(x + colw - 30, 40), Color(UITheme.ACCENT, 0.35), 1.0)
		# links
		for id in ItemDB.UPGRADES:
			for r in ItemDB.UPGRADES[id].get("req", []):
				if not rects.has(r):
					continue
				var a: Rect2 = rects[r]
				var b: Rect2 = rects[id]
				var p0 := Vector2(a.get_center().x, a.end.y)
				var p1 := Vector2(b.get_center().x, b.position.y)
				var done := State.has_up(r)
				var col := Color(UITheme.GOOD, 0.8) if State.has_up(id) else (Color(UITheme.ACCENT, 0.7) if done else Color(1, 1, 1, 0.15))
				draw_line(p0, p1, col, 3.0 if done else 2.0, true)
				if done and not State.has_up(id):
					var f := fposmod(_t * 0.6, 1.0)
					draw_circle(p0.lerp(p1, f), 3.0, UITheme.ACCENT)
		# cards
		for id in rects:
			var u: Dictionary = ItemDB.UPGRADES[id]
			var r: Rect2 = rects[id]
			var owned := State.has_up(id)
			var block := State.upgrade_block(id)
			var avail := block == ""
			var locked := block.begins_with("Necesită")
			var border := UITheme.GOOD if owned else (UITheme.ACCENT if avail else Color(1, 1, 1, 0.12))
			var bg := Color(0.06, 0.07, 0.06, 0.95)
			if id == hover:
				bg = Color(0.1, 0.1, 0.09, 0.98)
			draw_rect(r, bg)
			if avail:
				border = border.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_t * 4.0)))
			draw_rect(r, border, false, 2.0 if (id == selected or avail or owned) else 1.0)
			if id == selected:
				draw_rect(r.grow(4), Color(UITheme.ACCENT, 0.5), false, 1.0)
			var a := 0.45 if locked else 1.0
			HudIcons.draw(self, u.icon, Rect2(r.position + Vector2(12, 12), Vector2(26, 26)), Color(border if not locked else UITheme.TEXT_DIM, a), 2.0)
			_txt(r.position + Vector2(46, 22), "NIVEL %d" % int(u.tier), 11, Color(UITheme.TEXT_DIM, a), "mono")
			var nsz := 15
			while nsz > 11 and Assets.font("bold").get_string_size(u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz).x > r.size.x - 54:
				nsz -= 1
			_txt(r.position + Vector2(46, 38), u.name, nsz, Color(UITheme.TEXT, a), "bold")
			# short description (2 lines, wrapped manually)
			var words: PackedStringArray = String(u.desc).split(" ")
			var line := ""
			var ly := r.position.y + 64
			var lines := 0
			for w in words:
				var test := (line + " " + w).strip_edges()
				if Assets.font("body").get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > r.size.x - 20:
					_txt(Vector2(r.position.x + 10, ly), line, 12, Color(UITheme.TEXT_DIM, a))
					ly += 15
					lines += 1
					line = w
					if lines >= 3:
						line = ""
						break
				else:
					line = test
			if line != "" and lines < 3:
				_txt(Vector2(r.position.x + 10, ly), line, 12, Color(UITheme.TEXT_DIM, a))
			var status := "CONSTRUIT" if owned else ("DISPONIBIL" if avail else ("BLOCAT" if locked else "LIPSESC MATERIALE"))
			var scol := UITheme.GOOD if owned else (UITheme.ACCENT if avail else (UITheme.TEXT_DIM if locked else UITheme.WARN))
			draw_rect(Rect2(r.position.x, r.end.y - 20, r.size.x, 20), Color(scol, 0.14))
			_txt(Vector2(r.position.x, r.end.y - 6), status, 11, scol, "heading", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


var tree: TreeView
var detail: VBoxContainer
var summary: Label


func _init() -> void:
	super("Dezvoltarea buncărului", 1580.0)


func build() -> void:
	summary = UITheme.label("", 16, UITheme.TEXT_DIM, "mono")
	body.add_child(summary)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	tree = TreeView.new()
	tree.custom_minimum_size = Vector2(1180, 560)
	tree.picked.connect(func(_id: String) -> void: refresh())
	row.add_child(tree)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _row_style())
	dp.custom_minimum_size = Vector2(330, 560)
	row.add_child(dp)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	dp.add_child(detail)
	State.inventory_changed.connect(refresh)


func refresh() -> void:
	if not is_inside_tree():
		return
	summary.text = "Îmbunătățiri: %d / %d   ·   Confort: %d   ·   Capacitate rucsac: %d kg   ·   Consum generator: %.2f L/h" % [
		State.upgrades.size(), ItemDB.UPGRADES.size(), roundi(State.comfort()), int(State.carry_max), State.fuel_rate()]
	clear(detail)
	var id := tree.selected
	if id == "":
		detail.add_child(UITheme.heading("Alege o îmbunătățire", 20, UITheme.TEXT))
		var l := UITheme.label("Fiecare ramură se deblochează pe niveluri. Materialele se iau din rucsac și din depozit. Construcția consumă ore de joc.", 16, UITheme.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
		detail.add_child(l)
		return
	var u: Dictionary = ItemDB.UPGRADES[id]
	detail.add_child(UITheme.label("NIVEL %d  ·  %s" % [int(u.tier), _branch_name(u.branch)], 13, UITheme.ACCENT, "heading"))
	detail.add_child(UITheme.heading(u.name, 24, UITheme.TEXT))
	var d := UITheme.label(u.desc, 17, UITheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 300
	detail.add_child(d)
	detail.add_child(UITheme.spacer(6))
	detail.add_child(UITheme.label("COST", 13, UITheme.TEXT_DIM, "heading"))
	for k in u.cost:
		var have := State.available(k)
		var need: int = u.cost[k]
		detail.add_child(UITheme.label("%s   %d / %d" % [ItemDB.item_name(k), have, need], 16, UITheme.GOOD if have >= need else UITheme.DANGER, "mono"))
	detail.add_child(UITheme.label("Timp de lucru: %d ore" % int(u.get("hours", 2)), 15, UITheme.TEXT_DIM, "mono"))
	for r in u.get("req", []):
		detail.add_child(UITheme.label("Necesită: %s" % ItemDB.UPGRADES[r].name, 15, UITheme.GOOD if State.has_up(r) else UITheme.WARN))
	if u.has("dig"):
		var ok := int(State.dig.get(u.dig, 0)) >= 3
		detail.add_child(UITheme.label("Necesită: secțiunea %s săpată" % ("B" if u.dig == "sec_b" else "C"), 15, UITheme.GOOD if ok else UITheme.WARN))
	detail.add_child(UITheme.spacer(10))
	if State.has_up(id):
		detail.add_child(UITheme.label("✓ CONSTRUIT", 20, UITheme.GOOD, "heading"))
	else:
		var block := State.upgrade_block(id)
		var b := UITheme.button("Construiește", func() -> void:
			if State.buy_upgrade(id):
				Audio.sfx("upgrade_done", -2.0)
				if Game.level and Game.level.has_method("on_upgrade"):
					Game.level.on_upgrade(id)
				refresh())
		b.disabled = block != ""
		detail.add_child(b)
		if block != "":
			detail.add_child(UITheme.label(block, 15, UITheme.WARN))


func _branch_name(b: String) -> String:
	for x in ItemDB.BRANCHES:
		if x[0] == b:
			return x[1]
	return b
