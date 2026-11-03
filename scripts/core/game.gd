extends Node
## Game flow: scene changes, pause/mouse handling, sleep, expeditions, death.
## Debug CLI (after `--`): --scene=intro|bunker|surface|menu --shots=2,5 --shotdir=PATH
##   --quit=SECONDS --pose=x,y,z,yaw_deg[,pitch_deg] --day=N --loc=factory --give=all --windowed

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"intro": "res://scenes/intro.tscn",
	"bunker": "res://scenes/bunker.tscn",
	"surface": "res://scenes/expedition.tscn",
}

var ui_locks := 0
var player: Node = null
var level: Node = null
var build_mode_active := false
var args := {}
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	State.died.connect(_on_died)
	State.new_day.connect(_on_new_day)
	if args.has("scene"):
		_debug_boot.call_deferred()
	elif args.has("shots") or args.has("quit"):
		_schedule_debug()


# --------------------------------------------------------------------------
# Scene flow
# --------------------------------------------------------------------------

const SCENE_MODELS := {
	"menu": ["vault_door", "oil_barrel", "military_crate", "fire_extinguisher", "sandbags", "lamp_cage"],
	"intro": ["apartment_block", "bus_stop", "bench", "trash_bin", "car_sedan", "utility_pole", "street_lamp", "tree_leafy",
		"house_small", "oil_barrel", "military_crate", "concrete_barrier", "car_wreck", "lamp_cage", "metal_shelf",
		"fire_extinguisher", "vault_door", "factory_hall", "warehouse", "concrete_fence", "water_tower", "tire_pile",
		"burnt_truck", "scrap_pile"],
	"bunker": ["vault_door", "locker", "sandbags", "fire_extinguisher", "bunk_bed", "table_metal", "chair", "canned_food",
		"water_jug", "radio_station", "workbench", "crt_computer", "sofa_old", "metal_shelf", "wooden_crate", "military_crate",
		"jerrycan", "first_aid_kit", "oil_barrel", "diesel_generator", "electrical_panel", "water_tank", "water_purifier",
		"air_filter_unit", "toolbox", "planter_box", "lamp_cage", "bucket", "car_battery", "fridge_old", "rubble_pile",
		"plant_tomato", "plant_lettuce", "plant_pepper", "mushrooms"],
	"surface": ["ruined_building", "car_wreck", "bus_wreck", "rubble_pile", "tree_dead", "utility_pole", "concrete_barrier",
		"wooden_crate", "military_crate", "metal_shelf", "locker", "oil_barrel", "first_aid_kit", "toolbox", "supermarket_shelf",
		"tank_wreck", "sandbags", "enemy_mutant", "enemy_hazmat", "enemy_dog", "enemy_bandit", "survivor_npc", "weapon_axe",
		"weapon_pistol", "weapon_rifle", "ruin_wall_a", "ruin_wall_b", "ruin_house", "ruin_block", "debris_slab", "tire_pile",
		"scrap_pile", "road_sign", "radiation_sign", "burnt_truck", "shop_ruin", "enemy_zombie", "fps_pistol", "fps_rifle",
		"fps_shotgun", "tree_dead_b", "rock_a", "rock_b", "stone_small", "boulder", "log_fallen", "tree_stump", "branches_dry",
		"vault_door", "lamp_cage", "radio_antenna", "jerrycan", "apartment_block"],
}
const SCENE_TITLES := {"menu": "Meniul principal", "intro": "14 octombrie 2031 · 07:41", "bunker": "Obiectivul 17", "surface": "Suprafața"}


func _trace(msg: String) -> void:
	if args.has("selftest") or args.has("trace"):
		print("[trace] ", msg)


