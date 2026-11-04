extends Node
## Central asset access: models (glb), PBR texture sets, HDRIs, audio, fonts.
## Everything degrades gracefully: a missing model becomes a neutral placeholder,
## a missing texture becomes a flat color, a missing sound falls back to Synth.

const MODEL_DIR := "res://assets/models/"
const TEX_DIR := "res://assets/textures/"
const HDRI_DIR := "res://assets/hdri/"
const AUDIO_DIR := "res://assets/audio/"
const FONT_DIR := "res://assets/fonts/"

## Approximate real-world sizes used for placeholders when a model is missing.
const FALLBACK_SIZE := {
	"vault_door": Vector3(2.8, 2.6, 0.6), "bunker_entrance": Vector3(4, 3.2, 5),
	"metal_door": Vector3(1.0, 2.1, 0.1), "bunk_bed": Vector3(0.95, 1.8, 2.0),
	"metal_shelf": Vector3(1.2, 2.0, 0.5), "wooden_crate": Vector3(0.6, 0.6, 0.6),
	"military_crate": Vector3(1.0, 0.45, 0.5), "oil_barrel": Vector3(0.6, 0.9, 0.6),
	"canned_food": Vector3(0.08, 0.12, 0.08), "water_jug": Vector3(0.22, 0.4, 0.22),
	"jerrycan": Vector3(0.17, 0.45, 0.35), "diesel_generator": Vector3(1.6, 1.0, 0.8),
	"electrical_panel": Vector3(0.6, 0.9, 0.25), "water_tank": Vector3(1.2, 2.0, 1.2),
	"water_purifier": Vector3(0.9, 1.4, 0.6), "air_filter_unit": Vector3(1.0, 1.2, 0.8),
	"workbench": Vector3(2.0, 1.0, 0.8), "toolbox": Vector3(0.5, 0.25, 0.22),
	"radio_station": Vector3(0.6, 0.35, 0.35), "table_metal": Vector3(1.6, 0.78, 0.8),
	"chair": Vector3(0.45, 0.9, 0.45), "locker": Vector3(0.5, 1.9, 0.5),
	"first_aid_kit": Vector3(0.35, 0.12, 0.25), "gas_mask": Vector3(0.2, 0.3, 0.2),
	"lamp_cage": Vector3(0.2, 0.35, 0.2), "fluorescent_lamp": Vector3(1.2, 0.08, 0.15),
	"planter_box": Vector3(1.2, 0.45, 0.6), "plant_tomato": Vector3(0.5, 0.9, 0.5),
	"plant_lettuce": Vector3(0.3, 0.3, 0.3), "plant_potato": Vector3(0.45, 0.5, 0.45),
	"mushrooms": Vector3(0.2, 0.15, 0.2), "crt_computer": Vector3(0.45, 0.45, 0.45),
	"geiger_counter": Vector3(0.2, 0.1, 0.1), "flashlight": Vector3(0.05, 0.05, 0.25),
	"camping_stove": Vector3(0.3, 0.3, 0.3), "fridge_old": Vector3(0.6, 1.7, 0.6),
	"fire_extinguisher": Vector3(0.18, 0.6, 0.18), "sandbags": Vector3(1.2, 0.5, 0.5),
	"sofa_old": Vector3(2.0, 0.9, 0.9), "car_battery": Vector3(0.3, 0.2, 0.18),
	"shovel": Vector3(0.25, 1.1, 0.05), "bucket": Vector3(0.3, 0.35, 0.3),
	"apartment_block": Vector3(60, 15, 12), "house_small": Vector3(9, 7, 8),
	"car_sedan": Vector3(1.7, 1.4, 4.2), "car_wreck": Vector3(1.7, 1.3, 4.2),
	"bus_wreck": Vector3(2.5, 3.0, 11), "tree_leafy": Vector3(5, 9, 5),
	"tree_dead": Vector3(4, 7, 4), "street_lamp": Vector3(0.4, 7, 1.5),
	"bench": Vector3(1.8, 0.8, 0.6), "trash_bin": Vector3(1.8, 1.2, 1.0),
	"concrete_barrier": Vector3(3, 0.8, 0.6), "utility_pole": Vector3(0.4, 9, 1.8),
	"bus_stop": Vector3(4, 2.6, 1.6), "ruined_building": Vector3(16, 14, 12),
	"rubble_pile": Vector3(3, 1.2, 3), "supermarket_shelf": Vector3(2.0, 1.8, 0.6),
	"tank_wreck": Vector3(3.5, 2.4, 7), "enemy_mutant": Vector3(0.6, 1.9, 0.4),
	"enemy_raider": Vector3(0.6, 1.8, 0.4), "survivor_npc": Vector3(0.6, 1.75, 0.4),
	"weapon_pistol": Vector3(0.04, 0.13, 0.2), "weapon_rifle": Vector3(0.06, 0.25, 0.9),
	"weapon_axe": Vector3(0.05, 0.2, 0.7),
}

