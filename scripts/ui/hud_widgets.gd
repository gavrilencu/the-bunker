class_name HudWidgets
extends RefCounted
## Custom-drawn HUD widgets (STALKER-2-like clean military look).

const WHITE := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.62, 0.58)
const FAINT := Color(1, 1, 1, 0.14)
const BG := Color(0.02, 0.025, 0.022, 0.55)
const ACC := Color(0.96, 0.66, 0.22)
const RED := Color(0.94, 0.27, 0.22)
const YEL := Color(0.98, 0.8, 0.3)
const GRN := Color(0.56, 0.86, 0.42)
const BLU := Color(0.45, 0.72, 0.98)


class Base extends Control:
	var fade := 1.0
	var _fade_target := 1.0
	var _idle := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func txt(p: Vector2, s: String, size: int, col: Color, kind := "body", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
		var f := Assets.font(kind)
		draw_string(f, p + Vector2(1, 1), s, align, width, size, Color(0, 0, 0, col.a * 0.6))
		draw_string(f, p, s, align, width, size, col)

	func txt_w(s: String, size: int, kind := "body") -> float:
		return Assets.font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

	## Panel background: soft dark gradient + hairline border + corner ticks.
	func panel(r: Rect2, a := 1.0, accent := ACC) -> void:
		var top := Color(BG, BG.a * a)
		var bot := Color(BG, BG.a * 0.6 * a)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top, top, bot, bot]))
		draw_rect(r, Color(1, 1, 1, 0.07 * a), false, 1.0)
		var k := 8.0
		var ca := Color(accent, 0.8 * a)
		draw_line(r.position, r.position + Vector2(k, 0), ca, 2.0)
		draw_line(r.position, r.position + Vector2(0, k), ca, 2.0)
		draw_line(r.end, r.end - Vector2(k, 0), ca, 2.0)
		draw_line(r.end, r.end - Vector2(0, k), ca, 2.0)

	func bar(r: Rect2, v: float, col: Color, segments := 0, ghost := -1.0, a := 1.0) -> void:
		draw_rect(r, Color(0, 0, 0, 0.5 * a))
		if ghost > v:
			draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ghost, 0, 1), r.size.y)), Color(1, 1, 1, 0.35 * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0, 1), r.size.y)), Color(col, col.a * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0, 1), maxf(1.0, r.size.y * 0.35))), Color(1, 1, 1, 0.18 * a))
		if segments > 1:
			for i in range(1, segments):
				var x := r.position.x + r.size.x * float(i) / segments
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.55 * a), 2.0)

	## Dynamic-HUD helper: call each frame; `active` keeps it visible.
	func update_fade(delta: float, active: bool, dynamic: bool, linger := 4.0) -> void:
		if active or not dynamic:
			_idle = 0.0
			_fade_target = 1.0
		else:
			_idle += delta
			if _idle > linger:
				_fade_target = 0.0
		fade = move_toward(fade, _fade_target, delta * 2.5)
		modulate.a = fade


static func sev_color(level: int) -> Color:
	return RED if level >= 2 else (YEL if level == 1 else WHITE)


