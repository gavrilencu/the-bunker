extends LevelBase
## Obiectivul 17 — the hub. Rooms are carved out of solid rock with CSG.

const H := 3.2
## depth of the carved CSG floor below the visible floor planes
const SINK := 0.1
const ROOMS := {
	"airlock": Rect2(-2.5, -14.6, 5.0, 8.0),
	"hall": Rect2(-7.0, -6.0, 14.0, 11.0),
	"storage": Rect2(-16.0, -4.0, 8.4, 7.0),
	"tech": Rect2(7.6, -5.0, 9.4, 9.0),
	"green": Rect2(-5.0, 5.6, 10.0, 9.0),
	"workshop": Rect2(-16.0, 6.0, 10.4, 8.0),
	"infirmary": Rect2(5.6, 6.0, 9.4, 8.0),
}
## Doorways (XZ rects) connecting rooms. Dig doorways listed in DIGS.
const DOORS := [
	Rect2(-1.3, -6.6, 2.6, 0.6),
	Rect2(-7.6, -1.3, 0.6, 2.6),
	Rect2(7.0, -1.3, 0.6, 2.6),
	Rect2(-1.3, 5.0, 2.6, 0.6),
]
const DIGS := {
	"sec_b": {"room": "workshop", "door": Rect2(-5.6, 8.7, 0.6, 2.6), "title": "Secțiunea B — Atelierul", "site": Vector3(-4.35, 0, 10.0)},
	"sec_c": {"room": "infirmary", "door": Rect2(5.0, 8.7, 0.6, 2.6), "title": "Secțiunea C — Infirmeria", "site": Vector3(4.35, 0, 10.0)},
}
const PAINT := {
	"airlock": Color(0.36, 0.33, 0.2), "hall": Color(0.2, 0.31, 0.26), "storage": Color(0.27, 0.29, 0.31),
	"tech": Color(0.22, 0.27, 0.34), "green": Color(0.24, 0.32, 0.22), "workshop": Color(0.33, 0.27, 0.2),
	"infirmary": Color(0.75, 0.78, 0.76),
}

var csg: CSGCombiner3D
var open_rooms: Array = []
var lights: Array = []  # [{light, base, kind}]
var grow_lamps: Array[Vector3] = []
var planter_nodes: Array[Planter] = []
var gen_node: Node3D
var built_nodes := {}  # index -> root node
var airlock_pivot: Node3D
var _upgrade_nodes: Array = []
var gen_sound: AudioStreamPlayer3D
var _last_power := ""
var _flicker_t := 0.0
var _tut_t := 0.0

# build mode
var build_type := ""
var ghost: Node3D
var ghost_rot := 0.0
var ghost_valid := false
var ghost_flip := false
var ghost_ok_mat: StandardMaterial3D
var ghost_bad_mat: StandardMaterial3D


func _ready() -> void:
	State.context = "bunker"
	HUD.set_mode("bunker")
	make_environment({
		"sky": false, "ambient": Color(0.15, 0.15, 0.155), "ambient_energy": 1.0,
		"fog": false, "vfog_density": 0.012, "vfog_albedo": Color(0.85, 0.84, 0.8),
		"vfog_length": 40.0, "exposure": 1.05, "glow": 0.55, "bloom": 0.03,
		"ssao_radius": 1.0, "ssao_intensity": 2.6, "profile": {"vfog": true, "ssil": true, "sdfgi": true},
	})
	csg = CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = 1
	add_child(csg)
	var outer := CSGBox3D.new()
	outer.size = Vector3(80, 12, 80)
	outer.position = Vector3(0, H * 0.5, 0)
	outer.material = BunkerBuilder.wall_material()
	csg.add_child(outer)
	for room in ["airlock", "hall", "storage", "tech", "green"]:
		_open_room(room)
	for d in DOORS:
		_carve_door(d)
	for k in DIGS:
		if int(State.dig.get(k, 0)) >= DigSite.STAGES:
			_open_dig(k, false)
		else:
			_dig_site(k)
	_furnish()
	_spawn_built()
	_update_lit()
	ghost_ok_mat = _ghost_mat(Color(0.3, 1.0, 0.45, 0.35))
	ghost_bad_mat = _ghost_mat(Color(1.0, 0.25, 0.2, 0.35))
	State.refresh_caps()
	_apply_upgrade_visuals()

	spawn_player(Vector3(0, 0.1, -9.5), 180.0)
	player.footstep_surface = "concrete"
	Audio.ambient("bg", "ambient_bunker", -6.0, 2.0)
	Audio.play_music("music_bunker", 4.0, -10.0)
	Settings.set_reverb(0.22, 0.6)
	State.running = true
	_apply_power(true)
	if State.flags.get("autosave_on_enter", false):
		State.flags.erase("autosave_on_enter")
		var n := State.unload_to_stash()
		State.save_game()
		HUD.toast("Te-ai întors în buncăr. Joc salvat.", "good")
		if n > 0:
			HUD.toast("Prada (%d obiecte) a fost descărcată în depozit." % n, "info")
	if not State.flags.has("tut"):
		State.flags["tut"] = 0
		State.generator_on = false
		_apply_power(true)


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

func _open_room(room: String) -> void:
	if open_rooms.has(room):
		return
	open_rooms.append(room)
	var r: Rect2 = ROOMS[room]
	var h := 3.0 if room == "airlock" else H
	var b := CSGBox3D.new()
	b.operation = CSGShape3D.OPERATION_SUBTRACTION
	# carved floor sits 10 cm below the visible floor plane (no z-fighting)
	b.size = Vector3(r.size.x, h + SINK, r.size.y)
	b.position = Vector3(r.get_center().x, (h - SINK) * 0.5, r.get_center().y)
	b.material = BunkerBuilder.wall_material(PAINT.get(room, Color(0.2, 0.31, 0.26)), true, 0.35 if room == "infirmary" else 0.55)
	csg.add_child(b)
	var fm: Material
	match room:
		"tech":
			fm = Assets.pbr("metal_plate", {"tile": 1.5, "fallback": Color(0.35, 0.36, 0.37)})
		"infirmary":
			fm = Assets.pbr("tiles_wall", {"tile": 1.2, "fallback": Color(0.75, 0.75, 0.72)})
		_:
			fm = Assets.pbr("concrete_floor", {"tile": 2.5, "fallback": Color(0.4, 0.4, 0.38)})
	var fl := Geo.plane(self, r.size, Vector3(r.get_center().x, 0.0, r.get_center().y), fm, true)
	fl.set_meta("surface", "concrete")
	Geo.dust(self, Vector3(r.get_center().x, 1.6, r.get_center().y), Vector3(r.size.x * 0.45, 1.4, r.size.y * 0.45), int(r.get_area() * 2.5))
	_ceiling_details(room, r, h)


