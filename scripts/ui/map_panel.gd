class_name MapPanel
extends UIPanel
## Regional PDA map of Vadul Nou: pick an expedition destination.

const POS := {
	"bunker": Vector2(0.66, 0.53), "factory": Vector2(0.74, 0.43), "market": Vector2(0.53, 0.63),
	"hospital": Vector2(0.42, 0.4), "police": Vector2(0.36, 0.6), "metro": Vector2(0.27, 0.45), "military": Vector2(0.86, 0.2),
}
const ICONS := {"factory": "tool", "market": "food", "hospital": "med", "police": "weapon", "metro": "radio", "military": "skull"}
const BLAST := Vector2(0.14, 0.33)
const DAM := Vector2(0.9, 0.78)


class RegionMap extends Control:
	var selected := ""
	var hover := ""
	var _t := 0.0
	var blocks: Array = []
	signal picked(id: String)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 1983
		for i in 420:
			var c := Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.08, 0.92))
			var dense := exp(-c.distance_to(Vector2(0.38, 0.5)) * 3.2)
			if rng.randf() < dense + 0.08:
				blocks.append(Rect2(c, Vector2(rng.randf_range(0.006, 0.02), rng.randf_range(0.006, 0.018))))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func m(p: Vector2) -> Vector2:
		return p * size

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var h := ""
			for id in MapPanel.POS:
				if id != "bunker" and m(MapPanel.POS[id]).distance_to(e.position) < 22.0:
					h = id
			if h != hover:
				hover = h
				if h != "":
					Audio.ui("ui_hover")
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and hover != "":
			selected = hover
			picked.emit(hover)
			Audio.ui("ui_click")

	func _poly(pts: Array, col: Color, w: float) -> void:
		var pv := PackedVector2Array()
		for p in pts:
			pv.append(m(p))
		draw_polyline(pv, col, w, true)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.055, 0.065, 0.055))
		# terrain contours
		for i in 9:
			var c := m(Vector2(0.8, 0.3))
			draw_arc(c, 60.0 + i * 38.0, 0, TAU, 64, Color(0.5, 0.6, 0.45, 0.05), 1.0, true)
		# grid
		for i in 21:
			var x := size.x * i / 20.0
			var y := size.y * i / 20.0
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.7, 0.85, 0.6, 0.05 if i % 5 else 0.12), 1.0)
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.7, 0.85, 0.6, 0.05 if i % 5 else 0.12), 1.0)
		# radiation zone around the blast (shrinks over the days)
		var mult := State.surface_rad_mult()
		var rr := size.x * (0.22 + 0.25 * clampf(mult / 2.0, 0.0, 1.0))
		for k in 6:
			var f := 1.0 - k / 6.0
			draw_circle(m(MapPanel.BLAST), rr * f, Color(0.55 + 0.4 * (1.0 - f), 0.75 * f + 0.1, 0.1, 0.05))
		# river
		var river := [Vector2(0.0, 0.7), Vector2(0.12, 0.66), Vector2(0.25, 0.72), Vector2(0.4, 0.78), Vector2(0.55, 0.74), Vector2(0.7, 0.8), Vector2(0.84, 0.82), Vector2(0.9, 0.78), Vector2(1.0, 0.72)]
		_poly(river, Color(0.2, 0.42, 0.6, 0.55), 14.0)
		_poly(river, Color(0.35, 0.6, 0.8, 0.8), 5.0)
		# city blocks
		for b in blocks:
			var br := Rect2(m(b.position), b.size * size)
			var burnt := (b.position as Vector2).distance_to(MapPanel.BLAST) < 0.28
			draw_rect(br, Color(0.45, 0.25, 0.18, 0.5) if burnt else Color(0.62, 0.64, 0.58, 0.3))
		# roads + rail
		_poly([Vector2(0.0, 0.52), Vector2(0.3, 0.52), Vector2(0.55, 0.56), Vector2(0.8, 0.5), Vector2(1.0, 0.48)], Color(0.86, 0.8, 0.6, 0.55), 4.0)
		_poly([Vector2(0.38, 0.0), Vector2(0.4, 0.35), Vector2(0.45, 0.6), Vector2(0.5, 1.0)], Color(0.86, 0.8, 0.6, 0.45), 3.0)
		_poly([Vector2(0.66, 0.53), Vector2(0.74, 0.38), Vector2(0.86, 0.2)], Color(0.86, 0.8, 0.6, 0.35), 2.5)
		_poly([Vector2(0.86, 0.78), Vector2(0.78, 0.62), Vector2(0.69, 0.5)], Color(0.86, 0.8, 0.6, 0.35), 2.5)
		var rail := PackedVector2Array([m(Vector2(0.0, 0.3)), m(Vector2(0.5, 0.36)), m(Vector2(1.0, 0.3))])
		draw_dashed_line(rail[0], rail[1], Color(0.8, 0.8, 0.8, 0.35), 2.0, 8.0)
		draw_dashed_line(rail[1], rail[2], Color(0.8, 0.8, 0.8, 0.35), 2.0, 8.0)
		# district labels
		var fh := Assets.font("heading")
		for lab in [[Vector2(0.2, 0.22), "CENTRU (DISTRUS)"], [Vector2(0.43, 0.2), "CARTIERUL NORD"], [Vector2(0.72, 0.66), "ZONA INDUSTRIALĂ"],
				[Vector2(0.3, 0.88), "RÂUL VAD"], [Vector2(0.88, 0.86), "BARAJUL VADULUI"], [Vector2(0.86, 0.12), "BAZA 2214"]]:
			draw_string(fh, m(lab[0]) - Vector2(100, 0), lab[1], HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color(0.85, 0.85, 0.75, 0.45))
		# blast crater
		var bc := m(MapPanel.BLAST)
		for k in 3:
			draw_arc(bc, 16.0 + k * 12.0 + sin(_t * 2.0 + k) * 2.0, 0, TAU, 40, Color(0.95, 0.3, 0.2, 0.7 - k * 0.2), 2.0, true)
		HudIcons.draw(self, "rad", Rect2(bc - Vector2(12, 12), Vector2(24, 24)), Color(0.95, 0.85, 0.3))
		draw_string(fh, bc + Vector2(-100, 52), "EPICENTRU · 14.10.2031", HORIZONTAL_ALIGNMENT_CENTER, 200, 12, Color(0.95, 0.4, 0.3, 0.9))
		HudIcons.draw(self, "water", Rect2(m(MapPanel.DAM) - Vector2(9, 9), Vector2(18, 18)), Color(0.5, 0.75, 0.95, 0.8))
		# route to the selected destination
		var bp := m(MapPanel.POS.bunker)
		if selected != "":
			var sp := m(MapPanel.POS[selected])
			var dash := fposmod(_t * 30.0, 16.0)
			var dir := (sp - bp).normalized()
			var length := bp.distance_to(sp)
			var d := dash
			while d < length:
				draw_line(bp + dir * d, bp + dir * minf(d + 8.0, length), UITheme.ACCENT, 3.0, true)
				d += 16.0
		# locations
		var avail := State.available_locations()
		for id in MapPanel.POS:
			var p := m(MapPanel.POS[id])
			if id == "bunker":
				draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color(0, 0, 0, 0.7))
				draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), UITheme.GOOD, false, 2.0)
				draw_string(fh, p + Vector2(-90, 28), "OBIECTIVUL 17", HORIZONTAL_ALIGNMENT_CENTER, 180, 13, UITheme.GOOD)
				continue
			var loc: Dictionary = ItemDB.LOCATIONS[id]
			var known := avail.has(id)
			var col := UITheme.ACCENT if known else Color(0.6, 0.6, 0.55, 0.6)
			if known:
				var halo := 18.0 + float(loc.danger) * 10.0
				draw_circle(p, halo, Color(0.95, 0.3, 0.2, 0.06 + 0.03 * sin(_t * 3.0)))
			var sel: bool = id == selected or id == hover
			draw_circle(p, 15.0 if sel else 13.0, Color(0, 0, 0, 0.75))
			draw_arc(p, 15.0 if sel else 13.0, 0, TAU, 32, col, 2.0 if sel else 1.5, true)
			if known:
				HudIcons.draw(self, MapPanel.ICONS.get(id, "objective"), Rect2(p - Vector2(8, 8), Vector2(16, 16)), col, 1.5)
				draw_string(Assets.font("bold"), p + Vector2(-110, 32), String(loc.name), HORIZONTAL_ALIGNMENT_CENTER, 220, 13, Color(UITheme.TEXT, 0.95 if sel else 0.75))
			else:
				draw_string(fh, p + Vector2(-10, 6), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, col)
		# frame, north arrow, scale
		draw_rect(r, Color(UITheme.ACCENT, 0.55), false, 2.0)
		draw_string(fh, Vector2(size.x - 44, 34), "N", HORIZONTAL_ALIGNMENT_CENTER, 24, 22, UITheme.ACCENT)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - 32, 40), Vector2(size.x - 25, 56), Vector2(size.x - 39, 56)]), UITheme.ACCENT)
		draw_line(Vector2(24, size.y - 24), Vector2(24 + size.x * 0.1, size.y - 24), Color.WHITE, 2.0)
		draw_string(Assets.font("mono"), Vector2(24, size.y - 32), "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


var map: RegionMap
var detail: VBoxContainer


func _init() -> void:
	super("PDA · Vadul Nou", 1560.0)


func build() -> void:
	var mult := State.surface_rad_mult()
	var lvl := "EXTREM" if mult > 1.2 else ("RIDICAT" if mult > 0.6 else ("MODERAT" if mult > 0.3 else "SCĂZUT"))
	body.add_child(UITheme.label("Ziua %d  ·  Radiație generală la suprafață: %s (×%.2f)  ·  Mască %s  ·  Filtre %d  ·  Costum %s" % [
		State.day, lvl, mult, "DA" if State.available("gas_mask") > 0 else "NU", State.available("mask_filter"),
		"DA" if State.available("hazmat_suit") > 0 else "nu"], 16, UITheme.TEXT_DIM, "mono"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	map = RegionMap.new()
	map.custom_minimum_size = Vector2(1040, 640)
	map.picked.connect(func(_id: String) -> void: refresh())
	row.add_child(map)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _row_style())
	dp.custom_minimum_size = Vector2(440, 640)
	row.add_child(dp)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	dp.add_child(detail)
	Audio.sfx("map_open", -4.0)
	var avail := State.available_locations()
	if not avail.is_empty():
		map.selected = avail[0]


func refresh() -> void:
	if detail == null:
		return
	clear(detail)
	var id := map.selected
	if id == "":
		detail.add_child(UITheme.heading("Alege o destinație", 22, UITheme.TEXT))
		return
	var loc: Dictionary = ItemDB.LOCATIONS[id]
	var known := State.available_locations().has(id)
	if not known:
		detail.add_child(UITheme.heading("Locație necunoscută", 22, UITheme.TEXT_DIM))
		var hint := "Ascultă radioul sau așteaptă câteva zile."
		if loc.has("req_up"):
			hint = "Necesită îmbunătățirea: " + ItemDB.UPGRADES[loc.req_up].name
		detail.add_child(UITheme.label(hint, 16, UITheme.TEXT_DIM))
		return
	detail.add_child(UITheme.label("DESTINAȚIE", 13, UITheme.ACCENT, "heading"))
	detail.add_child(UITheme.heading(loc.name, 24, UITheme.TEXT))
	var d := UITheme.label(loc.desc, 16, UITheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 410
	detail.add_child(d)
	detail.add_child(UITheme.spacer(4))
	var travel := float(loc.travel) * State.mul("travel")
	var rate := float(loc.rad) * State.surface_rad_mult() * 0.4
	var danger := "★".repeat(clampi(roundi(float(loc.danger) * 2.0), 1, 5)) + "☆".repeat(5 - clampi(roundi(float(loc.danger) * 2.0), 1, 5))
	for line in [["Drum (dus)", "%.1f h" % travel], ["Radiație de fond", "%.2f mSv/s" % rate], ["Pericol", danger],
			["Vizite", str(int(State.flags.get("visits_" + id, 0)))]]:
		var r := HBoxContainer.new()
		var a := UITheme.label(line[0], 16, UITheme.TEXT_DIM)
		a.custom_minimum_size.x = 170
		r.add_child(a)
		r.add_child(UITheme.label(line[1], 16, UITheme.TEXT, "mono"))
		detail.add_child(r)
	var kinds: Array = Expedition_MIX.get(id, [])
	if not kinds.is_empty():
		var names := {"mutant": "mutanți", "hazmat": "zombi în costum", "dog": "câini mutanți", "bandit": "jefuitori înarmați"}
		var uniq: Array = []
		for k in kinds:
			if not uniq.has(names[k]):
				uniq.append(names[k])
		detail.add_child(UITheme.label("Ostili: " + ", ".join(uniq), 15, UITheme.DANGER))
	var cats: Array = []
	for k in loc.loot:
		var c: String = ItemDB.CAT_NAMES.get(ItemDB.item(k).get("cat", ""), "")
		if c != "" and not cats.has(c):
			cats.append(c)
	var cl := UITheme.label("Pradă probabilă: " + ", ".join(cats), 15, UITheme.GOOD)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.custom_minimum_size.x = 410
	detail.add_child(cl)
	detail.add_child(UITheme.spacer(12))
	var can_go := State.available("gas_mask") > 0 and (State.available("mask_filter") > 0 or State.mask_filter_left > 10.0)
	var b := UITheme.button("Pleacă", func() -> void:
		HUD.close_all_panels()
		Game.start_expedition(id))
	b.disabled = not can_go
	detail.add_child(b)
	if not can_go:
		detail.add_child(UITheme.label("Ai nevoie de mască de gaze și cel puțin un filtru.", 15, UITheme.DANGER, "bold"))
	else:
		detail.add_child(UITheme.label("Echipamentul se ia automat din depozit.", 14, UITheme.TEXT_DIM))


const Expedition_MIX := {
	"factory": ["mutant", "dog"], "market": ["mutant", "bandit"], "hospital": ["hazmat", "mutant"],
	"police": ["bandit", "mutant"], "military": ["bandit", "hazmat", "dog"], "metro": ["mutant", "dog", "bandit"],
}
