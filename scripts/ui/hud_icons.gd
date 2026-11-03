class_name HudIcons
extends RefCounted
## Crisp vector icons drawn with CanvasItem primitives (no textures needed).
## Every icon fits the rect `r`.


static func draw(ci: CanvasItem, kind: String, r: Rect2, col: Color, w := 2.0) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match kind:
		"health": _heart(ci, c, s * 0.42, col)
		"food": _can(ci, c, s, col, w)
		"water", "thirst": _drop(ci, c, s * 0.42, col)
		"energy", "fatigue": _moon(ci, c, s * 0.38, col)
		"rad": _trefoil(ci, c, s * 0.46, col)
		"bleed": _bleed(ci, c, s, col)
		"weight": _weight(ci, c, s, col, w)
		"air": _air(ci, c, s, col, w)
		"filter": _filter(ci, c, s, col, w)
		"power": _bolt(ci, c, s, col)
		"battery": _battery(ci, c, s, col, w)
		"fuel": _jerrycan(ci, c, s, col, w)
		"ammo": _bullet(ci, c, s, col)
		"stamina": _run(ci, c, s, col, w)
		"flashlight": _flashlight(ci, c, s, col, w)
		"med": _cross(ci, c, s, col)
		"res": _gear(ci, c, s * 0.4, col, w)
		"tool": _wrench(ci, c, s, col, w)
		"gear": _mask(ci, c, s, col, w)
		"weapon": _pistol(ci, c, s, col)
		"seed": _sprout(ci, c, s, col, w)
		"drink": _drop(ci, c, s * 0.42, col)
		"radio": _radio(ci, c, s, col, w)
		"skull": _skull(ci, c, s, col)
		"objective": _diamond(ci, c, s * 0.42, col, w)
		_: ci.draw_circle(c, s * 0.3, col)


static func _heart(ci: CanvasItem, c: Vector2, rr: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := float(i) / 40.0 * TAU
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * rr / 17.0)
	ci.draw_colored_polygon(pts, col)


static func _drop(ci: CanvasItem, c: Vector2, rr: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -rr * 1.25))
	for i in 25:
		var a := lerpf(-0.2, PI + 0.2, float(i) / 24.0)
		pts.append(c + Vector2(cos(a) * rr * 0.78, sin(a) * rr * 0.78 + rr * 0.3))
	ci.draw_colored_polygon(pts, col)


static func _moon(ci: CanvasItem, c: Vector2, rr: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := lerpf(PI * 0.35, PI * 1.65, float(i) / 32.0)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	for i in 33:
		var a := lerpf(PI * 1.45, PI * 0.55, float(i) / 32.0)
		pts.append(c + Vector2(rr * 0.42, 0) + Vector2(cos(a), sin(a)) * rr * 0.78)
	ci.draw_colored_polygon(pts, col)


static func _trefoil(ci: CanvasItem, c: Vector2, rr: float, col: Color) -> void:
	for k in 3:
		var base := -PI / 2 + k * TAU / 3.0
		var pts := PackedVector2Array([c + Vector2(cos(base), sin(base)) * rr * 0.22])
		for i in 13:
			var a := base - 0.5 + float(i) / 12.0 * 1.0
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c, rr * 0.16, col)


static func _can(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var r := Rect2(c - Vector2(s * 0.26, s * 0.32), Vector2(s * 0.52, s * 0.64))
	ci.draw_rect(r, col, false, w)
	ci.draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.3), Vector2(r.end.x, r.position.y + r.size.y * 0.3), col, w)
	ci.draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.7), Vector2(r.end.x, r.position.y + r.size.y * 0.7), col, w)


static func _bleed(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_drop(ci, c + Vector2(-s * 0.12, 0), s * 0.3, col)
	_drop(ci, c + Vector2(s * 0.22, s * 0.12), s * 0.18, col)


static func _weight(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.1), c + Vector2(s * 0.22, -s * 0.1), c + Vector2(s * 0.34, s * 0.34), c + Vector2(-s * 0.34, s * 0.34)])
	ci.draw_colored_polygon(pts, col)
	ci.draw_arc(c + Vector2(0, -s * 0.18), s * 0.14, PI, TAU, 16, col, w, true)