func _carve_door(d: Rect2) -> void:
	var b := CSGBox3D.new()
	b.operation = CSGShape3D.OPERATION_SUBTRACTION
	b.size = Vector3(d.size.x + 0.02, 2.5 + SINK, d.size.y + 0.02)
	b.position = Vector3(d.get_center().x, (2.5 - SINK) * 0.5, d.get_center().y)
	b.material = BunkerBuilder.wall_material(Color(0.36, 0.33, 0.2))
	csg.add_child(b)
	var fl := Geo.plane(self, d.size, Vector3(d.get_center().x, 0.0, d.get_center().y), Assets.pbr("concrete_floor", {"tile": 2.5}), true)
	fl.set_meta("surface", "concrete")


func _ceiling_details(room: String, r: Rect2, h: float) -> void:
	var pipe_m := Assets.pbr("painted_metal", {"tile": 1.0, "fallback": Color(0.3, 0.33, 0.3)})
	var rust_m := Assets.pbr("rusty_metal", {"tile": 1.0, "fallback": Color(0.35, 0.28, 0.22)})
	# two pipes running along the long axis, near the ceiling
	var along_x := r.size.x >= r.size.y
	var length := (r.size.x if along_x else r.size.y) - 0.2
	for i in 2:
		var off := 0.35 + i * 0.28
		var pos: Vector3
		var rot: Vector3
		if along_x:
			pos = Vector3(r.get_center().x, h - 0.25 - i * 0.05, r.position.y + off)
			rot = Vector3(0, 0, PI * 0.5)
		else:
			pos = Vector3(r.position.x + off, h - 0.25 - i * 0.05, r.get_center().y)
			rot = Vector3(PI * 0.5, 0, 0)
		Geo.cylinder(self, 0.07 + i * 0.03, length, pos, pipe_m if i == 0 else rust_m, rot, false, 12)
	# lamps
	var spots: Array = []
	match room:
		"airlock": spots = [Vector3(0, 0, -10.5)]
		"hall": spots = [Vector3(-3.5, 0, -2.2), Vector3(3.5, 0, -2.2), Vector3(-3.5, 0, 2.4), Vector3(3.5, 0, 2.4)]
		"storage": spots = [Vector3(-11.8, 0, -0.5)]
		"tech": spots = [Vector3(12.3, 0, -0.5)]
		"green": spots = [Vector3(0, 0, 7.2)]
		"workshop": spots = [Vector3(-10.8, 0, 10.0)]
		"infirmary": spots = [Vector3(10.3, 0, 10.0)]
	for s in spots:
		var lm := Geo.prop(self, "lamp_cage", Vector3(s.x, h - 0.35, s.z), 0.0, "none")
		Assets.set_shadows(lm, false)
		var warm := Color(1.0, 0.8, 0.58) if room != "infirmary" else Color(0.9, 0.95, 1.0)
		var l := Geo.omni(self, Vector3(s.x, h - 0.45, s.z), warm, 2.8, 12.0)
		lights.append({"light": l, "base": 2.8, "kind": "main"})
	# emergency red light by the doorway
	var em := Geo.omni(self, Vector3(r.get_center().x, h - 0.2, r.get_center().y), Color(1.0, 0.16, 0.08), 0.0, 9.0, false)
	lights.append({"light": em, "base": 1.5, "kind": "emergency"})


func _dig_site(k: String) -> void:
	var d: Dictionary = DIGS[k]
	var door: Rect2 = d.door
	# carve a shallow niche so the rubble sits in an opening
	var b := CSGBox3D.new()
	b.operation = CSGShape3D.OPERATION_SUBTRACTION
	b.size = Vector3(door.size.x + 0.3, 2.5 + SINK, door.size.y)
	b.position = Vector3(door.get_center().x, (2.5 - SINK) * 0.5, door.get_center().y)
	b.material = BunkerBuilder.wall_material()
	csg.add_child(b)
	var site := DigSite.new()
	add_child(site)
	site.position = d.site
	site.setup(k, d.title, Vector3(1.2, 2.2, 2.6))
	site.set_ghost(false)
	site.cleared.connect(func() -> void: _open_dig(k, true))


func _open_dig(k: String, fresh: bool) -> void:
	var d: Dictionary = DIGS[k]
	_open_room(d.room)
	_carve_door(d.door)
	_furnish_room(d.room)
	if fresh:
		player.add_shake(0.4)
		_apply_power(true)
		_update_lit()


func _furnish() -> void:
	for room in open_rooms:
		_furnish_room(room)


func _top(node: Node3D) -> float:
	var m: Node3D = node.get_child(0) if node is StaticBody3D and node.get_child_count() > 0 else node
	return Assets.model_aabb(m).end.y * m.scale.y


func _container(key: String, title: String, model: String, pos: Vector3, rot: float, items: Dictionary) -> LootContainer:
	var c := LootContainer.new()
	add_child(c)
	c.position = pos
	c.rotation.y = rot
	var m := Assets.model(model)
	c.add_child(m)
	Geo.fit_box(c, m, 1.0, 1.0)
	c.setup(key, title, items)
	c.set_ghost(false)
	return c


