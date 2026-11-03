class_name DigSite
extends Interactable
## Collapsed passage. Three shovel sessions (2 game hours each) clear it.

signal cleared

const STAGES := 3
var key := ""
var title := ""
var rubble: Node3D


func setup(p_key: String, p_title: String, size: Vector3) -> DigSite:
	key = p_key
	title = p_title
	hold_time = 2.5
	rubble = Node3D.new()
	add_child(rubble)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var mat := Assets.pbr("gravel", {"tile": 1.0, "fallback": Color(0.4, 0.38, 0.35)})
	var cmat := Assets.pbr("concrete_wall", {"tile": 1.5, "fallback": Color(0.5, 0.5, 0.48)})
	var pile := Assets.model("rubble_pile")
	rubble.add_child(pile)
	var aabb := Assets.model_aabb(pile)
	var s := minf(size.x / maxf(aabb.size.x, 0.1), size.y / maxf(aabb.size.y, 0.1)) * 1.1
	pile.scale = Vector3.ONE * s
	for i in 7:
		var chunk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.4, 1.1), rng.randf_range(0.2, 0.5), rng.randf_range(0.3, 0.8))
		chunk.mesh = bm
		chunk.material_override = cmat if i % 2 == 0 else mat
		chunk.position = Vector3(rng.randf_range(-size.x * 0.4, size.x * 0.4), rng.randf_range(0.1, size.y * 0.7), rng.randf_range(-size.z * 0.3, size.z * 0.3))
		chunk.rotation = Vector3(rng.randf() * 0.8, rng.randf() * TAU, rng.randf() * 0.8)
		rubble.add_child(chunk)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	add_child(cs)
	prompt_func = _prompt
	used.connect(_on_used)
	_update_visual()
	return self


func progress() -> int:
	return int(State.dig.get(key, 0))


func _prompt() -> String:
	if progress() >= STAGES:
		return ""
	if State.available("shovel") <= 0:
		return "%s — Ai nevoie de o lopată" % title
	return "%s — Sapă prin dărâmături  (%d/%d · 2 ore)" % [title, progress(), STAGES]


func _on_used(_by: Node) -> void:
	if progress() >= STAGES:
		return
	if State.available("shovel") <= 0:
		HUD.toast("Ai nevoie de o lopată.", "warn")
		return
	if State.energy < 10.0:
		HUD.toast("Ești prea obosit ca să sapi. Odihnește-te.", "warn")
		return
	Audio.sfx("dig", 0.0)
	State.simulate(120.0, false)
	State.energy = maxf(State.energy - 12.0, 0.0)
	State.dig[key] = progress() + 1
	State.add("soil", 1)
	if progress() >= STAGES:
		HUD.toast("Ai deschis: %s!" % title, "good")
		Audio.sfx("metal_impact", -6.0)
		cleared.emit()
		queue_free()
	else:
		HUD.toast("Săpat: %d/%d" % [progress(), STAGES], "info")
		_update_visual()


func _update_visual() -> void:
	var k := 1.0 - float(progress()) / STAGES * 0.6
	rubble.scale = Vector3(1.0, k, 1.0)
