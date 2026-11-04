class_name Terrain
extends Node3D
## Procedural heightfield for surface maps.
##
## Rolling ground + small detail, bomb craters with raised rims, hills rising around the
## playable area (so the edge of the map is a natural bowl), flattened pads under
## buildings, smoothed asphalt roads and earth mounds (the shelter portal). The inner
## square is a 1 m grid with HeightMapShape3D collision; a coarse ring continues the
## hills to the horizon. Splat masks are baked into vertex colours for the shader.

var size := 200.0          # inner square (m), collidable
var far_size := 1400.0     # outer ring extent (m)
var rim_start := 50.0      # where the boundary hills begin (half-extent of the playable area)
var amp := 2.6             # rolling ground amplitude (m)
var seed_value := 1

var pads: Array = []       # [Vector2 c, radius, falloff, height]
var roads: Array = []      # [Vector2 a, Vector2 b, half_width]
var craters: Array = []    # [Vector2 c, radius, depth]
var mounds: Array = []     # [Vector2 c, Vector2 half_extent, height, Vector2 dir, base]  (dir: open side)
var portals: Array = []    # [Vector2 c, Vector2 dir(out), half_w, trench_len, height, base]

var _n := 0
var _step := 1.0
var _h := PackedFloat32Array()
var _lo := FastNoiseLite.new()
var _mid := FastNoiseLite.new()
var _hi := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _built := false


func setup(p_seed: int, p_rim: float) -> void:
	seed_value = p_seed
	rim_start = p_rim
	for pair in [[_lo, 0.011, 3], [_mid, 0.035, 3], [_hi, 0.16, 2], [_hills, 0.004, 4], [_patch, 0.06, 2]]:
		var n: FastNoiseLite = pair[0]
		n.seed = p_seed + int(pair[1] * 1000.0)
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = pair[1]
		n.fractal_octaves = pair[2]


# --------------------------------------------------------------------------
# Features (register before build())
# --------------------------------------------------------------------------

func add_pad(c: Vector3, radius: float, falloff := 6.0) -> float:
	var h := _base(c.x, c.z)
	pads.append([Vector2(c.x, c.z), radius, falloff, h])
	return h


func add_road(a: Vector2, b: Vector2, half_width: float) -> void:
	roads.append([a, b, half_width])


func add_crater(c: Vector2, radius: float, depth: float) -> void:
	craters.append([c, radius, depth])


## Earth mound (e.g. over a shelter portal). half: footprint half-size, dir: the open face.
func add_mound(c: Vector2, half: Vector2, height: float, dir := Vector2(0, -1), base := NAN) -> void:
	mounds.append([c, half, height, dir.normalized(), _base(c.x, c.y) if is_nan(base) else base])


## Shelter portal cut into a hill: earth plateau behind the facade, a trench of
## `trench_len` in front whose sides slope down along the wing walls. Returns the floor height.
func add_portal(c: Vector2, dir: Vector2, half_w: float, trench_len: float, height: float) -> float:
	var base := _base(c.x, c.y)
	portals.append([c, dir.normalized(), half_w, trench_len, height, base])
	# flat apron in front + under the facade
	pads.append([c + dir.normalized() * trench_len * 0.5, half_w + 1.0, 5.0, base])
	return base


func _portal_earth(p: Vector2, pt: Array) -> float:
	var c: Vector2 = pt[0]
	var dir: Vector2 = pt[1]
	var half_w: float = pt[2]
	var tl: float = pt[3]
	var hgt: float = pt[4]
	var local := p - c
	var side := Vector2(-dir.y, dir.x)
	var u := absf(local.dot(side))
	var v := local.dot(-dir)   # > 0 behind the facade
	if v >= 0.0:
		var lat := 1.0 - smoothstep(half_w + 1.5, half_w + 11.0, u)
		var back := 1.0 - smoothstep(5.0, 16.0, v)
		return hgt * lat * back
	# earth starts behind the (1.2 m thick) wing walls so it never covers their faces
	if v < -tl - 0.5 or u < half_w + 1.0:
		return 0.0
	var along := clampf(1.0 + v / tl, 0.0, 1.0)          # 1 at the facade, 0 at the trench mouth
	var wall_h := lerpf(0.9, hgt - 0.6, along)
	return wall_h * (1.0 - smoothstep(half_w + 1.2, half_w + 9.0, u))