func _furnish_room(room: String) -> void:
	match room:
		"airlock":
			# closed blast door, decorative face (model -Z) toward the room,
			# slab back (model z 1.75) on the north wall
			var door := Interactable.new()
			add_child(door)
			var vd := Assets.vault_door(true)
			door.add_child(vd.root)
			airlock_pivot = vd.pivot
			(vd.root as Node3D).rotation.y = PI
			(vd.root as Node3D).position = Vector3(0.25, 0, -14.6 + 1.75)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(2.6, 2.5, 0.3)
			cs.shape = bs
			cs.position = Vector3(0, 1.25, -13.55)
			door.add_child(cs)
			door.prompt_func = _door_prompt
			door.used.connect(func(_by: Node) -> void: _door_use())
			door.set_ghost(true)
			_container("airlock_locker", "Dulap ecluză", "locker", Vector3(2.05, 0, -9.0), -PI * 0.5, {"gas_mask": 1, "mask_filter": 2, "geiger": 1})
			Geo.prop(self, "sandbags", Vector3(-1.5, 0, -12.6), 0.2)
			Geo.prop(self, "fire_extinguisher", Vector3(2.15, 0, -13.9), 0.0)
			Geo.label3d(self, "ECLUZA  ·  OBIECTIVUL 17", Vector3(0, 2.75, -14.55), 0.0, 0.2, Color(0.95, 0.8, 0.3))
		"hall":
			# beds keep clear of the storage doorway (west wall, z -1.3..1.3)
			for z in [-3.9, 3.0]:
				Geo.interact_prop(self, "bunk_bed", Vector3(-6.45, 0, z), PI * 0.5, func() -> String: return "Pat — Dormi", _sleep_menu)
			var table := Geo.prop(self, "table_metal", Vector3(0.6, 0, 0.6), 0.0)
			var ty := _top(table)
			Geo.prop(self, "chair", Vector3(-0.5, 0, 1.4), PI * 0.6)
			Geo.prop(self, "chair", Vector3(1.8, 0, -0.2), -PI * 0.4)
			Geo.prop(self, "canned_food", Vector3(0.2, ty, 0.5), 0.3, "none")
			Geo.prop(self, "canned_food", Vector3(0.32, ty, 0.62), 1.2, "none")
			Geo.prop(self, "water_jug", Vector3(1.1, ty, 0.8), 0.0, "none")
			var radio_table := Geo.prop(self, "table_metal", Vector3(4.9, 0, -5.5), PI)
			Geo.interact_prop(self, "radio_station", Vector3(4.6, _top(radio_table), -5.5), PI, _radio_prompt, _radio_use)
			Geo.prop(self, "chair", Vector3(4.6, 0, -4.6), PI)
			Geo.interact_prop(self, "workbench", Vector3(-3.6, 0, -5.68), PI * 0.5, func() -> String: return "Banc de lucru — Fabrică", func() -> void: HUD.open_panel(CraftPanel.new()))
			var term_table := Geo.prop(self, "table_metal", Vector3(6.2, 0, 2.6), PI * 0.5)
			Geo.interact_prop(self, "crt_computer", Vector3(6.2, _top(term_table), 2.6), -PI * 0.5, func() -> String: return "Terminal ZX-17 — Starea buncărului", _terminal)
			Geo.prop(self, "sofa_old", Vector3(3.2, 0, 4.2), PI)
			Geo.prop(self, "locker", Vector3(-4.4, 0, 4.55), PI)
			Geo.prop(self, "fire_extinguisher", Vector3(6.75, 0, -1.6), -PI * 0.5)
		"storage":
			_container("shelf_food", "Raft cu conserve", "metal_shelf", Vector3(-15.65, 0, -2.4), PI * 0.5, {"canned_meat": 4, "canned_beans": 4, "crackers": 3})
			_container("shelf_water", "Raft cu apă și medicamente", "metal_shelf", Vector3(-15.65, 0, 0.0), PI * 0.5, {"water_bottle": 6, "bandage": 3, "antirad": 2})
			_container("shelf_mats", "Raft cu materiale", "metal_shelf", Vector3(-15.65, 0, 2.3), PI * 0.5, {"cloth": 4, "plastic": 3, "duct_tape": 1, "charcoal": 3})
			_container("crate_tools", "Ladă cu unelte", "wooden_crate", Vector3(-9.0, 0, 2.3), 0.2, {"scrap": 6, "wood": 6, "pipe": 2, "shovel": 1})
			_container("crate_seeds", "Ladă de stat — rezervă agricolă", "military_crate", Vector3(-11.0, 0, 2.4), 0.0, {"seeds_lettuce": 2, "seeds_tomato": 2, "seed_potato": 2, "spores_mushroom": 2, "soil": 2})
			_container("fuel_drums", "Canistre de motorină", "jerrycan", Vector3(-13.6, 0, -3.5), 0.0, {"fuel_can": 3})
			_container("medkit_store", "Trusă de prim ajutor", "first_aid_kit", Vector3(-9.2, 0, -3.6), 0.0, {"medkit": 1, "bandage": 2})
			Geo.prop(self, "oil_barrel", Vector3(-12.6, 0, -3.4), 0.0)
			Geo.prop(self, "oil_barrel", Vector3(-12.0, 0, -3.5), 1.0)
			Geo.prop(self, "metal_shelf", Vector3(-12.0, 0, 2.7), PI)
			Geo.interact_prop(self, "locker", Vector3(-10.4, 0, -3.55), 0.0, func() -> String: return "Depozitul buncărului — Deschide  (%d obiecte)" % State.stash.size(), func() -> void:
				var inv := InventoryPanel.new()
				inv.view = "stash"
				HUD.open_panel(inv))
			Geo.label3d(self, "DEPOZIT", Vector3(-7.95, 2.7, 0), PI * 0.5, 0.25)
		"tech":
			gen_node = Geo.interact_prop(self, "diesel_generator", Vector3(13.4, 0, -4.3), 0.0, _gen_prompt, _gen_menu)
			Geo.interact_prop(self, "electrical_panel", Vector3(9.6, 0.9, -4.85), 0.0, func() -> String: return "Panou electric — Consum", _panel_info)
			Geo.interact_prop(self, "water_tank", Vector3(15.9, 0, 2.9), 0.0, _tank_prompt, _tank_menu)
			Geo.interact_prop(self, "water_purifier", Vector3(13.0, 0, 3.4), PI, func() -> String: return "Purificator de apă — Purifică", _purifier_menu)
			Geo.interact_prop(self, "air_filter_unit", Vector3(9.0, 0, 3.2), PI, _air_prompt, _air_menu)
			Geo.prop(self, "oil_barrel", Vector3(16.4, 0, -4.4), 0.0)
			Geo.prop(self, "toolbox", Vector3(10.6, 0, -4.5), 0.4)
			Geo.label3d(self, "CAMERA TEHNICĂ", Vector3(7.65, 2.7, 0), -PI * 0.5, 0.25)
		"green":
			_planter("g1", "planter", Vector3(-2.6, 0, 8.6), 0.0)
			_planter("g2", "planter", Vector3(-2.6, 0, 11.6), 0.0)
			_planter("g3", "planter", Vector3(2.6, 0, 8.6), 0.0)
			_planter("m1", "mushroom_bed", Vector3(2.6, 0, 13.2), 0.0)
			_grow_lamp(Vector3(-2.6, 0, 10.1), false)
			_grow_lamp(Vector3(2.6, 0, 7.4), false)
			Geo.prop(self, "bucket", Vector3(0.6, 0, 14.0), 0.0)
			Geo.label3d(self, "SERA", Vector3(0, 2.7, 5.65), PI, 0.25)
		"workshop":
			_container("ws_toolbox", "Trusă de scule", "toolbox", Vector3(-15.4, 0.0, 7.0), PI * 0.5, {"electronics": 3, "duct_tape": 2, "scrap": 4})
			_container("ws_locker", "Dulap vechi", "locker", Vector3(-15.6, 0, 9.4), PI * 0.5, {"cloth": 3, "battery_cell": 2, "electronics": 1})
			_container("ws_crates", "Lăzi sovietice", "military_crate", Vector3(-12.0, 0, 13.4), PI, {"wood": 6, "pipe": 2, "gunpowder": 2, "canned_meat": 3})
			Geo.prop(self, "workbench", Vector3(-10.5, 0, 6.5), 0.0)
			Geo.prop(self, "car_battery", Vector3(-8.2, 0, 13.4), 0.0)
		"infirmary":
			_container("inf_kit", "Dulap medical", "first_aid_kit", Vector3(14.6, 0.9, 8.0), -PI * 0.5, {"medkit": 2, "bandage": 4, "antirad": 3})
			_container("inf_locker", "Dulap infirmerie", "locker", Vector3(14.6, 0, 11.4), -PI * 0.5, {"cloth": 4, "plastic": 2, "charcoal": 2, "air_filter": 1})
			Geo.interact_prop(self, "bunk_bed", Vector3(8.0, 0, 13.4), 0.0, func() -> String: return "Pat — Dormi", _sleep_menu)
			Geo.prop(self, "fridge_old", Vector3(6.2, 0, 13.4), 0.0)


