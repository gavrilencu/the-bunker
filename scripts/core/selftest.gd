class_name SelfTest
extends RefCounted
## Automated smoke test of the gameplay loop. Run with:
##   Godot --path . -- --scene=bunker --lit --selftest --windowed --nolook
## Prints "[selftest] ..." lines; script errors show up in the log.

## Intro: mode "door" = reach the airlock and seal it; "die" = stay outside.
static func run_intro(tree: SceneTree, mode: String) -> void:
	var say := func(msg: String) -> void: print("[selftest] ", msg)
	await tree.create_timer(2.5).timeout
	var lvl = Game.level
	say.call("intro t=%.1f mode=%s" % [lvl.t, mode])
	if mode == "door":
		Game.player.global_position = Vector3(75.0, -5.9, -72.5)
		await tree.create_timer(0.5).timeout
		lvl._close_door()
		await tree.create_timer(4.0).timeout
		say.call("door_closed=%s impact_at=%.1f t=%.1f" % [lvl.door_closed, lvl._impact_at, lvl.t])
		for i in 40:
			await tree.create_timer(1.0).timeout
			if Game.level and Game.level.name == "Bunker":
				break
		say.call("now in %s, day=%d, intro_done=%s" % [Game.level.name if Game.level else "?", State.day, State.flags.get("intro_done", false)])
	else:
		for i in 30:
			await tree.create_timer(1.0).timeout
			if HUD.top_panel() is DeathPanel:
				break
		say.call("flashed=%s shock=%s dead=%s panel=%s" % [lvl.flashed, lvl.shock_arrived, State.dead, HUD.top_panel()])
	say.call("DONE")
	tree.quit()