static func _air(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	for i in 3:
		var y := c.y - s * 0.22 + i * s * 0.22
		var x0 := c.x - s * 0.34
		var x1 := c.x + s * (0.18 - i * 0.08)
		ci.draw_line(Vector2(x0, y), Vector2(x1, y), col, w, true)
		ci.draw_arc(Vector2(x1, y - s * 0.08), s * 0.08, PI * 0.5, PI * 2.2, 10, col, w, true)


static func _filter(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_arc(c, s * 0.34, 0, TAU, 28, col, w, true)
	for i in 3:
		var y := c.y - s * 0.15 + i * s * 0.15
		ci.draw_line(Vector2(c.x - s * 0.22, y), Vector2(c.x + s * 0.22, y), col, w * 0.7)


static func _bolt(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var k := s / 24.0
	var pts := PackedVector2Array([Vector2(2, -11), Vector2(-7, 2), Vector2(-1, 2), Vector2(-3, 11), Vector2(7, -3), Vector2(1, -3), Vector2(3, -11)])
	for i in pts.size():
		pts[i] = c + pts[i] * k
	ci.draw_colored_polygon(pts, col)


static func _battery(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var r := Rect2(c - Vector2(s * 0.36, s * 0.2), Vector2(s * 0.64, s * 0.4))
	ci.draw_rect(r, col, false, w)
	ci.draw_rect(Rect2(Vector2(r.end.x, c.y - s * 0.08), Vector2(s * 0.08, s * 0.16)), col)
	ci.draw_rect(Rect2(r.position + Vector2(w * 1.5, w * 1.5), Vector2(r.size.x * 0.55, r.size.y - w * 3)), col)


static func _jerrycan(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.18), c + Vector2(-s * 0.1, -s * 0.34), c + Vector2(s * 0.26, -s * 0.34),
		c + Vector2(s * 0.26, s * 0.36), c + Vector2(-s * 0.26, s * 0.36), c + Vector2(-s * 0.26, -s * 0.18)])
	ci.draw_polyline(pts, col, w, true)
	ci.draw_line(c + Vector2(-s * 0.14, -s * 0.04), c + Vector2(s * 0.14, s * 0.24), col, w * 0.8)
	ci.draw_line(c + Vector2(s * 0.14, -s * 0.04), c + Vector2(-s * 0.14, s * 0.24), col, w * 0.8)


static func _bullet(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var r := Rect2(c - Vector2(s * 0.09, s * 0.05), Vector2(s * 0.18, s * 0.38))
	ci.draw_rect(r, col)
	var pts := PackedVector2Array([Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(c.x, c.y - s * 0.34)])
	ci.draw_colored_polygon(pts, col)


static func _run(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_circle(c + Vector2(s * 0.08, -s * 0.3), s * 0.08, col)
	ci.draw_line(c + Vector2(s * 0.04, -s * 0.18), c + Vector2(-s * 0.06, s * 0.08), col, w)
	ci.draw_line(c + Vector2(-s * 0.06, s * 0.08), c + Vector2(s * 0.14, s * 0.34), col, w)
	ci.draw_line(c + Vector2(-s * 0.06, s * 0.08), c + Vector2(-s * 0.24, s * 0.32), col, w)
	ci.draw_line(c + Vector2(s * 0.02, -s * 0.12), c + Vector2(s * 0.24, -s * 0.02), col, w)
	ci.draw_line(c + Vector2(s * 0.02, -s * 0.12), c + Vector2(-s * 0.2, -s * 0.06), col, w)


static func _flashlight(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.08), Vector2(s * 0.3, s * 0.16)), col)
	var pts := PackedVector2Array([c + Vector2(-s * 0.06, -s * 0.14), c + Vector2(s * 0.06, -s * 0.14), c + Vector2(s * 0.06, s * 0.14), c + Vector2(-s * 0.06, s * 0.14)])
	ci.draw_colored_polygon(pts, col)
	for i in 3:
		var a := -0.45 + i * 0.45
		ci.draw_line(c + Vector2(s * 0.14, 0) + Vector2(cos(a), sin(a)) * s * 0.06, c + Vector2(s * 0.14, 0) + Vector2(cos(a), sin(a)) * s * 0.26, col, w * 0.8)


static func _cross(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(c - Vector2(s * 0.09, s * 0.3), Vector2(s * 0.18, s * 0.6)), col)
	ci.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.09), Vector2(s * 0.6, s * 0.18)), col)