func _planter(key: String, bed: String, pos: Vector3, rot: float, model := "planter_box") -> Planter:
	var p := Planter.new()
	add_child(p)
	p.position = pos
	p.rotation.y = rot
	p.setup(key, bed, model)
	p.set_ghost(false)
	planter_nodes.append(p)
	return p


func _grow_lamp(pos: Vector3, built: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var pole_m := Assets.pbr("painted_metal", {"tile": 1.0, "fallback": Color(0.3, 0.3, 0.3)})
	Geo.cylinder(root, 0.03, 2.4, Vector3(0, 1.2, 0), pole_m)
	var bar := Geo.mesh_box(root, Vector3(1.2, 0.06, 0.18), Vector3(0, 2.4, 0), Geo.emissive_mat(Color(1.0, 0.45, 0.85), 4.0))
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := Geo.omni(root, Vector3(0, 2.25, 0), Color(1.0, 0.55, 0.85), 1.2, 4.5, false)
	lights.append({"light": l, "base": 1.2, "kind": "grow", "mesh": bar})
	grow_lamps.append(pos)
	root.set_meta("lamp_pos", pos)
	if built:
		_apply_power(true)
	return root


func _update_lit() -> void:
	planter_nodes = planter_nodes.filter(func(x) -> bool: return is_instance_valid(x) and not x.is_queued_for_deletion())
	for p in planter_nodes:
		var lit: bool = p.has_meta("self_lit")
		for g in grow_lamps:
			if Vector2(p.position.x - g.x, p.position.z - g.z).length() < 3.2:
				lit = true
				break
		State.planters[p.key]["lit"] = lit


func _spawn_built() -> void:
	for i in State.built.size():
		_spawn_built_one(i)


func _spawn_built_one(i: int) -> void:
	var b: Dictionary = State.built[i]
	var type: String = b.get("type", "")
	if not ItemDB.BUILDABLES.has(type):
		return
	var p: Array = b.p
	var pos := Vector3(p[0], p[1], p[2])
	var rot := float(b.get("r", 0.0))
	var before := get_child_count()
	_spawn_built_type(i, type, pos, rot)
	# the first node added for this entry is its root
	if get_child_count() > before:
		var root := get_child(before)
		root.set_meta("built_index", i)
		built_nodes[i] = root
		for k in range(before + 1, get_child_count()):
			get_child(k).set_meta("built_extra", i)


func _spawn_built_type(i: int, type: String, pos: Vector3, rot: float) -> void:
	var def: Dictionary = ItemDB.BUILDABLES[type]
	match type:
		"planter", "mushroom_bed":
			_planter("b%d" % i, type, pos, rot)
		"hydro_rack":
			var pl := _planter("b%d" % i, "planter", pos, rot, "hydroponic_rack")
			pl.set_meta("self_lit", true)
		"grow_lamp":
			_grow_lamp(pos, true)
		"stove":
			Geo.interact_prop(self, def.model, pos, rot, func() -> String: return "Aragaz de campanie — Gătește", func() -> void: HUD.open_panel(CraftPanel.new("stove")))
		"bike_generator":
			var it := Interactable.new()
			add_child(it)
			it.position = pos
			it.rotation.y = rot
			_bike_mesh(it)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = def.size
			cs.shape = sh
			cs.position.y = def.size.y * 0.5
			it.add_child(cs)
			it.prompt_func = func() -> String: return "Pedalează 1 oră (baterii %d%%)" % roundi(State.battery / State.battery_max * 100.0)
			it.hold_time = 1.0
			it.used.connect(func(_by: Node) -> void: _pedal())
		"bed":
			Geo.interact_prop(self, "bunk_bed", pos, rot, func() -> String: return "Pat — Dormi", _sleep_menu)
		"lamp":
			var lm := Geo.prop(self, "lamp_cage", Vector3(pos.x, H - 0.35, pos.z), rot, "none")
			var l := Geo.omni(self, Vector3(pos.x, H - 0.5, pos.z), Color(1.0, 0.8, 0.58), 1.2, 7.0, false)
			lights.append({"light": l, "base": 1.2, "kind": "main"})
			lm.set_meta("built", i)
		"water_collector":
			Geo.interact_prop(self, def.model, pos, rot, func() -> String: return "Condensator de apă — %s" % ("funcționează" if State.power_state() == "gen" else "fără curent"), func() -> void: pass)
		_:
			if def.model != "":
				Geo.prop(self, def.model, pos, rot)


func _bike_mesh(parent: Node3D) -> void:
	var m := Assets.pbr("painted_metal", {"tile": 0.6, "fallback": Color(0.3, 0.32, 0.3)})
	var dark := Geo.color_mat(Color(0.08, 0.08, 0.08), 0.6)
	Geo.cylinder(parent, 0.32, 0.06, Vector3(0, 0.34, -0.55), dark, Vector3(0, 0, PI * 0.5))
	Geo.cylinder(parent, 0.32, 0.06, Vector3(0, 0.34, 0.55), dark, Vector3(0, 0, PI * 0.5))
	Geo.mesh_box(parent, Vector3(0.06, 0.06, 1.2), Vector3(0, 0.55, 0), m)
	Geo.mesh_box(parent, Vector3(0.06, 0.6, 0.06), Vector3(0, 0.75, 0.35), m)
	Geo.mesh_box(parent, Vector3(0.22, 0.06, 0.3), Vector3(0, 1.05, 0.35), dark)
	Geo.mesh_box(parent, Vector3(0.5, 0.05, 0.05), Vector3(0, 1.05, -0.45), m)
	Geo.mesh_box(parent, Vector3(0.3, 0.25, 0.25), Vector3(0.25, 0.25, -0.55), Geo.color_mat(Color(0.5, 0.15, 0.1), 0.5, 0.4))


# --------------------------------------------------------------------------
# Station interactions
# --------------------------------------------------------------------------

## Opens the blast door before leaving for the surface.
func play_departure() -> void:
	Audio.sfx("door_vault_open", 0.0, 0.0)
	if player:
		player.can_move = false
		player.add_shake(0.3)
	if airlock_pivot:
		var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(airlock_pivot, "rotation:y", 0.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	else:
		await get_tree().create_timer(1.5).timeout


func demolish(i: int) -> void:
	if i < 0 or i >= State.built.size():
		return
	var b: Dictionary = State.built[i]
	var type: String = b.get("type", "")
	if not ItemDB.BUILDABLES.has(type):
		return
	var def: Dictionary = ItemDB.BUILDABLES[type]
	var refund := []
	for k in def.cost:
		var n := ceili(int(def.cost[k]) * 0.5)
		State.add(k, n, true, true)
		refund.append("%s ×%d" % [ItemDB.item_name(k), n])
	State.built[i] = {"type": "_removed", "p": [0, 0, 0]}
	var pos := Vector3.ZERO
	for c in get_children():
		if c.get_meta("built_index", -1) == i or c.get_meta("built_extra", -1) == i:
			pos = c.global_position if c is Node3D else pos
			if c.has_meta("lamp_pos"):
				grow_lamps.erase(c.get_meta("lamp_pos"))
			c.queue_free()
	built_nodes.erase(i)
	State.planters.erase("b%d" % i)
	lights = lights.filter(func(e) -> bool: return is_instance_valid(e.light) and not (e.light as Node).is_queued_for_deletion() and not _freed_parent(e.light))
	State.refresh_caps()
	_update_lit.call_deferred()
	_dust_puff(pos)
	Audio.sfx("demolish", -2.0)
	HUD.toast("Demontat: %s  →  depozit: %s" % [def.name, ", ".join(refund)], "info")


func _freed_parent(n: Node) -> bool:
	var p := n.get_parent()
	while p and p != self:
		if p.is_queued_for_deletion():
			return true
		p = p.get_parent()
	return false


func _dust_puff(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 40
	p.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.6, 0.1, 0.6)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -0.3, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.6))
	fade.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = FX.soft_texture()
	mat.albedo_color = Color(0.7, 0.66, 0.6)
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	p.draw_pass_1 = qm
	add_child(p)
	p.global_position = pos + Vector3.UP * 0.2
	p.emitting = true
	p.finished.connect(p.queue_free)


