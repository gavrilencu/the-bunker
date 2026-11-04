extends Node
## Game flow: scene changes, pause/mouse handling, sleep, expeditions, death.
## Debug CLI (after `--`): --scene=intro|bunker|surface|menu --shots=2,5 --shotdir=PATH
##   --quit=SECONDS --pose=x,y,z,yaw_deg[,pitch_deg] --day=N --loc=factory --give=all --windowed
##   bunker: --showcase=lights --build=TYPE --move=f:hall_table --panel=light

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
	elif args.has("continue"):
		# look at the real save (menu -> Continuă) without ever writing back to it
		_debug_continue.call_deferred()
	elif args.has("shots") or args.has("quit"):
		_schedule_debug()


func _debug_continue() -> void:
	continue_game()
	State.save_path = "user://debug_slot.json"
	_schedule_debug()


# --------------------------------------------------------------------------
# Scene flow
# --------------------------------------------------------------------------

const SCENE_MODELS := {
	"menu": ["vault_door", "oil_barrel", "military_crate", "fire_extinguisher", "sandbags", "lamp_cage"],
	"intro": ["apartment_block", "bus_stop", "bench", "trash_bin", "car_sedan", "utility_pole", "street_lamp", "tree_leafy",
		"house_small", "oil_barrel", "military_crate", "concrete_barrier", "car_wreck", "lamp_cage", "metal_shelf",
		"fire_extinguisher", "vault_door", "factory_hall", "warehouse", "concrete_fence", "water_tower", "tire_pile",
		"burnt_truck", "scrap_pile",
		"civ_coat", "civ_fuse", "civ_woman", "enemy_bandit", "car_volga", "car_lada", "grass_green", "fps_pistol"],
	"bunker": ["vault_door", "locker", "sandbags", "fire_extinguisher", "bunk_bed", "table_metal", "chair", "canned_food",
		"water_jug", "radio_station", "workbench", "crt_computer", "sofa_old", "metal_shelf", "wooden_crate", "military_crate",
		"jerrycan", "first_aid_kit", "oil_barrel", "diesel_generator", "electrical_panel", "water_tank", "water_purifier",
		"air_filter_unit", "toolbox", "planter_box", "lamp_cage", "bucket", "car_battery", "fridge_old", "rubble_pile",
		"plant_tomato", "plant_lettuce", "plant_pepper", "mushrooms",
		"fps_pistol", "fluoro_lights", "duct_straight", "cable_run", "fire_alarm", "utility_box", "security_cam", "pipe_fitting", "water_bottle_m", "bandage_roll"],
	"surface": ["ruined_building", "car_wreck", "bus_wreck", "rubble_pile", "tree_dead", "utility_pole", "concrete_barrier",
		"wooden_crate", "military_crate", "metal_shelf", "locker", "oil_barrel", "first_aid_kit", "toolbox", "supermarket_shelf",
		"tank_wreck", "sandbags", "enemy_mutant", "enemy_hazmat", "enemy_dog", "enemy_bandit", "survivor_npc", "weapon_axe",
		"weapon_pistol", "weapon_rifle", "ruin_wall_a", "ruin_wall_b", "ruin_house", "ruin_block", "debris_slab", "tire_pile",
		"scrap_pile", "road_sign", "radiation_sign", "burnt_truck", "shop_ruin", "enemy_zombie", "fps_pistol", "fps_rifle",
		"fps_shotgun", "tree_dead_b", "rock_a", "rock_b", "stone_small", "boulder", "log_fallen", "tree_stump", "branches_dry",
		"vault_door", "lamp_cage", "radio_antenna", "jerrycan", "apartment_block",
		"grass_dry", "bed_old", "wardrobe_old", "table_wood", "bathtub_old", "sink_old", "toilet", "stove_electric", "cabinet_tall_b", "drawer_cabinet", "nightstand", "nightstand_b", "dresser_old", "hospital_bed", "bookshelf_worn", "books_set", "tv_old", "masonry_heater", "office_desk", "suitcase", "backpack_old", "display_fridge", "drill_press", "chair_wood", "chair_dining", "jug", "pot_enamel", "food_cans", "kettle", "cash_register", "fluoro_lights", "lamp_pendant", "chandelier", "wall_clock", "picture_frame", "picture_frame_b", "mirror", "potted_plant", "cardboard_box", "plastic_crate", "water_bottle_m", "bandage_roll", "canned_food"],
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
	var p := player
	if p and is_instance_valid(p):
		p.can_move = false
		var bed: Node3D = p.interaction_target() if p.has_method("interaction_target") else null
		p.lie_down(true, 1.0, bed)
		await get_tree().create_timer(1.3 if bed else 0.5).timeout
	await HUD.fade_to(1.0, 0.9)
	State.simulate(hours * 60.0, true)
	State.save_game()
	await get_tree().create_timer(0.6).timeout
	State.running = not State.dead
	_busy = false
	HUD.toast("Ai dormit %d ore. Joc salvat." % roundi(hours), "good")
	if p and is_instance_valid(p):
		p.lie_down(false, 1.1)
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.can_move = true)
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
	if args.has("cam"):
		# fixed review camera (screenshots): --cam=x,y,z,yaw_deg,pitch_deg
		var c: PackedStringArray = String(args.cam).split(",")
		var cam := Camera3D.new()
		cam.far = 2000.0
		p.get_parent().add_child.call_deferred(cam)
		cam.position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.rotation = Vector3(deg_to_rad(float(c[4]) if c.size() > 4 else -30.0), deg_to_rad(float(c[3]) if c.size() > 3 else 0.0), 0)
		cam.ready.connect(cam.make_current)


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
	State.corbii_tick()


