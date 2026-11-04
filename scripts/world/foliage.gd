class_name Foliage
extends RefCounted
## Real grass from scanned/modelled clumps (Sketchfab CC BY): extracts a clump model's
## mesh once, gives it a wind-sway alpha-tested material and scatters it with MultiMesh
## chunks (culled by distance, no shadows).

static var _mesh_cache := {}  # id -> [Mesh, Transform3D (mesh in model space), height, Texture2D]


static func available(id: String) -> bool:
	return Assets.has_model(id) and not _clump(id).is_empty()


static func _clump(id: String) -> Array:
	if _mesh_cache.has(id):
		return _mesh_cache[id]
	var res: Array = []
	if Assets.has_model(id):
		var m := Assets.model(id)
		var mis := m.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var mi := mis[0] as MeshInstance3D
			var xf := Transform3D()
			var n: Node = mi
			while n and n != m:
				if n is Node3D:
					xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var tex: Texture2D = null
			var mat := mi.get_active_material(0) as StandardMaterial3D
			if mat:
				tex = mat.albedo_texture
			var aabb := Assets.model_aabb(m)
			res = [mi.mesh, xf, maxf(aabb.size.y, 0.1), tex]
		m.free()
	_mesh_cache[id] = res
	return res


static func material(id: String, tint := Color.WHITE, wind := 1.0) -> ShaderMaterial:
	var c := _clump(id)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foliage.gdshader")
	if not c.is_empty():
		mat.set_shader_parameter("albedo_tex", c[3])
		# sway uses the clump's own height (mesh space): divide out the model scale
		var sc: float = (c[1] as Transform3D).basis.get_scale().y
		mat.set_shader_parameter("height", float(c[2]) / maxf(sc, 0.0001))
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("wind", wind)
	return mat


## One MultiMeshInstance3D for the given world transforms (each = clump placement).
static func instance(parent: Node, id: String, xfs: Array, mat: Material, range_end := 70.0) -> MultiMeshInstance3D:
	var c := _clump(id)
	if c.is_empty() or xfs.is_empty():
		return null
	var local: Transform3D = c[1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = c[0]
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, (xfs[i] as Transform3D) * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = range_end
	mmi.visibility_range_end_margin = range_end * 0.15
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)
	return mmi


## Fills a flat rectangle (XZ, at height y) with clumps; chunked for culling.
static func lawn(parent: Node, id: String, rect: Rect2, y: float, per_m2: float, rng: RandomNumberGenerator, tint := Color.WHITE, chunk := 12.0) -> void:
	if not available(id):
		return
	var mat := material(id, tint)
	var cx := rect.position.x
	while cx < rect.end.x:
		var cz := rect.position.y
		while cz < rect.end.y:
			var w := minf(chunk, rect.end.x - cx)
			var d := minf(chunk, rect.end.y - cz)
			var xfs: Array = []
			for i in int(w * d * per_m2):
				var p := Vector3(cx + rng.randf() * w, y, cz + rng.randf() * d)
				var s := rng.randf_range(0.7, 1.25)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), p))
			instance(parent, id, xfs, mat)
			cz += chunk
		cx += chunk
