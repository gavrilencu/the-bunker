class_name Placement
extends Node
## Interactive positioning of one object in the bunker: build holograms and moving
## existing furniture / lights share it.
##
## The object follows the crosshair and snaps by its mount:
##   floor   — the floor, or furniture tops for small objects (lanterns, radios, cans);
##             wall furniture (beds, shelves, lockers...) backs onto the nearest wall
##   wall    — a rock wall, facing into the room
##   ceiling — the ceiling above the aimed point
## Valid spots are inside one open room, clear of doorways, with no overlap with other
## solids or the player. Objects resting on a moved piece (riders) travel with it.
## LMB / G confirms, RMB / Esc cancels (moved objects return), wheel / R rotate,
## T toggles grid + wall alignment.

signal done(ok: bool)

const REACH := 6.0
const WALL_SNAP := 1.2
const OK_COLOR := Color(0.3, 1.0, 0.45)
const BAD_COLOR := Color(1.0, 0.28, 0.22)

## Grid + wall alignment, kept for the whole session.
static var snap := true

var level: Node3D
var target: Node3D
var riders: Array[Node3D] = []
var title := ""
var cost_line := ""
var mount := "floor"
var wall_furniture := false
## true when `target` is a preview made for this placement (the caller frees it)
var preview := false
## Optional () -> String: why the spot is not allowed ("" = fine).
var extra_check: Callable

var yaw := 0.0
var flip := false
var valid := false
var reason := ""
var wall_snapped := false
var stackable := false
## Shift was held when confirming (build mode places another one).
var repeat := false

var _aabb: AABB
var _front := Vector3.BACK
var _scale := Vector3.ONE
var _orig: Transform3D
var _rider_rel: Array[Transform3D] = []
var _rider_orig: Array[Transform3D] = []
var _layers := {}
var _overlays := {}
var _tint: StandardMaterial3D
var _foot: MeshInstance3D
var _foot_mat: StandardMaterial3D
var _t := 0.0
var _finished := false


func _ready() -> void:
	_aabb = Assets.model_aabb(target)
	_scale = target.scale
	_orig = target.global_transform
	yaw = target.rotation.y
	stackable = mount == "floor" and maxf(_aabb.size.x, _aabb.size.z) * _scale.x <= 0.75 and _aabb.size.y * _scale.y <= 0.8
	for r in riders:
		_rider_rel.append(_orig.affine_inverse() * r.global_transform)
		_rider_orig.append(r.global_transform)
	_tint = StandardMaterial3D.new()
	_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint.albedo_color = Color(OK_COLOR, 0.3)
	_prepare(target)
	for r in riders:
		_prepare(r)
	if wall_furniture:
		_front = _front_axis()
	if mount == "floor":
		_make_footprint()
	Game.build_mode_active = true
	_update()


func _exit_tree() -> void:
	if not _finished:
		_restore()
		Game.build_mode_active = false
		HUD.set_placement({})


## Collisions off (the object must not block its own rays / the player) + tint overlay.
func _prepare(n: Node) -> void:
	if n is CollisionObject3D:
		var co := n as CollisionObject3D
		_layers[co] = [co.collision_layer, co.collision_mask]
		co.collision_layer = 0
		co.collision_mask = 0
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		_overlays[gi] = gi.material_overlay
		gi.material_overlay = _tint
	for c in n.get_children():
		_prepare(c)


func _restore() -> void:
	for gi in _overlays:
		if is_instance_valid(gi):
			gi.material_overlay = _overlays[gi]
	for co in _layers:
		if is_instance_valid(co):
			co.collision_layer = _layers[co][0]
			co.collision_mask = _layers[co][1]
	_overlays.clear()
	_layers.clear()
	if _foot:
		_foot.queue_free()
		_foot = null


func finish(ok: bool) -> void:
	if _finished:
		return
	_finished = true
	_restore()
	if not ok and not preview:
		target.global_transform = _orig
		for i in riders.size():
			riders[i].global_transform = _rider_orig[i]
	Game.build_mode_active = false
	HUD.set_placement({})
	done.emit(ok)
	queue_free()


func cancel() -> void:
	finish(false)