# --------------------------------------------------------------------------
# Debug helpers
# --------------------------------------------------------------------------

func _debug_boot() -> void:
	var s: String = args.scene
	State.reset()
	if args.has("day"):
		State.day = int(args.day)
	if args.has("scene") or args.has("selftest"):
		State.save_path = "user://debug_slot.json"  # never touch the real save from a test run
	if args.has("flags"):  # --flags=corbii:threat,corbii_deadline:17
		for kv in String(args.flags).split(","):
			var p := kv.split(":")
			if p.size() == 2:
				State.flags[p[0]] = int(p[1]) if p[1].is_valid_int() else p[1]
	match s:
		"intro":
			State.context = "intro"
		"bunker":
			State.context = "bunker"
			State.minute = 9.0 * 60.0
			if args.has("lit"):
				State.flags["tut"] = 6
				State.generator_on = true
			if args.get("showcase", "") == "lights":
				# every light type around the main hall (south wall, east wall, ceiling, floor, table)
				for e in [["string_lights", Vector3(3.2, 2.25, 5.0), PI], ["sconce", Vector3(-2.4, 1.95, 5.0), PI],
						["bulkhead", Vector3(5.8, 2.0, 5.0), PI], ["beacon", Vector3(7.0, 2.3, 3.4), -PI * 0.5],
						["fluoro", Vector3(-3.5, 3.2, 0.4), PI * 0.5], ["floor_lamp", Vector3(1.55, 0.0, 4.45), 0.0],
						["work_light", Vector3(-4.2, 0.0, 2.6), PI * 0.75], ["lantern", Vector3(0.95, 0.63, 0.45), 0.0]]:
					State.built.append({"type": e[0], "p": [e[1].x, e[1].y, e[1].z], "r": e[2]})
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
	if args.has("build"):
		get_tree().create_timer(6.0, true, false, true).timeout.connect(func() -> void: start_build(String(args.build)))
	if args.has("move"):
		get_tree().create_timer(6.0, true, false, true).timeout.connect(func() -> void: level.start_move(String(args.move)))
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
		"light":
			var best: DecoLight = null
			for d in level.deco_lights:
				if best == null or d.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
					best = d
			if best:
				HUD.open_panel(LightPanel.new(best))