func goto(key: String, fade := 0.7) -> void:
	_trace("goto %s busy=%s" % [key, _busy])
	if _busy:
		return
	_busy = true
	build_mode_active = false
	await HUD.fade_to(1.0, fade)
	HUD.close_all_panels()
	HUD.set_mode("none")
	HUD.objective("")
	ui_locks = 0
	get_tree().paused = false
	Audio.stop_all_ambient(0.4)
	player = null
	level = null
	var title: String = SCENE_TITLES.get(key, "")
	if key == "surface":
		title = ItemDB.LOCATIONS.get(State.current_location, {}).get("name", title)
	HUD.show_loading(title)
	if get_tree().has_method("unload_current_scene"):
		get_tree().call("unload_current_scene")
	HUD.fade_to(0.0, 0.25)
	var hdris := ["sky_morning"] if key == "intro" else (["sky_overcast"] if key == "surface" else [])
	var jobs := Assets.begin_preload(SCENE_MODELS.get(key, []), Assets.texture_paths(hdris))
	while true:
		var p := Assets.poll_preload(jobs)
		HUD.set_loading_progress(p * 0.85, "resurse")
		if p >= 1.0:
			break
		await get_tree().process_frame
	HUD.set_loading_progress(0.88, "construiesc nivelul")
	await get_tree().process_frame
	get_tree().change_scene_to_file(SCENES[key])
	await get_tree().process_frame
	await get_tree().process_frame
	# a few frames rendered behind the loading screen compile the shader pipelines
	for i in 8:
		HUD.set_loading_progress(0.9 + i * 0.0125, "shadere")
		await get_tree().process_frame
	HUD.set_loading_progress(1.0)
	await HUD.fade_to(1.0, 0.25)
	HUD.hide_loading()
	update_mouse()
	_busy = false
	HUD.fade_to(0.0, fade)


func new_game() -> void:
	State.reset()
	goto("intro")


func continue_game() -> void:
	if State.load_game():
		State.context = "bunker"
		goto("bunker")
	else:
		new_game()


func intro_complete() -> void:
	State.context = "bunker"
	State.day = 1
	State.minute = 8.0 * 60.0 + 10.0
	State.flags["intro_done"] = true
	State.save_game()
	goto("bunker", 1.5)


func start_expedition(loc_id: String) -> void:
	var loc: Dictionary = ItemDB.LOCATIONS[loc_id]
	HUD.close_all_panels()
	get_tree().paused = false
	var moved := State.auto_loadout()
	if not moved.is_empty():
		HUD.toast("Echipament luat din depozit: " + ", ".join(moved), "info")
	State.save_game()
	_trace("expedition: departure, paused=%s locks=%d" % [get_tree().paused, ui_locks])
	if level and level.has_method("play_departure"):
		await level.play_departure()
	_trace("expedition: departure done, busy=%s" % _busy)
	State.current_location = loc_id
	State.simulate(float(loc.travel) * 60.0 * State.mul("travel"), false)
	State.context = "surface"
	if State.mask_filter_left <= 1.0 and State.remove("mask_filter"):
		State.mask_filter_left = 360.0
	goto("surface")


func return_to_bunker() -> void:
	var loc: Dictionary = ItemDB.LOCATIONS.get(State.current_location, {"travel": 0.5})
	State.simulate(float(loc.travel) * 60.0 * State.mul("travel"), false)
	State.context = "bunker"
	State.stats["expeditions"] = int(State.stats.get("expeditions", 0)) + 1
	State.flags["autosave_on_enter"] = true
	goto("bunker")


func sleep(hours: float) -> void:
	if _busy:
		return
	_busy = true
	State.running = false
	await HUD.fade_to(1.0, 0.9)
	State.simulate(hours * 60.0, true)
	State.save_game()
	await get_tree().create_timer(0.6).timeout
	State.running = not State.dead
	_busy = false
	HUD.toast("Ai dormit %d ore. Joc salvat." % roundi(hours), "good")
	HUD.fade_to(0.0, 0.9)


func hours_until_morning() -> float:
	var target := 7.0 * 60.0
	var m := State.minute
	var diff := target - m if m < target else 1440.0 - m + target
	return diff / 60.0


func start_build(type: String) -> void:
	if level and level.has_method("start_build"):
		level.start_build(type)


func reapply_environment() -> void:
	if level and level.has_method("apply_quality"):
		level.apply_quality()


# --------------------------------------------------------------------------
# UI / mouse / pause
# --------------------------------------------------------------------------

func push_ui() -> void:
	ui_locks += 1
	update_mouse()


func pop_ui() -> void:
	ui_locks = maxi(ui_locks - 1, 0)
	update_mouse()