# ==========================================================================
# Compass
# ==========================================================================
class Compass extends Base:
	const SPAN := 130.0
	var heading := 0.0
	var markers: Array = []  # [{bearing, color, icon, dist}]

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		# soft background band fading at the ends
		var mid := Color(0, 0, 0, 0.42)
		var clear := Color(0, 0, 0, 0)
		var y0 := 6.0
		var y1 := 30.0
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(cx, y0), Vector2(cx, y1), Vector2(0, y1)]), PackedColorArray([clear, mid, mid, clear]))
		draw_polygon(PackedVector2Array([Vector2(cx, y0), Vector2(w, y0), Vector2(w, y1), Vector2(cx, y1)]), PackedColorArray([mid, clear, clear, mid]))
		var ppd := w / SPAN
		var start := int(floor((heading - SPAN * 0.5) / 5.0)) * 5
		var labels := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SV", 270: "V", 315: "NV"}
		for d in range(start, int(heading + SPAN * 0.5) + 5, 5):
			var x := cx + (d - heading) * ppd
			var edge := 1.0 - clampf(absf(x - cx) / (w * 0.5), 0.0, 1.0)
			var a := smoothstep(0.0, 0.35, edge)
			var dd := posmod(d, 360)
			if labels.has(dd):
				var lab: String = labels[dd]
				var col := ACC if dd == 0 else WHITE
				txt(Vector2(x - 30, 25), lab, 17 if lab.length() == 1 else 14, Color(col, a), "heading", HORIZONTAL_ALIGNMENT_CENTER, 60)
			elif dd % 15 == 0:
				draw_line(Vector2(x, 10), Vector2(x, 20), Color(WHITE, 0.55 * a), 1.5)
				txt(Vector2(x - 20, 40), str(dd), 10, Color(DIM, 0.8 * a), "mono", HORIZONTAL_ALIGNMENT_CENTER, 40)
			else:
				draw_line(Vector2(x, 13), Vector2(x, 18), Color(WHITE, 0.3 * a), 1.0)
		# markers
		for m in markers:
			var delta := wrapf(float(m.bearing) - heading, -180.0, 180.0)
			var clamped := clampf(delta, -SPAN * 0.5 + 3.0, SPAN * 0.5 - 3.0)
			var x := cx + clamped * ppd
			var col: Color = m.color
			HudIcons.draw(self, m.icon, Rect2(x - 9, 0, 18, 18), col, 2.0)
			if absf(delta) <= SPAN * 0.5:
				txt(Vector2(x - 30, 54), "%d m" % int(m.dist), 12, Color(col, 0.9), "mono", HORIZONTAL_ALIGNMENT_CENTER, 60)
			else:
				var arrow := "◀" if delta < 0 else "▶"
				txt(Vector2(x - 20, 54), arrow, 12, col, "body", HORIZONTAL_ALIGNMENT_CENTER, 40)
		# centre pointer + heading readout
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, h - 14), Vector2(cx + 5, h - 14), Vector2(cx, h - 21)]), ACC)
		var hs := "%03d" % (int(round(heading)) % 360)
		draw_rect(Rect2(cx - 22, h - 13, 44, 13), Color(0, 0, 0, 0.5))
		txt(Vector2(cx - 22, h - 2), hs, 11, WHITE, "mono", HORIZONTAL_ALIGNMENT_CENTER, 44)


# ==========================================================================
# Vitals (bottom-left)
# ==========================================================================
class Vitals extends Base:
	var hp := 1.0
	var hp_ghost := 1.0
	var stamina := 1.0
	var needs := {"food": 1.0, "water": 1.0, "energy": 1.0}
	var statuses: Array = []  # [{icon, level, value}]
	var dynamic := true
	var show_needs := true
	var _t := 0.0
	var _needs_fade := 1.0
	var _stam_fade := 0.0

	func tick(delta: float) -> void:
		_t += delta
		hp_ghost = maxf(move_toward(hp_ghost, hp, delta * 0.25), hp)
		var needs_low := false
		for k in needs:
			if needs[k] < 0.55:
				needs_low = true
		_needs_fade = move_toward(_needs_fade, 1.0 if (needs_low or not dynamic) else 0.0, delta * 2.0)
		_stam_fade = move_toward(_stam_fade, 1.0 if (stamina < 0.99 or not dynamic) else 0.0, delta * (4.0 if stamina < 0.99 else 1.2))
		queue_redraw()

	func _draw() -> void:
		var x := 0.0
		var y := size.y
		# status icons row
		var ix := 0.0
		for st in statuses:
			var lvl: int = st.level
			var col := HudWidgets.sev_color(lvl)
			var pulse := 1.0
			if lvl >= 2:
				pulse = 0.55 + 0.45 * absf(sin(_t * 4.0))
			var r := Rect2(ix, y - 112, 34, 34)
			draw_rect(r, Color(0, 0, 0, 0.5))
			draw_rect(r, Color(col, 0.6 * pulse), false, 1.5)
			draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Color(col, 0.9 * pulse))
			HudIcons.draw(self, st.icon, r.grow(-6), Color(col, pulse), 2.0)
			if st.has("value"):
				txt(Vector2(ix, y - 117), str(st.value), 11, Color(col, 0.95), "mono", HORIZONTAL_ALIGNMENT_CENTER, 34)
			ix += 40
		# health
		var hcol := RED if hp < 0.3 else WHITE
		if hp < 0.3:
			hcol = hcol.lerp(WHITE, absf(sin(_t * 5.0)) * 0.4)
		HudIcons.draw(self, "health", Rect2(x, y - 64, 20, 20), Color(hcol, 0.95))
		txt(Vector2(x + 28, y - 46), "%d" % roundi(hp * 100.0), 22, hcol, "mono")
		bar(Rect2(x + 74, y - 59, 260, 9), hp, Color(0.88, 0.86, 0.8) if hp >= 0.3 else RED, 10, hp_ghost)
		# stamina
		var sa := _stam_fade
		if sa > 0.01:
			HudIcons.draw(self, "stamina", Rect2(x + 2, y - 38, 16, 16), Color(DIM, sa))
			bar(Rect2(x + 74, y - 33, 260, 4), stamina, Color(0.75, 0.82, 0.6, 0.9) if stamina > 0.25 else YEL, 0, -1.0, sa)
		# needs (food / water / energy)
		var na := _needs_fade
		if na > 0.01 and show_needs:
			var nx := x + 74
			for k in ["food", "water", "energy"]:
				var vv: float = needs[k]
				var col := RED if vv < 0.15 else (YEL if vv < 0.35 else Color(0.8, 0.8, 0.76))
				HudIcons.draw(self, k, Rect2(nx, y - 22, 14, 14), Color(col, na))
				bar(Rect2(nx + 18, y - 16, 62, 3), vv, col, 0, -1.0, na)
				nx += 90