func _schedule_debug() -> void:
	if args.has("shots"):
		for t in String(args.shots).split(","):
			get_tree().create_timer(float(t), true, false, true).timeout.connect(_shot.bind(t))
	if args.has("quit"):
		get_tree().create_timer(float(args.quit), true, false, true).timeout.connect(get_tree().quit)
	if args.has("swingseq"):
		get_tree().create_timer(float(args.get("seqat", "10")), true, false, true).timeout.connect(_swing_sheet)
	if args.has("act"):
		for a in String(args.act).split(","):
			var parts := a.split("@")
			if parts.size() == 2:
				get_tree().create_timer(float(parts[1]), true, false, true).timeout.connect(_debug_act.bind(parts[0]))


## Drives the inventory with synthesized mouse events: stash -> equipment slot,
## then the slot -> DEPOZIT tab. Prints the counts after each drop.
func _drag_test() -> void:
	var pnl := HUD.top_panel() as InventoryPanel
	if pnl == null:
		print("[dragtest] no inventory panel open")
		return
	State.add("gas_mask", 1, true, true)
	State.remove("gas_mask", State.count("gas_mask"))
	pnl.view = "stash"
	pnl.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var from := pnl.find_cell("gas_mask", false)
	var to := pnl.find_cell("gas_mask", true)
	if from == null or to == null:
		print("[dragtest] cells not found: ", from, " ", to)
		return
	await _drag(from.global_position + from.size * 0.5, to.global_position + to.size * 0.5)
	print("[dragtest] stash->equip: pack=%d stash=%d" % [State.count("gas_mask"), State.stash_count("gas_mask")])
	await get_tree().process_frame
	to = pnl.find_cell("gas_mask", true)
	var tab: Control = null
	for c in pnl.tabs.get_children():
		if c is InventoryPanel.DropTab and c.target == "stash":
			tab = c
	if to == null or tab == null:
		print("[dragtest] equip cell or tab missing")
		return
	await _drag(to.global_position + to.size * 0.5, tab.global_position + tab.size * 0.5)
	print("[dragtest] equip->stash tab: pack=%d stash=%d" % [State.count("gas_mask"), State.stash_count("gas_mask")])