# --------------------------------------------------------------------------
# Height function
# --------------------------------------------------------------------------

func _base(x: float, z: float) -> float:
	var h := _lo.get_noise_2d(x, z) * amp + _mid.get_noise_2d(x, z) * amp * 0.28
	# boundary bowl: hills rise past the playable area, bigger hills further out
	var e := maxf(absf(x), absf(z))
	var r := Vector2(x, z).length()
	var t := clampf((e - rim_start) / 38.0, 0.0, 1.0)
	h += t * t * (3.0 - 2.0 * t) * (7.0 + 6.0 * _mid.get_noise_2d(x * 0.5, z * 0.5))
	var far := clampf((r - rim_start - 60.0) / 300.0, 0.0, 1.0)
	h += far * (18.0 + 22.0 * _hills.get_noise_2d(x, z))
	return h


func _road_mask(x: float, z: float) -> float:
	var m := 0.0
	var p := Vector2(x, z)
	for rd in roads:
		var a: Vector2 = rd[0]
		var b: Vector2 = rd[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		var hw: float = rd[2]
		m = maxf(m, 1.0 - smoothstep(hw - 0.6, hw + 1.6, d))
	return m


func height_raw(x: float, z: float) -> float:
	var h := _base(x, z) + _hi.get_noise_2d(x, z) * 0.12
	var p := Vector2(x, z)
	# craters: bowl + raised rim
	for c in craters:
		var d := p.distance_to(c[0]) / float(c[1])
		if d < 1.8:
			var depth: float = c[2]
			if d < 1.0:
				h -= depth * (1.0 - d * d)
			h += depth * 0.4 * exp(-pow((d - 1.0) / 0.28, 2.0))
	# roads follow the low-frequency shape only
	var rm := _road_mask(x, z)
	if rm > 0.0:
		h = lerpf(h, _lo.get_noise_2d(x, z) * amp + _mid.get_noise_2d(x, z) * amp * 0.28, rm)
	# pads (building floors / aprons)
	for pd in pads:
		var d := p.distance_to(pd[0])
		var rad: float = pd[1]
		var fo: float = pd[2]
		if d < rad + fo:
			var m := 1.0 - smoothstep(rad, rad + fo, d)
			h = lerpf(h, float(pd[3]), m)
	# mounds (rounded earth bunker covers), closed on all sides but `dir`
	for md in mounds:
		var c: Vector2 = md[0]
		var half: Vector2 = md[1]
		var dir: Vector2 = md[3]
		var local := p - c
		var side := Vector2(-dir.y, dir.x)
		var u := local.dot(side) / half.x
		var v := local.dot(-dir) / half.y   # 0 at the facade, +1 at the back
		if v > -0.15:
			var q := Vector2(u, maxf(v, 0.0) * 0.8).length()
			var mh := float(md[2]) * clampf(1.0 - q * q, 0.0, 1.0)
			mh *= smoothstep(-0.15, 0.08, v)
			if mh > 0.0:
				h = maxf(h, float(md[4]) + mh)
	for pt in portals:
		var eh := _portal_earth(p, pt)
		if eh > 0.0:
			h = maxf(h, float(pt[5]) + eh)
	return h


# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------

func build(quality := 1.0) -> void:
	_step = 1.0
	_n = int(size / _step) + 1
	var half := size * 0.5
	_h.resize(_n * _n)
	for iz in _n:
		for ix in _n:
			_h[iz * _n + ix] = height_raw(-half + ix * _step, -half + iz * _step)
	_built = true
	_build_inner()
	_build_far()
	_build_collision()


func height_at(x: float, z: float) -> float:
	if not _built:
		return height_raw(x, z)
	var half := size * 0.5
	var fx := (x + half) / _step
	var fz := (z + half) / _step
	if fx < 0.0 or fz < 0.0 or fx >= _n - 1 or fz >= _n - 1:
		return height_raw(x, z)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _h[iz * _n + ix]
	var h10 := _h[iz * _n + ix + 1]
	var h01 := _h[(iz + 1) * _n + ix]
	var h11 := _h[(iz + 1) * _n + ix + 1]
	# same diagonal split as the mesh triangles
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := 0.6
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func slope_at(x: float, z: float) -> float:
	return 1.0 - normal_at(x, z).y


func _mask(x: float, z: float, _h_unused: float, _n_unused: Vector3) -> Color:
	var road := _road_mask(x, z)
	var dirt := 0.0
	var p := Vector2(x, z)
	for c in craters:
		var d := p.distance_to(c[0]) / float(c[1])
		dirt = maxf(dirt, 1.0 - smoothstep(0.9, 1.5, d))
	dirt = maxf(dirt, smoothstep(0.25, 0.65, _patch.get_noise_2d(x * 0.6, z * 0.6)))
	var gravel := smoothstep(0.35, 0.75, _patch.get_noise_2d(x + 300.0, z - 120.0))
	for pd in pads:
		var d := p.distance_to(pd[0])
		var rad: float = pd[1]
		gravel = maxf(gravel, (1.0 - smoothstep(rad - 1.0, rad + 4.0, d)) * 0.5)
	var grass := smoothstep(-0.1, 0.4, _patch.get_noise_2d(x * 0.35 - 77.0, z * 0.35 + 41.0)) * (1.0 - road) * (1.0 - dirt * 0.7)
	return Color(road, dirt, gravel * (1.0 - road), grass)


func grass_mask(x: float, z: float) -> float:
	var c := _mask(x, z, 0.0, Vector3.UP)
	return c.a * (1.0 - c.r) * (1.0 - c.b * 0.8) * (1.0 - slope_at(x, z) * 2.0)


func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	var tex := func(id: String, kind: String) -> Texture2D:
		return Assets._tex_any(Assets.TEX_DIR + id + "/", kind)
	m.set_shader_parameter("ash_albedo", tex.call("ground_ash", "albedo"))
	m.set_shader_parameter("ash_normal", tex.call("ground_ash", "normal"))
	m.set_shader_parameter("dirt_albedo", tex.call("ground_dirt", "albedo"))
	m.set_shader_parameter("dirt_normal", tex.call("ground_dirt", "normal"))
	m.set_shader_parameter("gravel_albedo", tex.call("gravel", "albedo"))
	m.set_shader_parameter("gravel_normal", tex.call("gravel", "normal"))
	m.set_shader_parameter("road_albedo", tex.call("asphalt", "albedo"))
	m.set_shader_parameter("road_normal", tex.call("asphalt", "normal"))
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	nt.noise = fn
	nt.generate_mipmaps = true
	m.set_shader_parameter("macro_noise", nt)
	# "Scăzut" geometry detail: single-scale ground sampling (10 fetches instead of 17)
	m.set_shader_parameter("detail", 0 if int(Settings.opt("lod")) == 0 else 1)
	return m


func _build_inner() -> void:
	var half := size * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(_n * _n)
	norms.resize(_n * _n)
	cols.resize(_n * _n)
	uvs.resize(_n * _n)
	for iz in _n:
		for ix in _n:
			var i := iz * _n + ix
			var x := -half + ix * _step
			var z := -half + iz * _step
			var h := _h[i]
			verts[i] = Vector3(x, h, z)
			var hl := _h[iz * _n + maxi(ix - 1, 0)]
			var hr := _h[iz * _n + mini(ix + 1, _n - 1)]
			var hd := _h[maxi(iz - 1, 0) * _n + ix]
			var hu := _h[mini(iz + 1, _n - 1) * _n + ix]
			var nrm := Vector3(hl - hr, 2.0 * _step, hd - hu).normalized()
			norms[i] = nrm
			cols[i] = _mask(x, z, h, nrm)
			uvs[i] = Vector2(x, z)
	var idx := PackedInt32Array()
	idx.resize((_n - 1) * (_n - 1) * 6)
	var k := 0
	for iz in _n - 1:
		for ix in _n - 1:
			var a := iz * _n + ix
			var b := a + 1
			var c := a + _n
			var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.regen_normal_maps()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainInner"
	mi.mesh = am
	mi.material_override = _material()
	add_child(mi)


func _far_h(x: float, z: float) -> float:
	return _base(x, z)


func _build_far() -> void:
	var step := 10.0
	var half := far_size * 0.5
	var inner := size * 0.5
	var n := int(far_size / step) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	uvs.resize(n * n)
	for iz in n:
		for ix in n:
			var x := -half + ix * step
			var z := -half + iz * step
			var h := _far_h(x, z)
			if absf(x) <= inner + 0.01 and absf(z) <= inner + 0.01:
				h -= 0.6  # skirt under the detailed mesh: no cracks at the seam
			var e := 4.0
			var nrm := Vector3(_far_h(x - e, z) - _far_h(x + e, z), 2.0 * e, _far_h(x, z - e) - _far_h(x, z + e)).normalized()
			var i := iz * n + ix
			verts[i] = Vector3(x, h, z)
			norms[i] = nrm
			cols[i] = Color(0.0, smoothstep(0.25, 0.65, _patch.get_noise_2d(x * 0.6, z * 0.6)), 0.0, 0.5)
			uvs[i] = Vector2(x, z)
	var idx := PackedInt32Array()
	for iz in n - 1:
		for ix in n - 1:
			var x0 := -half + ix * step
			var z0 := -half + iz * step
			if x0 >= -inner and x0 + step <= inner and z0 >= -inner and z0 + step <= inner:
				continue
			var a := iz * n + ix
			idx.append_array(PackedInt32Array([a, a + 1, a + n, a + 1, a + n + 1, a + n]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.regen_normal_maps()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainFar"
	mi.mesh = am
	mi.material_override = _material()
	add_child(mi)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.set_meta("surface", "grass")
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = _n
	hm.map_depth = _n
	hm.map_data = _h
	cs.shape = hm
	body.add_child(cs)
	add_child(body)


# --------------------------------------------------------------------------
# Dry grass
# --------------------------------------------------------------------------

func scatter_grass(rng: RandomNumberGenerator, extent: float, density: float, keep_out: Callable) -> void:
	if density <= 0.0:
		return
	var mesh := _grass_card()
	var chunk := 16.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	# real dry-grass clumps when the model is there (procedural cards otherwise)
	var real := Foliage.available("grass_dry")
	var fmat: Material = Foliage.material("grass_dry", Color(0.92, 0.88, 0.8)) if real else null
	var cz := -extent
	while cz < extent:
		var cx := -extent
		while cx < extent:
			var xfs: Array[Transform3D] = []
			var tries := int(chunk * chunk * 0.9 * density)
			for i in tries:
				var x := cx + rng.randf() * chunk
				var z := cz + rng.randf() * chunk
				var g := grass_mask(x, z)
				if g < 0.25 or rng.randf() > g:
					continue
				if keep_out.call(Vector2(x, z)):
					continue
				var h := height_at(x, z)
				var s := rng.randf_range(0.6, 1.25) * lerpf(0.75, 1.1, g)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
				xfs.append(Transform3D(b, Vector3(x, h - 0.03, z)))
			if real and not xfs.is_empty():
				Foliage.instance(self, "grass_dry", xfs, fmat, 75.0)
			elif not xfs.is_empty():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = xfs.size()
				for i in xfs.size():
					mm.set_instance_transform(i, xfs[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = mat
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 75.0
				mmi.visibility_range_end_margin = 12.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				add_child(mmi)
			cx += chunk
		cz += chunk


func _grass_card() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.45
	var h := 0.55
	for i in 3:
		var a := float(i) / 3.0 * PI
		var d := Vector3(cos(a), 0, sin(a)) * w
		var nrm := Vector3(-sin(a), 0, cos(a))
		var p := [-d, d, d + Vector3(0, h, 0), -d + Vector3(0, h, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	return st.commit()