static func run(tree: SceneTree) -> void:
	var say := func(msg: String) -> void: print("[selftest] ", msg)
	await tree.create_timer(2.0).timeout
	var lvl = Game.level
	say.call("level=%s" % lvl.name)
	# every doorway must let a player-sized box through
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.5, 0.7)
	q.shape = box
	q.collision_mask = 1
	var doors: Array = lvl.DOORS.duplicate()
	var blocked := 0
	for d in doors:
		var c := Vector3(d.get_center().x, 0.85, d.get_center().y)
		var along := Vector3(1, 0, 0) if d.size.x < d.size.y else Vector3(0, 0, 1)
		for k in range(-6, 7):
			q.transform = Transform3D(Basis(), c + along * (k * 0.25))
			for h in space.intersect_shape(q, 4):
				if h.collider != lvl.csg:
					blocked += 1
					say.call("BLOCKED door %s at %s by %s" % [str(d), str(q.transform.origin), h.collider.get_parent().name if h.collider.get_parent() else h.collider.name])
	say.call("doorways checked: %d, blocked samples: %d" % [doors.size(), blocked])
	for id in ItemDB.ITEMS:
		State.add(id, 6, true)

	# panels
	for p in [InventoryPanel.new(), CraftPanel.new(), BuildPanel.new(), MapPanel.new(), RadioPanel.new(),
			SettingsPanel.new(), PauseMenu.new(), ControlsPanel.new(), CreditsPanel.new()]:
		HUD.open_panel(p)
		await tree.process_frame
		await tree.process_frame
		say.call("opened %s" % p.get_script().get_global_name())
		HUD.close_panel(p)
	# crafting
	var cp := CraftPanel.new()
	HUD.open_panel(cp)
	await tree.process_frame
	for r in ItemDB.RECIPES:
		cp._craft(r)
	HUD.close_panel(cp)
	say.call("crafted all, day=%d %s" % [State.day, State.clock_text()])

	# station menus
	for fn in ["_gen_menu", "_panel_info", "_tank_menu", "_purifier_menu", "_air_menu", "_sleep_menu", "_terminal", "_radio_use", "_door_use"]:
		lvl.call(fn)
		await tree.process_frame
		HUD.close_all_panels()
	say.call("station menus ok")

	# farming
	var pl: Planter = lvl.planter_nodes[0]
	pl._plant("seeds_tomato", "tomato")
	State.generator_on = true
	for i in 8:
		pl.data()["water"] = 100.0
		State.simulate(10.0 * 60.0, false)
		State.food = 90.0
		State.hydration = 90.0
		State.energy = 90.0
	say.call("tomato growth=%.2f" % float(pl.data().growth))
	pl._refresh_visual()
	pl._on_used(null)
	say.call("harvest -> tomatoes=%d" % State.count("tomato"))
	var mush: Planter = lvl.planter_nodes[3]
	mush._plant("spores_mushroom", "mushroom")
	say.call("mushroom planted in %s" % mush.bed)

	# build every buildable
	var x := -5.0
	for type in ItemDB.BUILDABLES:
		State.built.append({"type": type, "p": [x, 0.0, 3.6], "r": 0.0})
		lvl._spawn_built_one(State.built.size() - 1)
		x += 1.1
	lvl._update_lit()
	lvl.start_build("planter")
	await tree.process_frame
	lvl._update_ghost()
	lvl.cancel_build()
	say.call("built %d objects" % State.built.size())
	var before := State.stash_count("wood")
	lvl.demolish(0)
	await tree.process_frame
	say.call("demolished #0 -> %s, wood refund %d" % [State.built[0].type, State.stash_count("wood") - before])

	# upgrades
	for id in ItemDB.UPGRADES:
		for k in ItemDB.UPGRADES[id].cost:
			State.add(k, 10, true, true)
	var fuel0 := State.fuel_rate()
	var bought := 0
	for pass_i in 3:
		for id in ItemDB.UPGRADES:
			if State.buy_upgrade(id):
				bought += 1
				lvl.on_upgrade(id)
	say.call("upgrades bought %d/%d (blocked by digs ok), fuel %.2f -> %.2f L/h, carry %d, battery %d" % [bought, ItemDB.UPGRADES.size(), fuel0, State.fuel_rate(), int(State.carry_max), int(State.battery_max)])
	say.call("locations now: %s" % str(State.available_locations()))
	for pnl in [TechPanel.new(), MapPanel.new(), LocalMapPanel.new(lvl), CraftPanel.new("stove")]:
		HUD.open_panel(pnl)
		for i in 5:
			await tree.process_frame
		say.call("opened %s" % pnl.get_script().get_global_name())
		HUD.close_panel(pnl)

	# digging
	for site in tree.get_nodes_in_group("_none"):
		pass
	var sites: Array = []
	for c in lvl.get_children():
		if c is DigSite:
			sites.append(c)
	for s in sites:
		for i in 3:
			State.energy = 90.0
			if is_instance_valid(s):
				s._on_used(null)
		await tree.process_frame
	say.call("dug %d sites, open rooms=%s" % [sites.size(), str(lvl.open_rooms)])

	# items
	for id in ["canned_meat", "water_bottle", "bandage", "antirad", "fuel_can"]:
		State.use_item(id)
	# save / load
	var ok := State.save_game()
	var d := State.to_dict()
	var ok2 := State.load_game()
	say.call("save=%s load=%s day=%d inv=%d" % [ok, ok2, State.day, State.inventory.size()])
	State.from_dict(d)

	# sleep
	await Game.sleep(3.0)
	await tree.create_timer(2.5).timeout
	say.call("slept -> %s" % State.clock_text())

	# expedition
	State.add("gas_mask", 1, true)
	State.add("mask_filter", 2, true)
	Game.start_expedition("market")
	for i in 40:
		await tree.create_timer(0.5).timeout
		if Game.level and Game.level.name == "Expedition" and not Game._busy:
			break
	await tree.create_timer(1.0).timeout
	var ex = Game.level
	say.call("expedition level=%s enemies=%d" % [ex.name, ex.enemies.size()])
	var searched := 0
	for c in ex.get_children():
		if c is LootContainer and searched < 5:
			c._on_used(null)
			searched += 1
	var p: Player = Game.player
	for wid in ["pistol", "rifle", "shotgun", "axe"]:
		State.add(wid, 1, true)
		p.equip(wid)
		await tree.create_timer(0.6).timeout
		State.flags["mag_" + wid] = 8
		if p.weapons.is_gun():
			p.weapons._fire()
			p.weapons.reload()
		else:
			p.weapons._start_swing()
		await tree.create_timer(0.5).timeout
		say.call("weapon %s ok (mag %d)" % [wid, p.weapons.mag()])
	if not ex.enemies.is_empty():
		var e: Enemy = ex.enemies[0]
		e.global_position = p.global_position + Vector3(0, 0, -1.5)
		await tree.create_timer(1.5).timeout
		e.take_hit(500.0, p.global_position, e.global_position + Vector3.UP * 1.3, Vector3(0, 0, -2.0))
		await tree.create_timer(1.0).timeout
		say.call("enemy %s dead, ragdoll=%s" % [e.kind, e._ragdoll != null])
	say.call("terrain h(0,0)=%.2f portal=%s" % [ex.terrain.height_at(0, 0), ex.portal != null])
	await tree.create_timer(1.0).timeout
	say.call("after combat hp=%.0f kills=%d rad=%.1f" % [State.health, int(State.stats.kills), State.radiation])
	ex.portal._use()
	for i in 40:
		await tree.create_timer(0.5).timeout
		if Game.level and Game.level.name == "Bunker" and not Game._busy:
			break
	say.call("back in %s, expeditions=%d" % [Game.level.name, int(State.stats.expeditions)])
	say.call("DONE")
	tree.quit()