func _drag(a: Vector2, b: Vector2) -> void:
	# control positions are canvas coordinates; injected events are window coordinates
	var xf := get_tree().root.get_final_transform()
	a = xf * a
	b = xf * b
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	Input.parse_input_event(down)
	await get_tree().process_frame
	for i in 14:
		var m := InputEventMouseMotion.new()
		var p := a.lerp(b, (i + 1) / 14.0)
		m.position = p
		m.global_position = p
		m.relative = (b - a) / 14.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _collect_lights(n: Node, acc: Array[Light3D]) -> void:
	if n is Light3D:
		acc.append(n)
	for c in n.get_children():
		_collect_lights(c, acc)


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
		"reach":
			p.weapons.reach_pulse(3.0)
		"hands":
			p.weapons.switch("hands")
		"sleep":
			# debug: lie on the nearest bed (in play the bed is the one E was pressed on)
			var best: Node3D = null
			for n in get_tree().current_scene.find_children("*", "Interactable", true, false):
				var it := n as Interactable
				if it and it.get_prompt().contains("Dormi") and (best == null or it.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
					best = it
			if best:
				p._last_used = best
			sleep(float(args.get("sleeph", "8")))
		"dragtest":
			_drag_test()
		"facecont":  # stand 1.7 m in front of the first container that has moving parts
			if level and "buildings" in level:
				for b in level.buildings:
					for c in b.containers:
						if not is_instance_valid(c):
							continue
						if args.has("face"):
							if not String(c.title).begins_with(String(args.face)):
								continue
						elif c.openers.is_empty():
							continue
						if true:
							var f: Vector3 = c.global_basis.z.normalized()
							p.global_position = c.global_position + f * 1.7 + Vector3(0, 0.1, 0)
							var to := -f
							p.rotation.y = atan2(-to.x, -to.z)
							p.head.rotation.x = -0.2
							print("[facecont] ", c.title, " at ", c.global_position)
							return
		"openall":  # every container of the town swings / slides open (animation check)
			if level and "buildings" in level:
				for b in level.buildings:
					for c in b.containers:
						if is_instance_valid(c):
							c.open_anim()
		"sprint":
			p.set_meta("debug_move", 2)
		"walk":
			p.set_meta("debug_move", 1)
		"stop":
			p.set_meta("debug_move", 0)
		"pos":
			var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.5, p.global_position + Vector3.DOWN * 1.0)
			q.exclude = [p.get_rid()]
			var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
			var under := "%s @%.2f" % [(hit.collider as Node).get_path(), (hit.position as Vector3).y] if not hit.is_empty() else "-"
			var kc: KinematicCollision3D = p.move_and_collide(Vector3.DOWN * 0.1, true)
			if kc:
				under += "  touching=%s n=%s at=%s" % [(kc.get_collider() as Node).get_path(), str(kc.get_normal().snapped(Vector3.ONE * 0.01)), str(kc.get_position().snapped(Vector3.ONE * 0.01))]
			print("[pos] %.2f %.2f %.2f  on_floor=%s  vel=%s paused=%s phys=%d can_move=%s  under=%s" % [p.global_position.x, p.global_position.y, p.global_position.z, p.is_on_floor(),
				str(p.velocity.snapped(Vector3.ONE * 0.01)), get_tree().paused, Engine.get_physics_frames(), p.can_move, under])
		"eat", "drink", "bandage", "soup", "bite", "bread", "potato", "pills":
			# takes the item into the hands; "use" then holds the button --usehold s
			var item := {"eat": "canned_meat", "drink": "water_bottle", "bandage": "bandage", "soup": "mushroom_soup",
				"bite": "tomato", "bread": "crackers", "potato": "potato", "pills": "antirad"}[what] as String
			State.add(item, 1, true)
			p.use_item_animated(item)
		"use":
			p.weapons.debug_hold = float(args.get("usehold", "3"))
		"putaway":
			p.weapons.put_away()
		"fps":
			var vp := get_viewport().get_viewport_rid()
			RenderingServer.viewport_set_measure_render_time(vp, true)
			var lights: Array[Light3D] = []
			_collect_lights(get_tree().current_scene, lights)
			if args.has("noshadow"):
				for l in lights:
					var kind := String(args.noshadow)
					if kind == "all" or (kind == "sun" and l is DirectionalLight3D) or (kind == "omni" and not l is DirectionalLight3D):
						l.shadow_enabled = false
			if args.has("off"):
				var e: Environment = level.env if level else null
				var vpn := get_viewport()
				for o in String(args.off).split(","):
					match o:
						"glow": e.glow_enabled = false
						"glowlite":
							RenderingServer.environment_glow_set_use_bicubic_upscale(false)
							e.set_glow_level(4, 0.0)
							e.set_glow_level(5, 0.0)
						"sky": e.background_mode = Environment.BG_COLOR; e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
						"fog": e.fog_enabled = false
						"vfog": e.volumetric_fog_enabled = false
						"adjust": e.adjustment_enabled = false
						"post": HUD.post.visible = false
						"hud": HUD.root.visible = false
						"aa": vpn.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED; vpn.msaa_3d = Viewport.MSAA_DISABLED; vpn.use_taa = false
						"deband": vpn.use_debanding = false
						"fsr": vpn.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
						"half": vpn.scaling_3d_scale = 0.5
						"full": vpn.scaling_3d_scale = 1.0
						"lights":
							for l in lights:
								if not l is DirectionalLight3D:
									l.visible = false
						"lod4": vpn.mesh_lod_threshold = 4.0
						"lod8": vpn.mesh_lod_threshold = 8.0
						"lod16": vpn.mesh_lod_threshold = 16.0
						"grass":
							for mm in level.find_children("*", "MultiMeshInstance3D", true, false):
								mm.visible = false
						"terrain":
							for mi in level.find_children("Terrain*", "Node3D", true, false):
								mi.visible = false
						"props":
							for mi in level.find_children("*", "MeshInstance3D", true, false):
								if mi.mesh and mi.mesh.resource_path.contains(".glb"):
									mi.visible = false
						"batches":
							for mi in level.find_children("*", "MeshInstance3D", true, false):
								if mi.mesh and mi.mesh.resource_path == "" and mi.material_override != null:
									mi.visible = false
						"range":
							for l in lights:
								if l is OmniLight3D:
									l.omni_range *= 0.7
						"ortho":
							for l in lights:
								if l is DirectionalLight3D:
									l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
									l.directional_shadow_max_distance = 50.0
						"meshstats":
							var per := {}
							for mi in level.find_children("*", "MeshInstance3D", true, false):
								if not mi.is_visible_in_tree() or mi.mesh == null:
									continue
								var tris := 0
								for si in mi.mesh.get_surface_count():
									var arrs: Array = mi.mesh.surface_get_arrays(si)
									var idx = arrs[Mesh.ARRAY_INDEX]
									tris += (idx.size() if idx != null else arrs[Mesh.ARRAY_VERTEX].size()) / 3
								var key: String = mi.mesh.resource_path.get_file() if mi.mesh.resource_path != "" else String(mi.name)
								if mi.get_parent() and mi.mesh.resource_path == "":
									key = mi.get_parent().name + "/" + mi.name
								var ent: Array = per.get_or_add(key, [0, 0, mi.mesh.get_surface_count()])
								ent[0] += 1
								ent[1] += tris
							var rows := per.keys()
							rows.sort_custom(func(a, b) -> bool: return per[a][1] > per[b][1])
							for k in rows.slice(0, 18):
								print("[mesh] %8d tris  x%-3d (%d surf)  %s" % [per[k][1], per[k][0], per[k][2], k])
						"triplanar":
							var seen := {}
							for mi in level.find_children("*", "GeometryInstance3D", true, false):
								var mats: Array = [(mi as GeometryInstance3D).material_override]
								if mi is MeshInstance3D and mi.mesh:
									for si in mi.mesh.get_surface_count():
										mats.append(mi.get_active_material(si))
								if mi is CSGShape3D:
									mats.append(mi.get("material"))
								for m in mats:
									if m is StandardMaterial3D and not seen.has(m):
										seen[m] = true
										m.uv1_triplanar = false
							print("[fps] triplanar off on %d materials" % seen.size())
						"world":
							for c in level.get_children():
								if c is Node3D and not c is Camera3D and not c is Player and not c is Light3D and not c is WorldEnvironment:
									c.visible = false
			var ns := 0
			var nv := 0
			for l in lights:
				if l.shadow_enabled and l.is_visible_in_tree():
					ns += 1
				if l.is_visible_in_tree():
					nv += 1
			print("[fps] lights=%d visible=%d with_shadows=%d  slim: %d -> %d tris in %d ms" % [lights.size(), nv, ns, Assets.slim_stats[0], Assets.slim_stats[1], Assets.slim_stats[2]])
			print("[fps] %d  draw_calls=%d  primitives=%d  proc=%.1fms phys=%.1fms render_cpu=%.1fms render_gpu=%.1fms nodes=%d phys_objs=%d" % [Engine.get_frames_per_second(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(vp),
				RenderingServer.viewport_get_measured_render_time_gpu(vp),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
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


## Debug: one contact sheet of the melee swing at the times in --swingseq=0,0.1,...
func _swing_sheet() -> void:
	var p = player
	if p == null:
		return
	var frames: Array[Image] = []
	p.weapons._swing_side = args.has("swingside")
	for t in String(args.swingseq).split(","):
		args["swingt"] = t
		p.weapons._swing = float(t)
		for i in 4:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2)
		frames.append(img)
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var cols := 3
	var sheet := Image.create(w * cols, h * ceili(frames.size() / float(cols)), false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	var dir: String = args.get("shotdir", "user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	sheet.save_png(dir + "/swing_sheet.png")
	print("[shot] swing sheet ", args.swingseq)


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir: String = args.get("shotdir", "user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s_%s.png" % [dir, args.get("scene", "menu"), tag]
	img.save_png(path)
	print("[shot] ", path)
