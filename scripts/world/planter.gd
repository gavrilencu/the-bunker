class_name Planter
extends Interactable
## A planter box / mushroom bed. Growth is simulated in State; this node only
## mirrors it visually and handles interaction.

var key := ""
var bed := "planter"  # or "mushroom_bed"
var crop_node: Node3D
var crop_id := ""
var soil: MeshInstance3D
var _refresh_t := 0.0
var _base_scale := 1.0


func setup(p_key: String, p_bed: String, model_id := "planter_box") -> Planter:
	key = p_key
	bed = p_bed
	if not State.planters.has(key):
		State.planters[key] = {"crop": "", "growth": 0.0, "water": 0.0, "dead": false, "lit": false, "neglect": 0.0}
	var m := Assets.model(model_id)
	add_child(m)
	var aabb := Assets.model_aabb(m)
	Geo.fit_box(self, m, 1.0, 1.0)
	soil = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(aabb.size.x * 0.86, aabb.size.z * 0.8)
	soil.mesh = pm
	var sm := Assets.pbr("soil", {"tile": 0.8, "fallback": Color(0.2, 0.14, 0.09)})
	if bed == "mushroom_bed":
		sm = Assets.pbr("soil", {"tile": 0.8, "fallback": Color(0.1, 0.08, 0.06), "tint": Color(0.55, 0.5, 0.45)})
	soil.material_override = sm
	soil.position = Vector3(aabb.get_center().x, aabb.end.y * 0.82, aabb.get_center().z)
	add_child(soil)
	prompt_func = _prompt
	used.connect(_on_used)
	_refresh_visual()
	return self


func data() -> Dictionary:
	return State.planters[key]


func _prompt() -> String:
	var d := data()
	var crop: String = d.get("crop", "")
	var bed_name := "Pat de ciuperci" if bed == "mushroom_bed" else "Jardinieră"
	if crop == "":
		return "%s — Plantează" % bed_name
	var info: Dictionary = ItemDB.CROPS[crop]
	if d.get("dead", false):
		return "%s uscate — Curăță" % info.name
	var g := float(d.get("growth", 0.0))
	if g >= 1.0:
		return "%s — Recoltează" % info.name
	var w := float(d.get("water", 0.0))
	var light_ok: bool = (not info.light) or (bool(d.get("lit", false)) and State.power_state() == "gen")
	var status := "%s %d%%  ·  apă %d%%%s" % [info.name, roundi(g * 100.0), roundi(w), "" if light_ok else "  ·  FĂRĂ LUMINĂ"]
	if w < 60.0:
		return status + " — Udă (1 L)"
	return status + " — Crește"


func _on_used(_by: Node) -> void:
	var d := data()
	var crop: String = d.get("crop", "")
	if crop == "":
		_plant_menu()
		return
	if d.get("dead", false):
		d["crop"] = ""
		d["dead"] = false
		d["growth"] = 0.0
		Audio.sfx("dig", -6.0)
		_refresh_visual()
		return
	if float(d.get("growth", 0.0)) >= 1.0:
		var info: Dictionary = ItemDB.CROPS[crop]
		for k in info.yield:
			State.add(k, int(info.yield[k]))
		State.stats["harvests"] = int(State.stats.get("harvests", 0)) + 1
		d["crop"] = ""
		d["growth"] = 0.0
		Audio.sfx("pickup", -2.0)
		_refresh_visual()
		return
	if float(d.get("water", 0.0)) < 60.0:
		if State.water < 1.0:
			HUD.toast("Rezervorul de apă e gol!", "danger")
			return
		State.water -= 1.0
		d["water"] = 100.0
		Audio.sfx("water_pour", -4.0)
		HUD.toast("Ai udat cultura (−1 L).", "info")


func _plant_menu() -> void:
	var opts: Array = []
	for seed_id in ["seeds_tomato", "seeds_lettuce", "seed_potato", "spores_mushroom"]:
		var crop: String = ItemDB.ITEMS[seed_id].crop
		var info: Dictionary = ItemDB.CROPS[crop]
		if info.bed != bed:
			continue
		var n := State.available(seed_id)
		opts.append({
			"text": "%s  (ai %d)" % [info.name, n],
			"desc": "%d h de creștere%s. Recoltă: %s" % [int(info.hours), ", are nevoie de lumină" if info.light else ", crește în întuneric", ItemDB.cost_text(info.yield)],
			"enabled": n > 0,
			"cb": func() -> void: _plant(seed_id, crop),
		})
	if opts.is_empty():
		HUD.toast("Nu ai semințe potrivite.", "warn")
		return
	HUD.choose("Plantează", "Alege ce plantezi. Nu uita să uzi cultura.", opts)


func _plant(seed_id: String, crop: String) -> void:
	if not State.take(seed_id):
		return
	var d := data()
	d["crop"] = crop
	d["growth"] = 0.0
	d["water"] = 100.0
	d["dead"] = false
	d["neglect"] = 0.0
	State.water = maxf(State.water - 1.0, 0.0)
	Audio.sfx("dig", -6.0)
	HUD.toast("Ai plantat: %s." % ItemDB.CROPS[crop].name, "good")
	State.flags["planted"] = true
	_refresh_visual()


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 1.0
		_refresh_visual()


func _refresh_visual() -> void:
	var d := data()
	var crop: String = d.get("crop", "")
	if crop != crop_id:
		if crop_node:
			crop_node.queue_free()
			crop_node = null
		crop_id = crop
		if crop != "":
			crop_node = Node3D.new()
			add_child(crop_node)
			var count := 3 if crop != "mushroom" else 4
			var aabb := Assets.model_aabb(get_child(0) as Node3D)
			for i in count:
				var cm := Assets.model(ItemDB.CROPS[crop].model)
				crop_node.add_child(cm)
				var fx := (float(i) + 0.5) / count - 0.5
				cm.position = Vector3(aabb.get_center().x + fx * aabb.size.x * 0.75, 0, aabb.get_center().z)
				cm.rotation.y = randf() * TAU
				Assets.set_shadows(cm, true)
			crop_node.position.y = soil.position.y - 0.02
	if crop_node:
		var g := clampf(float(d.get("growth", 0.0)), 0.0, 1.0)
		var s := lerpf(0.15, 1.0, g)
		crop_node.scale = Vector3.ONE * s
		var dead: bool = d.get("dead", false)
		Assets.for_each_geometry(crop_node, func(gi: GeometryInstance3D) -> void:
			gi.transparency = 0.0
			if dead:
				gi.material_overlay = _dead_mat()
			else:
				gi.material_overlay = null)


static var _dead: StandardMaterial3D
static func _dead_mat() -> StandardMaterial3D:
	if _dead == null:
		_dead = StandardMaterial3D.new()
		_dead.albedo_color = Color(0.25, 0.18, 0.1, 0.75)
		_dead.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dead.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	return _dead