func open_local_map() -> void:
	HUD.open_panel(LocalMapPanel.new(self))


func map_config() -> Dictionary:
	var markers: Array = []
	var add := func(pos: Vector3, icon: String, col: Color, label := "", small := false) -> void:
		markers.append({"pos": pos, "icon": icon, "color": col, "label": label, "small": small})
	var ps := State.power_state()
	add.call(Vector3(0, 0, -13.6), "objective", Color(1.0, 0.35, 0.25), "Ușa blindată")
	add.call(Vector3(13.4, 0, -4.3), "power", UITheme.GOOD if ps == "gen" else UITheme.DANGER, "Generator %.0f L" % State.fuel)
	add.call(Vector3(15.9, 0, 2.9), "water", UITheme.RADIO, "Apă %d L" % roundi(State.water))
	add.call(Vector3(9.0, 0, 3.2), "air", UITheme.WARN if State.air_filter < 30.0 else UITheme.TEXT, "FVU %d%%" % roundi(State.air_filter))
	add.call(Vector3(4.6, 0, -5.5), "radio", UITheme.ACCENT if not State.pending_radio().is_empty() else UITheme.TEXT, "Radio")
	add.call(Vector3(-3.6, 0, -5.7), "tool", UITheme.TEXT, "Banc de lucru")
	add.call(Vector3(-10.4, 0, -3.55), "res", UITheme.TEXT, "Depozit")
	for z in [-3.9, 3.0]:
		add.call(Vector3(-6.45, 0, z), "energy", UITheme.TEXT_DIM, "", true)
	for p in planter_nodes:
		if is_instance_valid(p):
			var d := p.data()
			var ripe: bool = float(d.get("growth", 0.0)) >= 1.0 and d.get("crop", "") != ""
			var col: Color = UITheme.GOOD if ripe else (UITheme.DANGER if d.get("dead", false) else (UITheme.WARN if d.get("crop", "") != "" and float(d.get("water", 0.0)) < 30.0 else UITheme.TEXT_DIM))
			add.call(p.global_position, "seed", col, "", true)
	for k in DIGS:
		if int(State.dig.get(k, 0)) < 3:
			add.call(DIGS[k].site, "weight", UITheme.WARN, "Dărâmături")
	var labels: Array = []
	var names := {"airlock": "Ecluza", "hall": "Sala principală", "storage": "Depozit", "tech": "Camera tehnică", "green": "Sera", "workshop": "Atelier", "infirmary": "Infirmerie"}
	for room in ROOMS:
		var r: Rect2 = ROOMS[room]
		var txt: String = names[room] if open_rooms.has(room) else names[room] + " (prăbușit)"
		labels.append({"pos": Vector3(r.get_center().x, 0, r.position.y + 0.9), "text": txt})
	return {"center": Vector2(0.5, 0.0), "extent": 36.0, "height": 3.05, "far": 9.0, "ambient": 1.1, "live": true,
		"markers": markers, "labels": labels, "title": "Obiectivul 17", "subtitle": "Planul buncărului · Ziua %d, %s" % [State.day, State.clock_text()],
		"legend": [["power", UITheme.GOOD, "Generator / energie"], ["water", UITheme.RADIO, "Rezervor de apă"], ["air", UITheme.TEXT, "Ventilație FVU"],
			["seed", UITheme.GOOD, "Cultură gata de recoltat"], ["seed", UITheme.WARN, "Cultură care trebuie udată"], ["weight", UITheme.WARN, "Dărâmături de săpat"],
			["objective", Color(1.0, 0.35, 0.25), "Ieșirea la suprafață"]],
		"info": ["Confort: %d  ·  Îmbunătățiri: %d/%d" % [roundi(State.comfort()), State.upgrades.size(), ItemDB.UPGRADES.size()],
			"[U] dezvoltare  ·  [B] construcție  ·  [X] demontează"]}