# ==========================================================================
# Weapon / equipment (bottom-right)
# ==========================================================================
class WeaponBox extends Base:
	var name_text := ""
	var mag := -1
	var mag_max := 0
	var reserve := 0
	var slot := 0
	var bandages := 0
	var flashlight := false
	var reloading := false
	var reload_p := -1.0   # 0..1 while reloading
	var icon_item := ""    # item id: the rendered weapon silhouette
	var _mag_shown := -1
	var _pop := 0.0

	func tick(delta: float) -> void:
		if mag != _mag_shown:
			_mag_shown = mag
			_pop = 1.0
		_pop = maxf(_pop - delta * 4.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if name_text == "":
			return
		var r := Rect2(w - 300, h - 84, 300, 84)
		panel(r, 1.0)
		# weapon silhouette (rendered from the model), name beside it
		var tex := IconFactory.get_icon(icon_item) if icon_item != "" else null
		var nx := r.position.x + 16
		if tex:
			draw_texture_rect(tex, Rect2(r.position.x + 8, r.position.y + 4, 64, 44), false, Color(1, 1, 1, 0.9))
			nx = r.position.x + 78
		txt(Vector2(nx, r.position.y + 22), name_text.to_upper(), 14, DIM, "heading")
		if mag >= 0:
			var ms := "%d" % mag
			var col := RED if mag == 0 else (YEL if mag <= 2 else WHITE)
			var fs := 44 + int(_pop * 6.0)
			txt(Vector2(r.end.x - 120, r.end.y - 18), ms, fs, col, "mono", HORIZONTAL_ALIGNMENT_RIGHT, 60)
			txt(Vector2(r.end.x - 56, r.end.y - 20), "/ %d" % reserve, 20, DIM, "mono")
			# the magazine as cartridges
			if mag_max > 0:
				var n := mini(mag_max, 30)
				var pw := 4.0 if n > 15 else 6.0
				var px := nx
				for i in n:
					var lit := i < mag
					var pr := Rect2(px, r.position.y + 30, pw, 13)
					draw_rect(pr, Color(col if lit else FAINT, 0.95 if lit else 0.5))
					if lit:
						draw_rect(Rect2(px, r.position.y + 30, pw, 3), Color(1, 0.85, 0.55, 0.9))
					px += pw + 2
			if reloading:
				txt(Vector2(r.position.x + 16, r.end.y - 18), "REÎNCARCĂ", 14, YEL, "bold")
				if reload_p >= 0.0:
					draw_rect(Rect2(r.position.x + 110, r.end.y - 25, 70, 3), Color(FAINT, 0.6))
					draw_rect(Rect2(r.position.x + 110, r.end.y - 25, 70 * clampf(reload_p, 0.0, 1.0), 3), YEL)
		else:
			txt(Vector2(r.end.x - 200, r.end.y - 20), "CORP LA CORP", 18, WHITE, "heading", HORIZONTAL_ALIGNMENT_RIGHT, 184)
		# slots
		for i in 4:
			var sr := Rect2(r.position.x + 16 + i * 26, r.end.y - 36, 20, 20)
			var on := slot == i + 1
			draw_rect(sr, Color(0, 0, 0, 0.4))
			draw_rect(sr, Color(ACC if on else FAINT, 0.9 if on else 1.0), false, 1.5)
			txt(Vector2(sr.position.x, sr.end.y - 5), str(i + 1), 12, ACC if on else DIM, "mono", HORIZONTAL_ALIGNMENT_CENTER, 20)
		# small status row above the panel
		var sx := w - 300.0
		HudIcons.draw(self, "med", Rect2(sx, h - 108, 16, 16), WHITE if bandages > 0 else DIM)
		txt(Vector2(sx + 20, h - 95), "H ×%d" % bandages, 13, WHITE if bandages > 0 else DIM, "mono")
		if flashlight:
			HudIcons.draw(self, "flashlight", Rect2(sx + 80, h - 108, 18, 16), ACC)


# ==========================================================================
# Dosimeter + mask filter (surface)
# ==========================================================================
class Dosimeter extends Base:
	var has_geiger := false
	var rate := 0.0
	var dose := 0.0
	var filter_s := 360.0
	var spare := 0
	var weight := 0.0
	var cap := 30.0
	var _t := 0.0

	func _draw() -> void:
		_t += get_process_delta_time()
		var w := size.x
		var r := Rect2(w - 300, 0, 300, 112)
		panel(r, 1.0, GRN if rate < 0.6 else (YEL if rate < 1.5 else RED))
		# filter ring
		var c := r.position + Vector2(48, 56)
		var frac := clampf(filter_s / 360.0, 0.0, 1.0)
		var fcol := RED if filter_s < 45.0 else (YEL if filter_s < 120.0 else WHITE)
		draw_arc(c, 32, 0, TAU, 48, Color(1, 1, 1, 0.1), 5.0, true)
		draw_arc(c, 32, -PI / 2, -PI / 2 + TAU * frac, 48, fcol, 5.0, true)
		HudIcons.draw(self, "filter", Rect2(c - Vector2(10, 22), Vector2(20, 18)), Color(fcol, 0.8), 1.5)
		txt(Vector2(c.x - 30, c.y + 10), "%d:%02d" % [int(filter_s) / 60, int(filter_s) % 60], 15, fcol, "mono", HORIZONTAL_ALIGNMENT_CENTER, 60)
		txt(Vector2(c.x - 30, c.y + 26), "+%d" % spare, 11, DIM, "mono", HORIZONTAL_ALIGNMENT_CENTER, 60)
		# dosimeter readout
		var x0 := r.position.x + 98
		txt(Vector2(x0, r.position.y + 20), "DOZIMETRU", 12, DIM, "heading")
		if has_geiger:
			var col := GRN if rate < 0.6 else (YEL if rate < 1.5 else RED)
			if rate >= 1.5:
				col = col.lerp(WHITE, absf(sin(_t * 8.0)) * 0.3)
			txt(Vector2(x0, r.position.y + 52), "%.2f" % rate, 30, col, "mono")
			txt(Vector2(x0 + 88, r.position.y + 52), "mSv/s", 12, DIM, "mono")
			# log-scale bar graph
			var segs := 16
			var lv := clampf(log(1.0 + rate * 4.0) / log(1.0 + 4.0 * 4.0), 0.0, 1.0)
			for i in segs:
				var on := float(i) / segs < lv
				var sc := GRN.lerp(YEL, float(i) / segs * 1.6).lerp(RED, maxf(float(i) / segs - 0.6, 0.0) * 2.5)
				draw_rect(Rect2(x0 + i * 11, r.position.y + 62, 8, 10), Color(sc, 0.95) if on else Color(1, 1, 1, 0.08))
		else:
			txt(Vector2(x0, r.position.y + 52), "--.--", 30, DIM, "mono")
			txt(Vector2(x0, r.position.y + 70), "fără contor Geiger", 11, DIM)
		txt(Vector2(x0, r.position.y + 92), "DOZĂ %d mSv" % roundi(dose), 13, WHITE if dose < 250 else RED, "mono")
		# weight
		var wcol := RED if weight > cap * 1.5 else (YEL if weight > cap else DIM)
		HudIcons.draw(self, "weight", Rect2(r.end.x - 74, r.position.y + 80, 14, 14), wcol)
		txt(Vector2(r.end.x - 56, r.position.y + 93), "%.1f/%d" % [weight, int(cap)], 12, wcol, "mono")


# ==========================================================================
# Bunker systems (bottom-right in the bunker)
# ==========================================================================
class Systems extends Base:
	var rows: Array = []  # [{icon, label, value(0..1), text, level}]

	func _draw() -> void:
		var w := size.x
		var hgt := 34.0 + rows.size() * 26.0
		var r := Rect2(w - 320, size.y - hgt, 320, hgt)
		panel(r, 1.0)
		txt(Vector2(r.position.x + 14, r.position.y + 20), "OBIECTIVUL 17  ·  SISTEME", 12, DIM, "heading")
		var y := r.position.y + 34
		for row in rows:
			var col := HudWidgets.sev_color(int(row.level))
			HudIcons.draw(self, row.icon, Rect2(r.position.x + 12, y, 16, 16), col)
			txt(Vector2(r.position.x + 36, y + 13), row.label, 13, WHITE, "bold")
			bar(Rect2(r.position.x + 118, y + 6, 110, 5), float(row.value), col if int(row.level) > 0 else Color(0.85, 0.84, 0.8))
			txt(Vector2(r.position.x + 236, y + 13), row.text, 12, col, "mono", HORIZONTAL_ALIGNMENT_RIGHT, 72)
			y += 26


# ==========================================================================
# Reticle: crosshair, hold ring, hit markers, damage direction
# ==========================================================================
class Reticle extends Base:
	var spread := 0.0
	var weapon := false
	var active := false
	var progress := 0.0
	var _hit := 0.0
	var _kill := false
	var damage_dirs: Array = []  # [{angle, t}]

	func hitmarker(kill: bool) -> void:
		_hit = 1.0
		_kill = kill

	func add_damage(angle: float) -> void:
		damage_dirs.append({"angle": angle, "t": 1.6})

	func tick(delta: float) -> void:
		_hit = maxf(_hit - delta * 4.0, 0.0)
		for d in damage_dirs:
			d.t -= delta
		damage_dirs = damage_dirs.filter(func(d) -> bool: return d.t > 0.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if weapon and not active:
			var g := 7.0 + spread * 22.0
			var col := Color(1, 1, 1, 0.85)
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + dir * g, c + dir * (g + 8.0), Color(0, 0, 0, 0.5), 3.5)
				draw_line(c + dir * g, c + dir * (g + 8.0), col, 1.6)
			draw_circle(c, 1.4, col)
		else:
			draw_circle(c, 3.0 if active else 2.0, Color(0, 0, 0, 0.5))
			draw_circle(c, 2.2 if active else 1.6, ACC if active else Color(1, 1, 1, 0.8))
		if active and progress <= 0.0:
			draw_arc(c, 9.0, 0, TAU, 28, Color(ACC, 0.7), 1.5, true)
		if progress > 0.0:
			draw_arc(c, 20.0, 0, TAU, 48, Color(0, 0, 0, 0.45), 6.0, true)
			draw_arc(c, 20.0, -PI / 2, -PI / 2 + TAU * progress, 48, ACC, 3.0, true)
		if _hit > 0.0:
			var hc := Color(RED if _kill else WHITE, _hit)
			for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
				var d := Vector2(cos(a), sin(a))
				draw_line(c + d * 8.0, c + d * 16.0, hc, 2.2, true)
		for d in damage_dirs:
			var a: float = d.angle - PI / 2
			var alpha := clampf(float(d.t) / 1.6, 0.0, 1.0)
			draw_arc(c, 150.0, a - 0.32, a + 0.32, 24, Color(RED, 0.85 * alpha), 7.0, true)
			draw_arc(c, 142.0, a - 0.2, a + 0.2, 16, Color(RED, 0.4 * alpha), 3.0, true)


# ==========================================================================
# Interaction prompt (under the reticle)
# ==========================================================================
class Prompt extends Base:
	var title := ""
	var action := ""
	var hold := false
	## secondary actions: [[key, text], ...] drawn as one row under the main action
	var alt: Array = []

	func _draw() -> void:
		var c := size.x * 0.5
		if not alt.is_empty():
			var gap := 22.0
			var total := -gap
			for a in alt:
				total += txt_w(a[1], 15, "bold") + 30.0 + gap
			var ax := c - total * 0.5
			var ay := 46.0 if action != "" else 14.0
			for a in alt:
				var ar := Rect2(ax, ay, 22, 20)
				draw_rect(ar, Color(0, 0, 0, 0.55))
				draw_rect(ar, Color(1, 1, 1, 0.6), false, 1.2)
				txt(Vector2(ar.position.x, ar.end.y - 5), a[0], 13, WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER, 22)
				txt(Vector2(ax + 30, ay + 15), a[1], 15, DIM, "bold")
				ax += txt_w(a[1], 15, "bold") + 30.0 + gap
		if action == "":
			if title != "" and not alt.is_empty():
				txt(Vector2(c - 300, 2), title.to_upper(), 13, ACC, "heading", HORIZONTAL_ALIGNMENT_CENTER, 600)
			return
		var key := "E"
		var hint := "ține" if hold else ""
		var fs := 19
		var tw := txt_w(action, fs, "bold")
		var kw := 26.0
		var total := kw + 10.0 + tw + (txt_w(hint, 13) + 6.0 if hold else 0.0)
		var x := c - total * 0.5
		if title != "":
			txt(Vector2(c - 300, 2), title.to_upper(), 13, ACC, "heading", HORIZONTAL_ALIGNMENT_CENTER, 600)
		var y := 14.0
		var kr := Rect2(x, y, kw, 26)
		draw_rect(kr, Color(0, 0, 0, 0.55))
		draw_rect(kr, Color(1, 1, 1, 0.85), false, 1.5)
		txt(Vector2(kr.position.x, kr.end.y - 7), key, 16, WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER, kw)
		x += kw + 8
		if hold:
			txt(Vector2(x, y + 19), hint, 13, DIM)
			x += txt_w(hint, 13) + 6
		txt(Vector2(x, y + 20), action, fs, WHITE, "bold")


# ==========================================================================
# Placement bar (bottom centre, while building / moving furniture)
# ==========================================================================
class PlaceBar extends Base:
	## {title, sub, ok, status, keys: [[key, text], ...]}; empty hides the bar
	var info := {}

	func _draw() -> void:
		if info.is_empty():
			return
		var ok: bool = info.get("ok", false)
		var col := GRN if ok else RED
		var keys: Array = info.get("keys", [])
		var row_w := 0.0
		for k in keys:
			row_w += _cap_w(k[0]) + 8.0 + txt_w(k[1], 15, "bold") + 22.0
		var w := maxf(row_w + 28.0, 640.0)
		var r := Rect2((size.x - w) * 0.5, 0, w, 104)
		panel(r, 1.0, col)
		var x := r.position.x + 16.0
		txt(Vector2(x, 26), String(info.get("title", "")).to_upper(), 17, ACC, "heading")
		var st: String = ("✓  " if ok else "✕  ") + String(info.get("status", ""))
		txt(Vector2(r.end.x - 16.0 - txt_w(st, 15, "bold"), 26), st, 15, col, "bold")
		var sub: String = info.get("sub", "")
		if sub != "":
			txt(Vector2(x, 48), sub, 14, DIM)
		var y := 66.0
		for k in keys:
			var cw := _cap_w(k[0])
			var kr := Rect2(x, y, cw, 24)
			draw_rect(kr, Color(0, 0, 0, 0.55))
			draw_rect(kr, Color(1, 1, 1, 0.7), false, 1.2)
			txt(Vector2(kr.position.x, kr.end.y - 7), k[0], 12, WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER, cw)
			x += cw + 8.0
			txt(Vector2(x, y + 18), k[1], 15, WHITE, "bold")
			x += txt_w(k[1], 15, "bold") + 22.0

	func _cap_w(k: String) -> float:
		return maxf(txt_w(k, 12, "bold") + 14.0, 24.0)


# ==========================================================================
# What is in the hands (food / water / bandage): how much is left + the keys
# ==========================================================================
class HeldBox extends Base:
	## {name, count, frac, verb, busy, kind}; empty hides it
	var info := {}
	var _shown := 0.0

	func _draw() -> void:
		if info.is_empty():
			return
		var w := 420.0
		var r := Rect2((size.x - w) * 0.5, 0, w, 84)
		panel(r, 1.0, ACC)
		var x := r.position.x + 16.0
		var title := String(info.get("name", "")).to_upper()
		txt(Vector2(x, 26), title, 17, ACC, "heading")
		var cnt := int(info.get("count", 1))
		if cnt > 1:
			txt(Vector2(x + txt_w(title, 17, "heading") + 10.0, 26), "×%d" % cnt, 15, DIM, "bold")
		var frac := clampf(float(info.get("frac", 1.0)), 0.0, 1.0)
		var bandage := String(info.get("kind", "")) == "bandage"
		var pct := ("%d%%" % roundi(frac * 100.0)) if not bandage else ("%d / 3" % floori(frac * 3.0 + 0.001))
		txt(Vector2(r.end.x - 16.0 - txt_w(pct, 15, "bold"), 26), pct, 15, WHITE, "bold")
		var col := GRN if frac > 0.35 or bandage else YEL
		bar(Rect2(x, 36, w - 32.0, 6), frac, col, 3 if bandage else 0)
		# keys
		var y := 52.0
		var busy: bool = info.get("busy", false)
		var keys := [["LMB", ("Ține apăsat: " if not busy else "") + String(info.get("verb", "Folosește"))], ["RMB", "Pune deoparte"]]
		for k in keys:
			var cw := maxf(txt_w(k[0], 12, "bold") + 14.0, 24.0)
			var kr := Rect2(x, y, cw, 22)
			draw_rect(kr, Color(0, 0, 0, 0.55))
			draw_rect(kr, Color(1, 1, 1, 0.75 if not (busy and k[0] == "LMB") else 1.0), false, 1.2)
			if busy and k[0] == "LMB":
				draw_rect(kr, Color(ACC, 0.35))
			txt(Vector2(kr.position.x, kr.end.y - 6), k[0], 12, WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER, cw)
			x += cw + 8.0
			txt(Vector2(x, y + 16), k[1], 14, WHITE if not busy or k[0] == "LMB" else DIM, "bold")
			x += txt_w(k[1], 14, "bold") + 20.0


# ==========================================================================
# Objective tracker (top-right)
# ==========================================================================
class Objective extends Base:
	var text := ""
	var dist := -1.0
	var _flash := 0.0
	var _shown := ""

	func set_text(t: String) -> void:
		if t != _shown:
			_shown = t
			if t != "":
				_flash = 1.0
				Audio.ui("ui_hover")
		text = t

	func tick(delta: float) -> void:
		_flash = maxf(_flash - delta * 0.7, 0.0)
		queue_redraw()

	func _draw() -> void:
		if text == "":
			return
		var w := size.x
		var lines := text.split("\n")
		var hgt := 30.0 + lines.size() * 22.0
		var r := Rect2(w - 420, 0, 420, hgt)
		var a := 1.0
		draw_rect(r, Color(0, 0, 0, 0.32))
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), ACC)
		if _flash > 0.0:
			draw_rect(r, Color(ACC, _flash * 0.25))
		HudIcons.draw(self, "objective", Rect2(r.position.x + 12, r.position.y + 7, 14, 14), ACC, 1.5)
		txt(Vector2(r.position.x + 32, r.position.y + 20), "OBIECTIV" + ("  ·  ACTUALIZAT" if _flash > 0.4 else ""), 12, ACC, "heading")
		if dist >= 0.0:
			txt(Vector2(r.end.x - 90, r.position.y + 20), "%d m" % int(dist), 12, DIM, "mono", HORIZONTAL_ALIGNMENT_RIGHT, 80)
		var y := r.position.y + 42
		for l in lines:
			txt(Vector2(r.position.x + 14, y), l, 17, Color(WHITE, a), "bold")
			y += 22


# ==========================================================================
# Clock / location (top-left)
# ==========================================================================
class Clock extends Base:
	var day := 1
	var time := "08:00"
	var place := ""
	var night := false

	func _draw() -> void:
		txt(Vector2(0, 30), "ZIUA %d" % day, 28, ACC, "heading")
		var dw := txt_w("ZIUA %d" % day, 28, "heading")
		txt(Vector2(dw + 14, 29), time, 22, WHITE, "mono")
		HudIcons.draw(self, "energy" if night else "rad", Rect2(dw + 82, 12, 16, 16), DIM if night else Color(DIM, 0.0))
		txt(Vector2(0, 50), place.to_upper(), 12, DIM, "heading")