func update_mouse() -> void:
	var gameplay := HUD.mode in ["intro", "bunker", "surface"]
	if gameplay and ui_locks == 0 and not args.has("nolook"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = gameplay and ui_locks > 0


func register_player(p: Node) -> void:
	player = p
	if args.has("pose"):
		var v: PackedStringArray = String(args.pose).split(",")
		if v.size() >= 3:
			p.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		if v.size() >= 4:
			p.rotation.y = deg_to_rad(float(v[3]))
		if v.size() >= 5 and p.has_method("set_pitch"):
			p.set_pitch(deg_to_rad(float(v[4])))


func _on_died(reason: String) -> void:
	HUD.close_all_panels()
	var retry := func() -> void:
		if State.context == "intro":
			new_game()
		else:
			continue_game()
	HUD.open_panel(DeathPanel.new(reason, retry))


func _on_new_day(d: int) -> void:
	HUD.toast("A început ziua %d." % d, "info")


# --------------------------------------------------------------------------
# Debug helpers
# --------------------------------------------------------------------------

func _debug_boot() -> void:
	var s: String = args.scene
	State.reset()
	if args.has("day"):
		State.day = int(args.day)
	match s:
		"intro":
			State.context = "intro"
		"bunker":
			State.context = "bunker"
			State.minute = 9.0 * 60.0
			if args.has("lit"):
				State.flags["tut"] = 6
				State.generator_on = true
		"surface":
			State.context = "surface"
			State.current_location = args.get("loc", "factory")
			State.add("gas_mask", 1, true)
			State.add("mask_filter", 2, true)
			State.add("axe", 1, true)
			State.mask_filter_left = 360.0
	if args.get("give", "") == "all":
		for id in ItemDB.ITEMS:
			State.add(id, 5, true)
	if SCENES.has(s):
		get_tree().change_scene_to_file(SCENES[s])
	_schedule_debug()
	if args.has("depart"):
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: start_expedition(String(args.depart)))
	if args.has("goto"):
		get_tree().create_timer(1.5, true, false, true).timeout.connect(func() -> void: goto(String(args.goto)))
	if args.has("panel"):
		get_tree().create_timer(3.0, true, false, true).timeout.connect(_debug_panel)
	if args.has("selftest"):
		var st = load("res://scripts/core/selftest.gd")
		if s == "intro":
			st.run_intro(get_tree(), args.selftest)
		else:
			st.run(get_tree())


func _debug_panel() -> void:
	match String(args.panel):
		"inventory":
			HUD.open_panel(InventoryPanel.new())
		"settings":
			HUD.open_panel(SettingsPanel.new())
		"craft":
			HUD.open_panel(CraftPanel.new())
		"map":
			HUD.open_panel(MapPanel.new())
		"build":
			HUD.open_panel(BuildPanel.new())
		"tech":
			HUD.open_panel(TechPanel.new())
		"localmap":
			level.open_local_map()


func _schedule_debug() -> void:
	if args.has("shots"):
		for t in String(args.shots).split(","):
			get_tree().create_timer(float(t), true, false, true).timeout.connect(_shot.bind(t))
	if args.has("quit"):
		get_tree().create_timer(float(args.quit), true, false, true).timeout.connect(get_tree().quit)
	if args.has("act"):
		for a in String(args.act).split(","):
			var parts := a.split("@")
			if parts.size() == 2:
				get_tree().create_timer(float(parts[1]), true, false, true).timeout.connect(_debug_act.bind(parts[0]))


## Scripted test actions: --act=fire@3.5,reload@4,swing@5,kill@6,hit@6,sprint@2,walk@2,stop@3
func _debug_act(what: String) -> void:
	var p = player
	if p == null or not is_instance_valid(p):
		return
	match what:
		"fire":
			p.weapons._fire()
		"reload":
			p.weapons.reload()
		"swing":
			p.weapons._start_swing()
		"sprint":
			p.set_meta("debug_move", 2)
		"walk":
			p.set_meta("debug_move", 1)
		"stop":
			p.set_meta("debug_move", 0)
		"fps":
			print("[fps] %d  draw_calls=%d  primitives=%d" % [Engine.get_frames_per_second(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		"kill", "hit":
			var best: Node = null
			var bd := INF
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.state == e.S.DEAD:
					continue
				var d: float = e.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = e
			if best:
				var dir: Vector3 = (best.global_position - p.global_position).normalized()
				best.take_hit(9999.0 if what == "kill" else 20.0, p.global_position, best.global_position + Vector3.UP * 1.3, dir * 2.0)


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir: String = args.get("shotdir", "user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s_%s.png" % [dir, args.get("scene", "menu"), tag]
	img.save_png(path)
	print("[shot] ", path)