func on_upgrade(_id: String) -> void:
	_apply_upgrade_visuals()
	_apply_power(true)
	_update_lit()


## Small visible changes for purchased upgrades.
func _apply_upgrade_visuals() -> void:
	for n in _upgrade_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_upgrade_nodes.clear()
	var steel := Assets.pbr("rusty_metal", {"tile": 1.0, "fallback": Color(0.3, 0.3, 0.3)})
	if State.has_up("door_2"):
		for k in 3:
			_upgrade_nodes.append(Geo.box(self, Vector3(3.6, 0.12, 0.14), Vector3(0, 0.6 + k * 0.8, -13.45), steel))
	if State.has_up("battery_2"):
		for k in 4:
			_upgrade_nodes.append(Geo.prop(self, "car_battery", Vector3(8.4 + k * 0.38, 0, -4.6), 0.0))
	if State.has_up("well") and open_rooms.has("workshop"):
		var w := Geo.interact_prop(self, "water_purifier", Vector3(-7.2, 0, 12.8), PI, func() -> String: return "Puț de adâncime — +10 L/zi", func() -> void: pass)
		_upgrade_nodes.append(w)
	if State.has_up("armory") and Assets.has_model("weapon_rack"):
		_upgrade_nodes.append(Geo.prop(self, "weapon_rack", Vector3(-2.05, 0, -8.0), PI * 0.5))
	if State.has_up("radio_2"):
		var mast := Assets.pbr("painted_metal", {"tile": 1.0})
		_upgrade_nodes.append(Geo.cylinder(self, 0.03, 2.8, Vector3(6.6, 1.4, -5.8), mast))
	if State.has_up("solar"):
		_upgrade_nodes.append(Geo.mesh_box(self, Vector3(0.05, 1.4, 0.05), Vector3(16.9, 1.6, -1.0), Geo.color_mat(Color(0.1, 0.1, 0.1))))


func _door_prompt() -> String:
	return "Ușa blindată — Ieși la suprafață"


func _door_use() -> void:
	if State.day < 2 and not Game.args.has("scene"):
		HUD.subtitle("Alex", "Nu acum. Radiația de afară e încă letală. Măcar o zi trebuie să stau închis aici.", 5.0)
		return
	HUD.open_panel(MapPanel.new())


func _radio_prompt() -> String:
	if State.power_state() == "none":
		return "Stație radio R-105 — Fără curent"
	var n := State.pending_radio().size()
	return "Stație radio R-105 — Ascultă%s" % ("  ·  SEMNAL NOU" if n > 0 else "")


func _radio_use() -> void:
	if State.power_state() == "none":
		HUD.toast("Radioul nu are curent.", "warn")
		return
	HUD.open_panel(RadioPanel.new())
	State.flags["radio_used"] = true


func _gen_prompt() -> String:
	return "Generator diesel — Comenzi  (%s · %.1f L)" % ["pornit" if State.generator_on and State.fuel > 0 else "oprit", State.fuel]


func _gen_menu() -> void:
	var hours_left := State.fuel / State.fuel_rate()
	var info := "Rezervor: %.1f / %.0f L.  Consum: %.2f L/oră (~%d ore rămase).\nFără generator: doar baterii (lumină de avarie, ventilație redusă)." % [State.fuel, State.FUEL_MAX, State.fuel_rate(), int(hours_left)]
	var opts: Array = []
	if State.generator_on:
		opts.append({"text": "Oprește generatorul (economisește combustibil)", "cb": func() -> void:
			State.generator_on = false
			Audio.sfx("power_down", -2.0)
			_apply_power(true)})
	else:
		opts.append({"text": "Pornește generatorul", "enabled": State.fuel > 0.0, "cb": func() -> void:
			State.generator_on = true
			Audio.sfx("power_up", -2.0)
			_apply_power(true)
			State.flags["gen_started"] = true})
	opts.append({"text": "Alimentează cu o canistră de 10 L  (ai %d)" % State.available("fuel_can"), "enabled": State.available("fuel_can") > 0 and State.fuel < State.FUEL_MAX - 0.5, "cb": func() -> void:
		State.use_item("fuel_can")
		Audio.sfx("water_pour", -4.0)})
	HUD.choose("Generator diesel", info, opts)


func _panel_info() -> void:
	var ps := State.power_state()
	var info := "Sursă: %s\nGenerator: %.2f L/oră (lămpi de creștere: %d, condensatoare: %d)\nBaterii: %d / %d%%" % [
		{"gen": "generator", "battery": "baterii de avarie", "none": "NICIUNA"}[ps], State.fuel_rate(), State.grow_lamp_count(),
		State.building_count("water_collector"), roundi(State.battery), roundi(State.battery_max)]
	HUD.choose("Panou electric", info, [{"text": "OK", "cb": func() -> void: pass}])


func _tank_prompt() -> String:
	return "Rezervor de apă — Bea / umple  (%d L)" % roundi(State.water)


func _tank_menu() -> void:
	HUD.choose("Rezervor de apă", "Apă potabilă: %.1f / %.0f L." % [State.water, State.WATER_MAX], [
		{"text": "Bea apă (0,5 L)", "enabled": State.water >= 0.5 and State.hydration < 99.0, "cb": func() -> void:
			State.water -= 0.5
			State.hydration = minf(State.hydration + 30.0, 100.0)
			Audio.sfx("drink", -3.0)},
		{"text": "Umple o sticlă (0,5 L)", "enabled": State.water >= 0.5, "cb": func() -> void:
			State.water -= 0.5
			State.add("water_bottle", 1)
			Audio.sfx("water_pour", -6.0)},
	])