## Programmatic move (tests, tools): the target and everything riding on it.
func move_to(xf: Transform3D) -> void:
	target.global_transform = xf
	for i in riders.size():
		riders[i].global_transform = xf * _rider_rel[i]


# --------------------------------------------------------------------------
# Per frame
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_update()
	var c := OK_COLOR if valid else BAD_COLOR
	_tint.albedo_color = Color(c, 0.2 + 0.08 * sin(_t * 5.0))
	if _foot_mat:
		_foot_mat.albedo_color = Color(c, 0.85)


func _update() -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var cam: Camera3D = p.cam
	var from := cam.global_position
	var far := from - cam.global_basis.z * REACH
	var hit := _ray(from, far)
	reason = ""
	var ok := false
	match mount:
		"wall":
			ok = _on_wall(hit)
		"ceiling":
			ok = _on_ceiling(hit, far)
		_:
			ok = _on_floor(hit, far)
	if ok:
		reason = _check()
	valid = ok and reason == ""
	var xf := target.global_transform
	for i in riders.size():
		riders[i].global_transform = xf * _rider_rel[i]
	if _foot:
		_foot.global_transform = Transform3D(Basis(Vector3.UP, target.rotation.y), xf.origin + Vector3.UP * 0.012)
	HUD.set_placement(_hud_info())


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	if Game.player and is_instance_valid(Game.player):
		q.exclude = [Game.player.get_rid()]
	return level.get_world_3d().direct_space_state.intersect_ray(q)


func _set_pose(p: Vector3, y: float) -> void:
	target.global_transform = Transform3D(Basis(Vector3.UP, y).scaled(_scale), p)


func _on_floor(hit: Dictionary, far: Vector3) -> bool:
	wall_snapped = false
	if hit.is_empty():
		hit = _ray(far, far + Vector3.DOWN * 6.0)
	elif (hit.normal as Vector3).y < 0.7:
		# aimed at a wall or the side of something: drop to the floor in front of it
		var start: Vector3 = (hit.position as Vector3) + (hit.normal as Vector3) * 0.08
		hit = _ray(start, start + Vector3.DOWN * 6.0)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
		reason = "Țintește podeaua"
		return false
	var p: Vector3 = hit.position
	var on_top := p.y > 0.2
	if on_top:
		if not stackable:
			reason = "Prea mare ca să stea pe mobilier"
			_set_pose(p, yaw)
			return false
		p.y = _surface_top(hit.collider, p.y)
	else:
		p.y = 0.0
	if snap:
		var g := 0.05 if on_top or maxf(_aabb.size.x, _aabb.size.z) * _scale.x < 0.7 else 0.25
		p.x = snappedf(p.x, g)
		p.z = snappedf(p.z, g)
	var y := yaw
	if wall_furniture and snap and not on_top:
		var w := _nearest_wall(p + Vector3.UP * 0.5)
		if not w.is_empty():
			var n: Vector3 = w.normal
			n = Vector3(n.x, 0.0, n.z).normalized()
			y = atan2(n.x, n.z) - atan2(_front.x, _front.z) + (PI if flip else 0.0)
			var depth := _support(Basis(Vector3.UP, y), -n)
			p += n * (n.dot((w.position as Vector3) - p) + depth + 0.015)
			p.y = 0.0
			wall_snapped = true
			yaw = y
	_set_pose(p, y)
	return true


func _on_wall(hit: Dictionary) -> bool:
	if hit.is_empty() or hit.collider != level.csg or absf((hit.normal as Vector3).y) > 0.3:
		reason = "Țintește un perete"
		return false
	var n: Vector3 = hit.normal
	n = Vector3(n.x, 0.0, n.z).normalized()
	var p: Vector3 = hit.position
	if snap:
		var s := p.snapped(Vector3.ONE * 0.1)
		p = s - n * n.dot(s - (hit.position as Vector3))
	var ceil_y: float = level.ceiling_at(p)
	p.y = clampf(p.y, 0.25 - _aabb.position.y * _scale.y, ceil_y - 0.05 - _aabb.end.y * _scale.y)
	wall_snapped = true
	_set_pose(p + n * 0.004, atan2(n.x, n.z))
	return true


