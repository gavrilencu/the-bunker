class_name BoxBatch
extends RefCounted
## Merges many boxes / triangles into one mesh per material (a whole building is a
## handful of draw calls) and their colliders into one StaticBody3D.
## No UVs are generated: use world-triplanar materials (Assets.pbr) or flat colours.

## [normal, u, v] per face with u × v = normal (corners wound clockwise from outside).
const FACES := [
	[Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP], [Vector3.LEFT, Vector3(0, 0, 1), Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3(0, 0, -1)], [Vector3.DOWN, Vector3.RIGHT, Vector3(0, 0, 1)],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
]

## Cell size (m) for splitting the merged meshes, so the parts behind the camera get
## frustum-culled; 0 = one mesh per material (fine for a single building).
var cell := 0.0

var _tools := {}  # Material, or [Material, cell] -> SurfaceTool
var _shapes: Array = []  # [Transform3D, size]
var _count := 0


func _st(mat: Material, at: Vector3) -> SurfaceTool:
	var key = mat if cell <= 0.0 else [mat, Vector3i((at / cell).floor())]
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


## Box centred at `c`, turned by `yaw` around Y.
func box(mat: Material, c: Vector3, size: Vector3, yaw := 0.0, collide := false) -> void:
	box_xf(mat, Transform3D(Basis(Vector3.UP, yaw), c), size, collide)


## Box with an arbitrary transform (roof slabs, boards nailed across windows...).
func box_xf(mat: Material, xf: Transform3D, size: Vector3, collide := false) -> void:
	if size.x < 0.002 or size.y < 0.002 or size.z < 0.002:
		return
	var st := _st(mat, xf.origin)
	var h := size * 0.5
	for f in FACES:
		var n: Vector3 = f[0]
		var c: Vector3 = n * h
		var du: Vector3 = f[1] * h
		var dv: Vector3 = f[2] * h
		var wn := (xf.basis * n).normalized()
		var p0 := xf * (c - du - dv)
		var p1 := xf * (c + du - dv)
		var p2 := xf * (c + du + dv)
		var p3 := xf * (c - du + dv)
		for p in [p0, p2, p1, p0, p3, p2]:
			st.set_normal(wn)
			st.add_vertex(p)
	_count += 1
	if collide:
		_shapes.append([xf, size])


## Cylinder from `a` to `b` (pipes, posts, wheels), capped at both ends.
func cylinder(mat: Material, a: Vector3, b: Vector3, r: float, sides := 10, collide := false) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.002 or r < 0.001:
		return
	var w := axis / length
	var u := (Vector3.UP if absf(w.y) < 0.95 else Vector3.RIGHT).cross(w).normalized()
	var v := w.cross(u)
	var st := _st(mat, (a + b) * 0.5)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		var p0 := a + n0 * r
		var p1 := a + n1 * r
		var q0 := b + n0 * r
		var q1 := b + n1 * r
		for p in [[p0, n0], [q1, n1], [p1, n1], [p0, n0], [q0, n0], [q1, n1]]:
			st.set_normal(p[1])
			st.add_vertex(p[0])
		for cap in [[a, -w, p0, p1], [b, w, q1, q0]]:
			for p in [cap[0], cap[2], cap[3]]:
				st.set_normal(cap[1])
				st.add_vertex(p)
	if collide:
		var basis := Basis(u, w, v)
		_shapes.append([Transform3D(basis, (a + b) * 0.5), Vector3(r * 1.8, length, r * 1.8)])


## Flat triangle (gable ends); `double` adds the back face too.
func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, double := true) -> void:
	var st := _st(mat, a)
	var n := (c - a).cross(b - a).normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)
	if double:
		for p in [a, c, b]:
			st.set_normal(-n)
			st.add_vertex(p)


## Invisible collider only.
func collider(xf: Transform3D, size: Vector3) -> void:
	_shapes.append([xf, size])


func is_empty() -> bool:
	return _tools.is_empty() and _shapes.is_empty()


## Builds the meshes (one per material) and the static body under `parent`.
func commit(parent: Node3D, shadows := true, fade_at := 0.0) -> StaticBody3D:
	for key in _tools:
		var mi := MeshInstance3D.new()
		mi.mesh = (_tools[key] as SurfaceTool).commit()
		mi.material_override = key if key is Material else key[0]
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if fade_at > 0.0:
			mi.visibility_range_end = fade_at
			mi.visibility_range_end_margin = fade_at * 0.1
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mi)
	var body: StaticBody3D = null
	if not _shapes.is_empty():
		body = StaticBody3D.new()
		parent.add_child(body)
		for s in _shapes:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = s[1]
			cs.shape = bs
			cs.transform = s[0]
			body.add_child(cs)
	_tools.clear()
	_shapes.clear()
	return body