func _purifier_menu() -> void:
	var n := State.available("dirty_water")
	var powered := State.power_state() == "gen"
	HUD.choose("Purificator de apă", "Transformă apa murdară adusă de la suprafață în apă potabilă (5 L / canistră, 30 min). Are nevoie de generator.%s" % ("" if powered else "\nGENERATORUL E OPRIT."), [
		{"text": "Purifică toată apa murdară (ai %d canistre)" % n, "enabled": n > 0 and powered, "cb": func() -> void:
			State.take("dirty_water", n)
			State.simulate(30.0 * n, false)
			State.water = minf(State.water + 5.0 * n, State.WATER_MAX)
			Audio.sfx("water_pour", -2.0)
			HUD.toast("+%d L apă potabilă" % (5 * n), "good")},
	])


func _air_prompt() -> String:
	return "Unitate FVU — Verifică filtrul  (aer %d%% · filtru %d%%)" % [roundi(State.air_quality), roundi(State.air_filter)]


func _air_menu() -> void:
	HUD.choose("Unitate de filtrare FVU", "Filtrul se uzează ~4%/zi. Sub 20% pătrunde praf radioactiv în buncăr. Fără curent, aerul se viciază.", [
		{"text": "Înlocuiește filtrul  (ai %d)" % State.available("air_filter"), "enabled": State.available("air_filter") > 0, "cb": func() -> void:
			State.take("air_filter")
			State.air_filter = 100.0
			Audio.sfx("metal_impact", -6.0)
			HUD.toast("Filtru nou montat.", "good")},
	])


func _sleep_menu() -> void:
	var hm := Game.hours_until_morning()
	HUD.choose("Somn", "Oboseală: %d%%. În timpul somnului foamea și setea scad mai încet." % roundi(100.0 - State.energy), [
		{"text": "Dormi până dimineață (%.0f ore)" % hm, "cb": func() -> void: Game.sleep(hm)},
		{"text": "Dormi 2 ore", "cb": func() -> void: Game.sleep(2.0)},
		{"text": "Dormi 4 ore", "cb": func() -> void: Game.sleep(4.0)},
	])


func _pedal() -> void:
	if State.energy < 12.0:
		HUD.toast("Ești prea obosit.", "warn")
		return
	State.simulate(60.0, false)
	State.energy = maxf(State.energy - 10.0, 0.0)
	State.hydration = maxf(State.hydration - 6.0, 0.0)
	State.battery = minf(State.battery + 25.0, State.battery_max)
	Audio.sfx("generator_loop", -10.0)
	HUD.toast("Baterii: %d%%" % roundi(State.battery / State.battery_max * 100.0), "info")
	_apply_power(true)


func _terminal() -> void:
	var s := State.stats
	var info := "ZIUA %d · %s\nZile supraviețuite: %d\nExpediții: %d · Recolte: %d · Obiecte fabricate: %d\n\nCombustibil: %.1f L (%.0f ore)\nApă: %.0f L · Aer: %d%% · Filtru: %d%%\nRadiație absorbită: %d mSv\n\nSfat: %s" % [
		State.day, State.clock_text(), maxi(State.day - 1, 0), int(s.get("expeditions", 0)), int(s.get("harvests", 0)), int(s.get("crafted", 0)),
		State.fuel, State.fuel / State.fuel_rate(), State.water, roundi(State.air_quality), roundi(State.air_filter), roundi(State.radiation), _tip()]
	HUD.choose("Terminal ZX-17", info, [{"text": "Închide", "cb": func() -> void: pass}])


func _tip() -> String:
	if State.fuel < 8.0:
		return "Combustibilul e pe terminate. Caută canistre la suprafață sau oprește generatorul noaptea."
	if State.air_filter < 25.0:
		return "Filtrul de aer e uzat. Fabrică unul la banc (cărbune ×2, textile ×2, fier vechi)."
	if State.available("mask_filter") == 0:
		return "Fără filtre de mască nu poți ieși. Fabrică-le din cărbune, textile și plastic."
	return "Radiația de la suprafață scade în fiecare zi. Raidurile scurte sunt mai sigure."


# --------------------------------------------------------------------------
# Power & lights
# --------------------------------------------------------------------------

func _apply_power(force := false) -> void:
	var ps := State.power_state()
	if ps == _last_power and not force:
		return
	_last_power = ps
	for e in lights:
		var l: Light3D = e.light
		match e.kind:
			"main":
				l.light_energy = e.base if ps == "gen" else (e.base * 0.3 if ps == "battery" else 0.0)
				l.light_color = Color(1.0, 0.8, 0.58) if ps == "gen" else Color(1.0, 0.55, 0.3)
			"emergency":
				l.light_energy = 0.0 if ps == "gen" else e.base
			"grow":
				l.light_energy = e.base if ps == "gen" else 0.0
				if e.has("mesh"):
					(e.mesh as MeshInstance3D).visible = ps == "gen"
	if gen_node:
		var running := ps == "gen"
		if running and gen_sound == null:
			gen_sound = Audio.loop_at("generator_loop", gen_node, -3.0, 22.0)
		elif not running and gen_sound:
			gen_sound.queue_free()
			gen_sound = null
	Audio.ambient_volume("bg", -6.0 if ps == "gen" else -14.0)


func _process(delta: float) -> void:
	_apply_power()
	_flicker_t -= delta
	if _flicker_t <= 0.0 and State.power_state() == "gen":
		_flicker_t = randf_range(4.0, 14.0)
		var mains := lights.filter(func(e) -> bool: return e.kind == "main")
		if not mains.is_empty():
			var e: Dictionary = mains[randi() % mains.size()]
			var l: Light3D = e.light
			var tw := create_tween()
			for i in randi_range(2, 6):
				tw.tween_property(l, "light_energy", e.base * randf_range(0.05, 0.4), 0.04)
				tw.tween_property(l, "light_energy", e.base, randf_range(0.03, 0.12))
	_tutorial(delta)
	if build_type != "":
		_update_ghost()


