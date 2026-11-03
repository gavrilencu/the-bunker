class_name IconFactory
extends RefCounted
## Renders inventory icons from the real 3D models (studio-lit, transparent),
## one per frame pair, cached for the session. Items without a model use vector icons.

const ITEM_MODELS := {
	"canned_meat": "canned_food", "canned_beans": "canned_food", "tomato": "plant_tomato", "lettuce": "plant_lettuce",
	"mushroom": "mushrooms", "water_bottle": "water_jug", "dirty_water": "bucket", "medkit": "first_aid_kit",
	"bandage": "first_aid_kit", "fuel_can": "jerrycan", "gas_mask": "gas_mask", "shovel": "shovel", "flashlight": "flashlight",
	"geiger": "geiger_counter", "axe": "weapon_axe", "pistol": "weapon_pistol", "rifle": "weapon_rifle", "shotgun": "weapon_saiga",
	"wood": "wooden_crate", "soil": "bucket",
	"battery_cell": "car_battery", "air_filter": "air_filter_unit", "scrap": "scrap_pile", "electronics": "crt_computer",
	"plastic": "water_jug", "pipe": "oil_barrel", "seed_potato": "plant_pepper", "seeds_tomato": "plant_tomato",
	"seeds_lettuce": "plant_lettuce", "spores_mushroom": "mushrooms",
}

static var _cache := {}
static var _queue: Array = []
static var _busy := false


## Returns the icon if ready (else null and schedules a render).
static func get_icon(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var mid: String = ITEM_MODELS.get(item_id, "")
	if mid == "" or not Assets.has_model(mid):
		_cache[item_id] = null
		return null
	if not _queue.has(item_id):
		_queue.append(item_id)
		_pump()
	return null


static func warm_up(ids: Array) -> void:
	for id in ids:
		get_icon(id)


static func _pump() -> void:
	if _busy:
		return
	_busy = true
	_run()


static func _run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		if _cache.has(id):
			continue
		var tex := await _render(tree, ITEM_MODELS[id])
		_cache[id] = tex
	_busy = false


static func _render(tree: SceneTree, model_id: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 192)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 2.2
	key.light_color = Color(1.0, 0.94, 0.86)
	key.rotation_degrees = Vector3(-40, 35, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.4
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.rotation_degrees = Vector3(-15, 200, 0)
	vp.add_child(rim)
	var m := Assets.model(model_id)
	vp.add_child(m)
	var aabb := Assets.model_aabb(m)
	var c := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.01)
	var cam := Camera3D.new()
	cam.fov = 28.0
	var dir := Vector3(1.0, 0.62, 1.35).normalized()
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	cam.near = maxf(dist * 0.02, 0.005)
	cam.far = dist * 4.0
	vp.add_child(cam)
	HUD.add_child(vp)
	cam.look_at_from_position(c + dir * dist, c, Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return ImageTexture.create_from_image(img)