func _on_ceiling(hit: Dictionary, far: Vector3) -> bool:
	var found := false
	var p := Vector3.ZERO
	if not hit.is_empty() and hit.collider == level.csg and (hit.normal as Vector3).y < -0.7:
		p = hit.position
		found = true
	else:
		# aimed at the floor or a wall: use the ceiling straight above that point
		var base: Vector3 = far if hit.is_empty() else (hit.position as Vector3) + (hit.normal as Vector3) * 0.05
		var up := _ray(base, base + Vector3.UP * 6.0)
		if not up.is_empty() and up.collider == level.csg and (up.normal as Vector3).y < -0.7:
			p = up.position
			found = true
	if not found:
		reason = "Țintește tavanul"
		return false
	if snap:
		var g := 0.1 if maxf(_aabb.size.x, _aabb.size.z) * _scale.x < 0.7 else 0.25
		p.x = snappedf(p.x, g)
		p.z = snappedf(p.z, g)
	p.y = level.ceiling_at(p)
	wall_snapped = false
	_set_pose(p, yaw)
	return true


## Closest rock wall around `c` (walls are axis aligned).
func _nearest_wall(c: Vector3) -> Dictionary:
	var best := WALL_SNAP
	var res := {}
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var h := _ray(c, c + d * WALL_SNAP)
		if not h.is_empty() and h.collider == level.csg and absf((h.normal as Vector3).y) < 0.3:
			var dist := c.distance_to(h.position)
			if dist < best:
				best = dist
				res = h
	return res


## Extent of the rotated bounds from the origin along `dir`.
func _support(b: Basis, dir: Vector3) -> float:
	var m := -INF
	for i in 8:
		m = maxf(m, (b * (_aabb.get_endpoint(i) * _scale)).dot(dir))
	return m


## Which local axis of a wall piece faces the room: the thin horizontal axis, signed by
## the wall it stands against now (previews: +axis; R flips).
func _front_axis() -> Vector3:
	var axis := Vector3.RIGHT if _aabb.size.x < _aabb.size.z else Vector3.BACK
	if preview:
		return axis
	var c := _orig * _aabb.get_center()
	c.y = _orig.origin.y + minf(_aabb.size.y * 0.5, 0.6)
	var best := INF
	var n := Vector3.ZERO
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var h := _ray(c, c + d * 2.5)
		if not h.is_empty() and h.collider == level.csg:
			var dist := c.distance_to(h.position)
			if dist < best:
				best = dist
				n = h.normal
	if n == Vector3.ZERO:
		return axis
	var local := _orig.basis.inverse() * n
	return axis if local.dot(axis) >= 0.0 else -axis


## Snaps to the visual top of the furniture under the cursor (collision boxes are shrunk).
func _surface_top(collider: Object, y: float) -> float:
	var n: Node = collider as Node
	while n and n != level and not n.has_meta("mv_key"):
		n = n.get_parent()
	if n == null or n == level or not (n is Node3D):
		return y
	var body := n as Node3D
	var top := (body.global_transform * Assets.model_aabb(body)).end.y
	return top if absf(top - y) < 0.06 else y


# --------------------------------------------------------------------------
# Validity
# --------------------------------------------------------------------------

func _check() -> String:
	var xf := target.global_transform
	var corners := _corners(xf)
	if level.room_at(corners) == "":
		return "În afara camerei"
	if mount == "floor" and xf.origin.y < 0.2 and level.blocks_passage(corners):
		return "Blochează o trecere"
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = (_aabb.size * _scale - Vector3.ONE * 0.06).max(Vector3.ONE * 0.02)
	q.shape = sh
	q.transform = Transform3D(xf.basis.orthonormalized(), xf * _aabb.get_center())
	q.collision_mask = 1 | 2
	for h in level.get_world_3d().direct_space_state.intersect_shape(q, 12):
		var c: Object = h.collider
		if c == level.csg:
			continue
		if c is Player:
			return "Stai chiar pe locul acela"
		return "Locul e ocupat"
	if extra_check.is_valid():
		return extra_check.call()
	return ""