func _tutorial(delta: float) -> void:
	_tut_t -= delta
	if _tut_t > 0.0:
		return
	_tut_t = 0.5
	var step := int(State.flags.get("tut", 99))
	var looted := 0
	for k in ["shelf_food", "shelf_water", "shelf_mats", "crate_tools", "crate_seeds", "fuel_drums", "medkit_store"]:
		if State.containers.get(k, false):
			looted += 1
	match step:
		0:
			HUD.objective("Pornește generatorul din camera tehnică (est)")
			if not State.flags.has("tut_said0"):
				State.flags["tut_said0"] = true
				HUD.subtitle("Alex", "Întuneric... Generatorul. Trebuie pornit înainte să se descarce bateriile de avarie.", 6.0)
			if State.generator_on and State.fuel > 0:
				State.flags["tut"] = 1
				HUD.subtitle("Alex", "Merge! Acum să văd ce a mai rămas în depozit.", 4.0)
		1:
			HUD.objective("Cercetează depozitul (vest) — %d/7" % looted)
			if looted >= 5:
				State.flags["tut"] = 2
		2:
			HUD.objective("Plantează semințe în seră (sud) și udă-le")
			if State.flags.get("planted", false):
				State.flags["tut"] = 3
		3:
			HUD.objective("Ascultă radioul din sala principală")
			if State.flags.get("radio_used", false):
				State.flags["tut"] = 4
		4:
			HUD.objective("Ia masca din dulapul ecluzei. Dormi, apoi pregătește prima ieșire.")
			if State.day >= 2:
				State.flags["tut"] = 5
		5:
			HUD.objective("Ziua %d — supraviețuiește. [B] construcție · [Tab] inventar" % State.day)
			State.flags["tut"] = 6
		_:
			HUD.objective("")


# --------------------------------------------------------------------------
# Build mode
# --------------------------------------------------------------------------

func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m


func start_build(type: String) -> void:
	cancel_build()
	build_type = type
	Game.build_mode_active = true
	var def: Dictionary = ItemDB.BUILDABLES[type]
	ghost = Node3D.new()
	add_child(ghost)
	if def.model != "":
		ghost.add_child(Assets.model(def.model))
	else:
		var holder := Node3D.new()
		ghost.add_child(holder)
		_bike_mesh(holder)
	Assets.set_shadows(ghost, false)
	HUD.set_build_hint("CONSTRUCȚIE: %s — click stânga plasează · R / rotița rotește · Esc / click dreapta anulează\nCost: %s" % [def.name, ItemDB.cost_text(def.cost)])


func cancel_build() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	build_type = ""
	Game.build_mode_active = false
	HUD.set_build_hint("")


func _update_ghost() -> void:
	if ghost == null or player == null:
		return
	var cam := player.cam
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_basis.z * 6.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [player.get_rid()]
	var r := space.intersect_ray(q)
	var def: Dictionary = ItemDB.BUILDABLES[build_type]
	ghost_valid = false
	if not r.is_empty() and (r.normal as Vector3).y > 0.8 and (r.position as Vector3).y < 0.3:
		var p: Vector3 = r.position
		p.x = snappedf(p.x, 0.25)
		p.z = snappedf(p.z, 0.25)
		p.y = 0.0
		ghost.global_position = p
		ghost.rotation.y = ghost_rot
		if def.get("wall", false):
			_snap_to_wall(ghost, def.size)
		ghost.visible = true
		ghost_valid = _inside_rooms(p, def.size) and _free_space(p, def.size) and p.distance_to(player.global_position) > 0.9 and State.has_all(def.cost)
	else:
		ghost.visible = false
	var mat := ghost_ok_mat if ghost_valid else ghost_bad_mat
	Assets.for_each_geometry(ghost, func(g: GeometryInstance3D) -> void: g.material_override = mat)


## Pushes wall-type furniture flush against the nearest wall, facing the room.
func _snap_to_wall(g: Node3D, size: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var best := 1.1
	var best_n := Vector3.ZERO
	var best_p := Vector3.ZERO
	var from := g.global_position + Vector3.UP * 0.6
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.1, 1)
		q.exclude = [player.get_rid()]
		var r := space.intersect_ray(q)
		if not r.is_empty() and r.collider == csg:
			var dist := from.distance_to(r.position)
			if dist < best:
				best = dist
				best_n = r.normal
				best_p = r.position
	if best_n != Vector3.ZERO:
		var yaw := atan2(best_n.x, best_n.z) + (PI if ghost_flip else 0.0)
		g.rotation.y = yaw
		var depth := size.z * 0.5 + 0.03
		var np := best_p + best_n * depth
		g.global_position = Vector3(np.x, 0.0, np.z)
		ghost_rot = yaw


func _inside_rooms(p: Vector3, size: Vector3) -> bool:
	var half := maxf(size.x, size.z) * 0.5
	for room in open_rooms:
		var r: Rect2 = ROOMS[room]
		if p.x - half > r.position.x + 0.1 and p.x + half < r.end.x - 0.1 and p.z - half > r.position.y + 0.1 and p.z + half < r.end.y - 0.1:
			return true
	return false


func _free_space(p: Vector3, size: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x * 0.9, maxf(size.y - 0.2, 0.2), size.z * 0.9)
	q.shape = sh
	q.transform = Transform3D(Basis(Vector3.UP, ghost_rot), p + Vector3(0, size.y * 0.5 + 0.1, 0))
	q.collision_mask = 1 | 2
	var hits := space.intersect_shape(q, 8)
	for h in hits:
		if h.collider != csg:
			return false
	return true


func _place() -> void:
	if not ghost_valid:
		Audio.sfx("ui_click", -2.0)
		return
	var def: Dictionary = ItemDB.BUILDABLES[build_type]
	if not State.consume(def.cost):
		return
	var p := ghost.global_position
	State.built.append({"type": build_type, "p": [p.x, p.y, p.z], "r": ghost_rot})
	var idx := State.built.size() - 1
	_spawn_built_one(idx)
	State.refresh_caps()
	if built_nodes.has(idx) and built_nodes[idx] is Node3D:
		var n: Node3D = built_nodes[idx]
		n.scale = Vector3(0.6, 0.05, 0.6)
		create_tween().tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dust_puff(p)
	Audio.sfx("build_place", -2.0)
	_update_lit()
	Audio.sfx("craft", -2.0)
	HUD.toast("Construit: %s" % def.name, "good")
	State.simulate(30.0, false)
	cancel_build()


func _unhandled_input(event: InputEvent) -> void:
	if build_type == "":
		return
	if event.is_action_pressed("attack"):
		_place()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("aim") or event.is_action_pressed("pause"):
		cancel_build()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate") or event.is_action_pressed("wheel_up"):
		ghost_rot += deg_to_rad(15.0)
		ghost_flip = not ghost_flip
	elif event.is_action_pressed("wheel_down"):
		ghost_rot -= deg_to_rad(15.0)