static func _gear(ci: CanvasItem, c: Vector2, rr: float, col: Color, w: float) -> void:
	for i in 8:
		var a := i * TAU / 8.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * rr * 0.7, c + Vector2(cos(a), sin(a)) * rr * 1.1, col, w * 1.6)
	ci.draw_arc(c, rr * 0.72, 0, TAU, 24, col, w * 1.2, true)
	ci.draw_arc(c, rr * 0.28, 0, TAU, 16, col, w, true)


static func _wrench(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_line(c + Vector2(-s * 0.26, s * 0.26), c + Vector2(s * 0.12, -s * 0.12), col, w * 2.0)
	ci.draw_arc(c + Vector2(s * 0.18, -s * 0.18), s * 0.14, PI * 0.9, PI * 2.6, 16, col, w * 1.5, true)


static func _mask(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.04), s * 0.32, PI * 1.0, TAU, 20, col, w, true)
	ci.draw_line(c + Vector2(-s * 0.32, -s * 0.04), c + Vector2(-s * 0.2, s * 0.24), col, w)
	ci.draw_line(c + Vector2(s * 0.32, -s * 0.04), c + Vector2(s * 0.2, s * 0.24), col, w)
	ci.draw_circle(c + Vector2(-s * 0.13, -s * 0.08), s * 0.08, col)
	ci.draw_circle(c + Vector2(s * 0.13, -s * 0.08), s * 0.08, col)
	ci.draw_circle(c + Vector2(0, s * 0.24), s * 0.1, col)


static func _pistol(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.2), Vector2(s * 0.66, s * 0.16)), col)
	var pts := PackedVector2Array([c + Vector2(s * 0.1, -s * 0.05), c + Vector2(s * 0.28, -s * 0.05), c + Vector2(s * 0.2, s * 0.32), c + Vector2(s * 0.02, s * 0.32)])
	ci.draw_colored_polygon(pts, col)


static func _sprout(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_line(c + Vector2(0, s * 0.34), c + Vector2(0, -s * 0.05), col, w)
	ci.draw_arc(c + Vector2(-s * 0.14, -s * 0.08), s * 0.14, PI * 1.6, PI * 2.6, 12, col, w, true)
	ci.draw_arc(c + Vector2(s * 0.14, -s * 0.16), s * 0.14, PI * 0.4, PI * 1.4, 12, col, w, true)
	ci.draw_line(c + Vector2(-s * 0.26, s * 0.34), c + Vector2(s * 0.26, s * 0.34), col, w)


static func _radio(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.06), Vector2(s * 0.6, s * 0.36)), col, false, w)
	ci.draw_line(c + Vector2(s * 0.18, -s * 0.06), c + Vector2(s * 0.3, -s * 0.38), col, w)
	ci.draw_circle(c + Vector2(-s * 0.12, s * 0.12), s * 0.08, col)


static func _skull(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(0, -s * 0.06), s * 0.28, col)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.16, s * 0.12), Vector2(s * 0.32, s * 0.2)), col)
	var bg := Color(0, 0, 0, 0.85)
	ci.draw_circle(c + Vector2(-s * 0.11, -s * 0.06), s * 0.08, bg)
	ci.draw_circle(c + Vector2(s * 0.11, -s * 0.06), s * 0.08, bg)


static func _diamond(ci: CanvasItem, c: Vector2, rr: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr * 0.8, 0), c + Vector2(0, rr), c + Vector2(-rr * 0.8, 0), c + Vector2(0, -rr)])
	ci.draw_colored_polygon(pts.slice(0, 4), Color(col, col.a * 0.25))
	ci.draw_polyline(pts, col, w, true)


## Category icon name for an item.
static func for_item(id: String) -> String:
	var cat: String = ItemDB.item(id).get("cat", "res")
	match cat:
		"food": return "food"
		"drink": return "water"
		"med": return "med"
		"fuel": return "fuel"
		"gear": return "filter" if id.contains("filter") else "gear"
		"weapon": return "weapon"
		"ammo": return "ammo"
		"tool": return "flashlight" if id == "flashlight" else ("rad" if id == "geiger" else "tool")
		"seed": return "seed"
	return "res"