## XZ corners of the footprint in world space.
func _corners(xf: Transform3D) -> PackedVector2Array:
	var a := _aabb
	var res := PackedVector2Array()
	for c in [Vector3(a.position.x, 0, a.position.z), Vector3(a.end.x, 0, a.position.z), Vector3(a.end.x, 0, a.end.z), Vector3(a.position.x, 0, a.end.z)]:
		var w: Vector3 = xf * c
		res.append(Vector2(w.x, w.z))
	return res


# --------------------------------------------------------------------------
# Feedback
# --------------------------------------------------------------------------

## Outline of the footprint on the floor with a chevron on the front side.
func _make_footprint() -> void:
	var x0 := _aabb.position.x * _scale.x
	var x1 := _aabb.end.x * _scale.x
	var z0 := _aabb.position.z * _scale.z
	var z1 := _aabb.end.z * _scale.z
	var w := 0.025
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector2, b: Vector2, alpha: float) -> void:
		st.set_color(Color(1, 1, 1, alpha))
		for v in [Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(a.x, b.y)]:
			st.add_vertex(Vector3(v.x, 0.0, v.y))
	quad.call(Vector2(x0, z0), Vector2(x1, z1), 0.16)
	quad.call(Vector2(x0, z0), Vector2(x1, z0 + w), 1.0)
	quad.call(Vector2(x0, z1 - w), Vector2(x1, z1), 1.0)
	quad.call(Vector2(x0, z0 + w), Vector2(x0 + w, z1 - w), 1.0)
	quad.call(Vector2(x1 - w, z0 + w), Vector2(x1, z1 - w), 1.0)
	# chevron pointing along the front axis, just outside the footprint
	var f := _front if wall_furniture else Vector3.BACK
	var side := Vector3(f.z, 0.0, -f.x)
	var edge := absf(z1 if f.z > 0.0 else z0) if f.x == 0.0 else absf(x1 if f.x > 0.0 else x0)
	var tip := f * (edge + 0.22)
	var base := f * (edge + 0.06)
	st.set_color(Color(1, 1, 1, 0.9))
	for v in [base + side * 0.12, tip, base - side * 0.12]:
		st.add_vertex(v)
	_foot_mat = StandardMaterial3D.new()
	_foot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foot_mat.vertex_color_use_as_albedo = true
	_foot_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_foot = MeshInstance3D.new()
	_foot.mesh = st.commit()
	_foot.material_override = _foot_mat
	_foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(_foot)


func _hud_info() -> Dictionary:
	var keys: Array = [["CLICK", "Plasează"]]
	if mount != "wall":
		keys.append(["ROTIȚĂ", "Rotește %d°" % (15 if snap else 5)])
		keys.append(["R", "Întoarce" if wall_snapped else "90°"])
	keys.append(["T", "Aliniere: %s" % ("DA" if snap else "NU")])
	if preview:
		keys.append(["SHIFT+CLICK", "Încă unul"])
	keys.append(["CLICK DR.", "Anulează"])
	return {"title": title, "sub": cost_line, "ok": valid, "status": "Poziție bună" if valid else reason, "keys": keys}


func _unhandled_input(e: InputEvent) -> void:
	if _finished:
		return
	if e.is_action_pressed("attack") or e.is_action_pressed("move_object"):
		get_viewport().set_input_as_handled()
		if valid:
			repeat = Input.is_key_pressed(KEY_SHIFT)
			finish(true)
		else:
			Audio.sfx("ui_click", -2.0, 0.0)
			HUD.toast(reason if reason != "" else "Nu se poate plasa aici.", "warn")
	elif e.is_action_pressed("aim") or e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		finish(false)
	elif e.is_action_pressed("wheel_up") or e.is_action_pressed("wheel_down"):
		get_viewport().set_input_as_handled()
		if mount != "wall" and not wall_snapped:
			var step := deg_to_rad(15.0 if snap else 5.0)
			yaw += step if e.is_action_pressed("wheel_up") else -step
	elif e.is_action_pressed("rotate"):
		get_viewport().set_input_as_handled()
		if wall_snapped and mount == "floor":
			flip = not flip
		elif mount != "wall":
			yaw = snappedf(yaw + PI * 0.5, PI * 0.5) if snap else yaw + PI * 0.5
	elif e.is_action_pressed("snap_toggle"):
		get_viewport().set_input_as_handled()
		snap = not snap
		Audio.ui("ui_click")