var _scene_cache := {}
var _mat_cache := {}
var _tex_cache := {}
var _sound_cache := {}
var _font_cache := {}


# --------------------------------------------------------------------------
# Threaded preloading (used by the loading screen)
# --------------------------------------------------------------------------

## Starts background loads for models (+ optional texture/HDRI paths). Returns jobs.
func begin_preload(ids: Array, paths: Array = []) -> Array:
	var jobs: Array = []
	for id in ids:
		var entries: Array = [[id, _model_path(id)]]
		if id == "vault_door":
			for part in ["vault_door_frame", "vault_door_leaf"]:
				entries.append(["vault_door/" + part, "%svault_door/%s.glb" % [MODEL_DIR, part]])
		for e in entries:
			if _scene_cache.has(e[0]) or not ResourceLoader.exists(e[1]):
				continue
			ResourceLoader.load_threaded_request(e[1], "", true)
			jobs.append({"key": e[0], "path": e[1], "kind": "scene"})
	for p in paths:
		if _tex_cache.has(p) or not ResourceLoader.exists(p):
			continue
		ResourceLoader.load_threaded_request(p, "", true)
		jobs.append({"key": p, "path": p, "kind": "tex"})
	return jobs


## Polls jobs, stores finished resources in the caches; returns progress 0..1.
func poll_preload(jobs: Array) -> float:
	if jobs.is_empty():
		return 1.0
	var done := 0
	for j in jobs:
		if j.get("done", false):
			done += 1
			continue
		var st := ResourceLoader.load_threaded_get_status(j.path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var res = ResourceLoader.load_threaded_get(j.path)
			if j.kind == "scene":
				_scene_cache[j.key] = res
			else:
				_tex_cache[j.key] = res
			j["done"] = true
			done += 1
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			j["done"] = true
			done += 1
	return float(done) / jobs.size()


## Every PBR texture file of every texture set (+ HDRIs).
func texture_paths(hdris: Array = []) -> Array:
	var out: Array = []
	var d := DirAccess.open(TEX_DIR)
	if d:
		for set_name in d.get_directories():
			for map in ["albedo", "normal", "roughness", "ao", "metallic"]:
				for ext in [".jpg", ".png"]:
					var p: String = TEX_DIR + set_name + "/" + map + ext
					if ResourceLoader.exists(p):
						out.append(p)
	for h in hdris:
		for ext in [".hdr", ".exr"]:
			if ResourceLoader.exists(HDRI_DIR + h + ext):
				out.append(HDRI_DIR + h + ext)
	return out


func has_model(id: String) -> bool:
	return ResourceLoader.exists(_model_path(id))


func _model_path(id: String) -> String:
	return "%s%s/%s.glb" % [MODEL_DIR, id, id]


## Instantiates model `id`. The returned Node3D is NOT inside the tree yet.
func model(id: String) -> Node3D:
	var path := _model_path(id)
	if not _scene_cache.has(id):
		_scene_cache[id] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scene_cache[id]
	if ps:
		var inst := ps.instantiate()
		if SLIM.has(id):
			_slim(inst, float(SLIM[id]))
		if inst is Node3D:
			return inst
		var wrap := Node3D.new()
		wrap.add_child(inst)
		return wrap
	return _placeholder(id)


## Heavy Sketchfab props (a small stone has 6k triangles, the ruined mill 170k): the
## share of the original triangle count to keep. The importer already generated LOD
## index sets with meshoptimizer; the finest one under the share becomes the mesh.
const SLIM := {
	"ruined_building": 0.2, "factory_hall": 0.35, "concrete_fence": 0.12,
	"car_sedan": 0.3, "car_wreck": 0.3, "street_lamp": 0.25, "sandbags": 0.2,
	"rock_a": 0.15, "rock_b": 0.15, "boulder": 0.15, "stone_small": 0.1,
	"tree_dead": 0.3, "tree_dead_b": 0.25, "tree_leafy": 0.4, "log_fallen": 0.2, "tree_stump": 0.25,
	"ruin_block": 0.25, "branches_dry": 0.3, "lamp_cage": 0.2, "chair": 0.3, "oil_barrel": 0.3, "bunk_bed": 0.3,
	"workbench": 0.25, "locker": 0.4, "military_crate": 0.35, "fridge_old": 0.45, "sofa_old": 0.45, "metal_shelf": 0.5,
	"wooden_crate": 0.4, "table_metal": 0.5, "radio_station": 0.2, "supermarket_shelf": 0.5,
}
var _slim_cache := {}  # source Mesh -> slimmed ArrayMesh
var slim_stats := [0, 0, 0]  # triangles before / after, milliseconds spent (--act=fps prints it)


func _slim(root: Node, ratio: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		if m == null:
			continue
		if not _slim_cache.has(m):
			_slim_cache[m] = _slim_mesh(m, ratio)
			# drop the full-resolution copy: it would otherwise sit on the GPU all session
			# (every instance of this model goes through here and gets the slim mesh)
			if m is ArrayMesh:
				(m as ArrayMesh).clear_surfaces()
		mi.mesh = _slim_cache[m]


func _slim_mesh(m: Mesh, ratio: float) -> Mesh:
	var t0 := Time.get_ticks_usec()
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var d: Dictionary = RenderingServer.mesh_get_surface(m.get_rid(), si)
		var vc: int = d.get("vertex_count", 0)
		var ic: int = d.get("index_count", 0)
		var arrays := m.surface_get_arrays(si)
		var target := int(ic * ratio)
		var pick: PackedByteArray = PackedByteArray()
		var pick_n := -1
		var coarsest: PackedByteArray = PackedByteArray()
		var coarsest_n := ic
		var stride := 2 if vc <= 65535 else 4
		for l in d.get("lods", []):
			var bytes: PackedByteArray = l.index_data
			var n := bytes.size() / stride
			if n <= target and n > pick_n:
				pick = bytes
				pick_n = n
			if n < coarsest_n:
				coarsest = bytes
				coarsest_n = n
		if pick_n < 0 and coarsest_n < ic:
			pick = coarsest
			pick_n = coarsest_n
		slim_stats[0] += ic / 3
		if pick_n > 0:
			slim_stats[1] += pick_n / 3
			if stride == 4:
				arrays[Mesh.ARRAY_INDEX] = pick.to_int32_array()
			else:
				var idx := PackedInt32Array()
				idx.resize(pick_n)
				for i in pick_n:
					idx[i] = pick.decode_u16(i * 2)
				arrays[Mesh.ARRAY_INDEX] = idx
		else:
			slim_stats[1] += ic / 3
		out.add_surface_from_arrays(m.surface_get_primitive_type(si), arrays)
		out.surface_set_material(out.get_surface_count() - 1, m.surface_get_material(si))
		out.surface_set_name(out.get_surface_count() - 1, m.surface_get_name(si))
	slim_stats[2] += (Time.get_ticks_usec() - t0) / 1000
	return out


## Instantiates a sub-part saved next to a model, e.g. ("vault_door", "vault_door_leaf").
func model_part(id: String, part: String) -> Node3D:
	var key := id + "/" + part
	var path := "%s%s/%s.glb" % [MODEL_DIR, id, part]
	if not _scene_cache.has(key):
		_scene_cache[key] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scene_cache[key]
	if ps:
		return ps.instantiate()
	return null


## Builds the blast door as {root, pivot, leaf}: frame + leaf on a hinge pivot.
## Model space: opening centred near x=0.25, y=1.22; corridor (outside) is -Z;
## the leaf is modelled open — pivot.rotation.y = CLOSED_YAW closes it.
const DOOR_HINGE := Vector3(-1.258, 0.0, 0.874)
const DOOR_CLOSED_YAW := -PI * 0.5

func vault_door(closed: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "VaultDoor"
	var frame := model_part("vault_door", "vault_door_frame")
	var leaf := model_part("vault_door", "vault_door_leaf")
	if frame == null or leaf == null:
		var whole := model("vault_door")
		root.add_child(whole)
		return {"root": root, "pivot": null, "leaf": whole}
	root.add_child(frame)
	var pivot := Node3D.new()
	pivot.position = DOOR_HINGE
	root.add_child(pivot)
	pivot.add_child(leaf)
	leaf.position = -DOOR_HINGE
	pivot.rotation.y = DOOR_CLOSED_YAW if closed else 0.0
	# collision: frame slab with the opening left free, and the leaf body
	var fb := StaticBody3D.new()
	root.add_child(fb)
	# frame slab spans x -1.985..1.985, z 0.83..1.75; opening x -0.95..1.45, y 0..2.42
	for spec in [[Vector3(1.04, 2.6, 0.92), Vector3(-1.465, 1.3, 1.29)], [Vector3(0.54, 2.6, 0.92), Vector3(1.715, 1.3, 1.29)],
			[Vector3(2.4, 0.2, 0.92), Vector3(0.25, 2.5, 1.29)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[0]
		cs.shape = bs
		cs.position = spec[1]
		fb.add_child(cs)
	var lb := StaticBody3D.new()
	pivot.add_child(lb)
	var lcs := CollisionShape3D.new()
	var lbs := BoxShape3D.new()
	# open leaf in pivot space: x 0..1.45 (thickness), z -2.62..0 (diameter)
	lbs.size = Vector3(1.3, 2.25, 2.5)
	lcs.shape = lbs
	lcs.position = Vector3(0.72, 1.2, -1.31)
	lb.add_child(lcs)
	return {"root": root, "pivot": pivot, "leaf": leaf}


func _placeholder(id: String) -> Node3D:
	var size: Vector3 = FALLBACK_SIZE.get(id, Vector3.ONE * 0.5)
	var root := Node3D.new()
	root.name = "placeholder_" + id
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.33, 0.3)
	mat.roughness = 0.8
	if id.begins_with("enemy") or id.begins_with("survivor"):
		var cap := CapsuleMesh.new()
		cap.radius = size.x * 0.5
		cap.height = size.y
		cap.material = mat
		mat.albedo_color = Color(0.18, 0.2, 0.16)
		mi.mesh = cap
	else:
		var box := BoxMesh.new()
		box.size = size
		box.material = mat
		mi.mesh = box
	mi.position.y = size.y * 0.5
	root.add_child(mi)
	return root


## Local-space AABB of all meshes under `root` (root's own transform ignored).
func model_aabb(root: Node3D, visible_only := false) -> AABB:
	var res := AABB()
	var has := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var t: Transform3D = it[1]
		if visible_only and n is Node3D and not (n as Node3D).visible:
			continue
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var b: AABB = t * (n as MeshInstance3D).get_aabb()
			res = b if not has else res.merge(b)
			has = true
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
	if not has:
		return AABB(Vector3(-0.25, 0, -0.25), Vector3(0.5, 0.5, 0.5))
	return res


## Applies a function to every GeometryInstance3D below root.
func for_each_geometry(root: Node, fn: Callable) -> void:
	if root is GeometryInstance3D:
		fn.call(root)
	for c in root.get_children():
		for_each_geometry(c, fn)


func set_shadows(root: Node, on: bool) -> void:
	for_each_geometry(root, func(g: GeometryInstance3D) -> void:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var r := find_animation_player(c)
		if r:
			return r
	return null


# --------------------------------------------------------------------------
# Textures / materials
# --------------------------------------------------------------------------

func texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[path] = t
	return t


func _tex_any(dir: String, base: String) -> Texture2D:
	for ext in [".jpg", ".png", ".jpeg", ".webp"]:
		var t := texture(dir + base + ext)
		if t:
			return t
	return null


func has_texture_set(tex_id: String) -> bool:
	return _tex_any(TEX_DIR + tex_id + "/", "albedo") != null


## PBR material from res://assets/textures/<tex_id>/.
## opts: tile (m per repeat, triplanar), triplanar (bool, default true), world (bool),
##       tint (Color), fallback (Color), rough_mul, metal (float), uv (Vector2 scale for non-triplanar),
##       emission (Color), normal_scale
func pbr(tex_id: String, opts: Dictionary = {}) -> StandardMaterial3D:
	var key := tex_id + JSON.stringify(opts)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var dir := TEX_DIR + tex_id + "/"
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var alb := _tex_any(dir, "albedo")
	if alb:
		m.albedo_texture = alb
		m.albedo_color = opts.get("tint", Color.WHITE)
	else:
		m.albedo_color = opts.get("fallback", Color(0.45, 0.45, 0.43))
	var nrm := _tex_any(dir, "normal")
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = opts.get("normal_scale", 1.0)
	var rough := _tex_any(dir, "roughness")
	if rough:
		m.roughness_texture = rough
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness = opts.get("rough_mul", 1.0)
	else:
		m.roughness = opts.get("rough_mul", 0.85)
	var ao := _tex_any(dir, "ao")
	if ao:
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.3
	var met := _tex_any(dir, "metallic")
	if met:
		m.metallic_texture = met
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.metallic = opts.get("metal", 1.0)
	else:
		m.metallic = opts.get("metal", 0.0)
	if opts.get("triplanar", true):
		var tile: float = opts.get("tile", 2.0)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = opts.get("world", true)
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / tile
	else:
		var uv: Vector2 = opts.get("uv", Vector2.ONE)
		m.uv1_scale = Vector3(uv.x, uv.y, 1)
	if opts.has("emission"):
		m.emission_enabled = true
		m.emission = opts["emission"]
		m.emission_energy_multiplier = opts.get("emission_energy", 1.0)
	_mat_cache[key] = m
	return m


func hdri(id: String) -> Texture2D:
	for ext in [".hdr", ".exr"]:
		var t := texture(HDRI_DIR + id + ext)
		if t:
			return t
	return null


# --------------------------------------------------------------------------
# Audio
# --------------------------------------------------------------------------

## Returns a stream for `id`. If variants id_1..id_N exist, picks one at random.
func sound(id: String) -> AudioStream:
	if not _sound_cache.has(id):
		var list: Array = []
		var base := _audio_file(id)
		if base:
			list.append(base)
		for i in range(1, 9):
			var v := _audio_file("%s_%d" % [id, i])
			if v:
				list.append(v)
			elif i > 1:
				break
		if list.is_empty():
			var synth := Synth.make(id)
			if synth:
				list.append(synth)
		_sound_cache[id] = list
	var arr: Array = _sound_cache[id]
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]


func _audio_file(id: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var p: String = AUDIO_DIR + id + ext
		if ResourceLoader.exists(p):
			return load(p)
	return null


## Returns a looping copy of the stream (does not mutate the cached resource).
func looped(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var s := stream.duplicate()
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var bytes_per := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var ch := 2 if w.stereo else 1
		w.loop_end = w.data.size() / (bytes_per * ch)
	return s


# --------------------------------------------------------------------------
# Fonts
# --------------------------------------------------------------------------

## kind: "heading" (Oswald), "body" (Barlow), "bold" (Barlow SemiBold), "mono"
func font(kind: String) -> Font:
	if _font_cache.has(kind):
		return _font_cache[kind]
	var f: Font = null
	match kind:
		"heading":
			var base: FontFile = load(FONT_DIR + "Oswald.ttf") if ResourceLoader.exists(FONT_DIR + "Oswald.ttf") else null
			if base:
				var fv := FontVariation.new()
				fv.base_font = base
				fv.variation_opentype = {"wght": 600}
				f = fv
		"body":
			f = load(FONT_DIR + "Barlow-Regular.ttf") if ResourceLoader.exists(FONT_DIR + "Barlow-Regular.ttf") else null
		"bold":
			f = load(FONT_DIR + "Barlow-SemiBold.ttf") if ResourceLoader.exists(FONT_DIR + "Barlow-SemiBold.ttf") else null
		"mono":
			f = load(FONT_DIR + "ShareTechMono.ttf") if ResourceLoader.exists(FONT_DIR + "ShareTechMono.ttf") else null
	if f == null:
		f = ThemeDB.fallback_font
	_font_cache[kind] = f
	return f
