class_name Pedestrian
extends AnimatableBody3D
## Townsperson for the morning of Day Zero. Strolls a route (ping-pong or loop), waits,
## crosses at the zebra when the cars have red; at the alert stops and stares, at the
## siren runs to a shelter point and disappears inside.

enum M { WALK, WAIT, CROSS, STARTLED, RUN, GONE }

var route: Array[Vector3] = []
var loop := false
## stands still (bus stop, shop window) until the panic
var idler := false
## waits at the zebra until the city says the cars have red, then walks `route`
var crosser := false
var speed := 1.3
## waypoints of the run for cover (last one = the door they disappear into)
var flee_path: Array[Vector3] = []
var mode := M.WALK
var city: Node

var _i := 1
var _dir := 1
var _model: Node3D
var _ap: AnimationPlayer
var _anims := {}
const CIVILIANS := ["civ_coat", "civ_fuse", "civ_woman"]
var _t := 0.0
var _pause := 0.0
var _run_speed := 4.4


func setup(p_route: Array[Vector3], p_speed: float, p_city: Node) -> Pedestrian:
	route = p_route
	speed = p_speed
	city = p_city
	return self


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.72
	cs.shape = cap
	cs.position.y = 0.86
	add_child(cs)
	# realistic townspeople (Mixamo-rigged scans/characters); their idle, walk and run
	# clips are retargeted from the bandit's Mixamo set. Falls back to the old low-poly man.
	var pool: Array = []
	for id in CIVILIANS:
		if Assets.has_model(id):
			pool.append(id)
	var real := not pool.is_empty()
	_model = Assets.model(pool.pick_random() if real else "survivor_npc")
	add_child(_model)
	_model.scale = Vector3.ONE * randf_range(0.95, 1.04)
	if not real:
		CityLife.dress(_model)
	Assets.for_each_geometry(_model, func(g: GeometryInstance3D) -> void:
		g.visibility_range_end = 90.0)
	_ap = Assets.find_animation_player(_model)
	if _ap and real:
		var got := AnimRetarget.import_anims(_model, _ap, "enemy_bandit", {"idle": "Idle (3)", "walk": "Walking (5)", "run": "Running (1)"})
		for k in got:
			var a := _ap.get_animation(got[k])
			a.loop_mode = Animation.LOOP_LINEAR
			_strip_root_motion(a)
			_anims[k] = got[k]
	elif _ap:
		for k in ["idle", "walk", "run", "death"]:
			if _ap.has_animation(k):
				var a := _ap.get_animation(k)
				if k != "death":
					a.loop_mode = Animation.LOOP_LINEAR
					_strip_root_motion(a)
				_anims[k] = k
	_run_speed = randf_range(3.8, 5.0)
	if route.is_empty():
		route = [global_position]
	global_position = route[0]
	if idler or crosser or route.size() < 2:
		mode = M.WAIT
		_play("idle", randf_range(0.8, 1.1))
		if _ap:
			_ap.seek(randf() * 2.0, true)
	else:
		_i = 1
		_play("walk", speed / 1.35)
		if _ap:
			_ap.seek(randf() * 1.0, true)
		_face(route[1] - route[0], 1.0)


## Locks the hip translation on X/Z so clips play in place (the body itself moves).
static func _strip_root_motion(a: Animation) -> void:
	if a.has_meta("in_place"):
		return
	a.set_meta("in_place", true)
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(a.track_get_path(t)).to_lower()
		if not (path.contains("hips") or path.contains("pelvis") or path.contains("root")):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var p0: Vector3 = a.track_get_key_value(t, 0)
		for i in n:
			var p: Vector3 = a.track_get_key_value(t, i)
			a.track_set_key_value(t, i, Vector3(p0.x, p.y, p0.z))
		break


func _play(k: String, spd := 1.0, blend := 0.3) -> void:
	if _ap == null or not _anims.has(k):
		return
	var n: String = _anims[k]
	if _ap.current_animation != n:
		_ap.play(n, blend, spd)
	else:
		_ap.speed_scale = spd


func _face(dir: Vector3, w: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), w)


## Alert on the phones: everyone stops and stares for a moment.
func alert() -> void:
	if mode in [M.GONE, M.RUN]:
		return
	mode = M.STARTLED
	_t = randf_range(1.0, 2.6)
	_play("idle", 1.0, 0.4)


## Siren: run for the nearest door along `path`.
func panic(path: Array[Vector3]) -> void:
	if mode == M.GONE:
		return
	flee_path = path
	mode = M.STARTLED
	_t = minf(_t, randf_range(0.1, 0.9)) if _t > 0.0 else randf_range(0.1, 0.9)
	set_meta("panicking", true)


func _physics_process(delta: float) -> void:
	match mode:
		M.WAIT:
			if crosser and city and city.walk_signal():
				crosser = false
				mode = M.WALK
				_i = 1
				_play("walk", speed / 1.35)
		M.WALK:
			_walk(delta)
		M.STARTLED:
			_t -= delta
			if _t <= 0.0:
				if has_meta("panicking"):
					mode = M.RUN
					_play("run", _run_speed / 4.4, 0.2)
				else:
					mode = M.WALK if not idler and route.size() > 1 else M.WAIT
					if mode == M.WALK:
						_play("walk", speed / 1.35)
		M.RUN:
			if flee_path.is_empty():
				mode = M.GONE
				visible = false
				collision_layer = 0
				set_physics_process(false)
				if _ap:
					_ap.pause()  # a hidden skeleton still costs a skin update every frame
				return
			var d := flee_path[0] - global_position
			d.y = 0.0
			if d.length() < 0.5:
				flee_path.remove_at(0)
				return
			_step_toward(flee_path[0], _run_speed, delta)


func _walk(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_play("walk", speed / 1.35)
		return
	var target := route[_i]
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.25:
		if loop:
			_i = (_i + 1) % route.size()
		else:
			if _i + _dir >= route.size() or _i + _dir < 0:
				_dir = -_dir
				# turn around: a short look at a shop window / the street
				if randf() < 0.5:
					_pause = randf_range(1.0, 3.0)
					_play("idle", 1.0)
			_i += _dir
		return
	# give way to the player instead of walking through him
	var p = Game.player
	if p and is_instance_valid(p):
		var to_p: Vector3 = p.global_position - global_position
		to_p.y = 0.0
		if to_p.length() < 1.1 and to_p.dot(d.normalized()) > 0.2:
			_play("idle", 1.0)
			_pause = 0.6
			return
	_step_toward(target, speed, delta)


func _step_toward(target: Vector3, spd: float, delta: float) -> void:
	var d := target - global_position
	var flat := Vector3(d.x, 0.0, d.z)
	var dist := flat.length()
	if dist < 0.001:
		return
	var step := minf(spd * delta, dist)
	var np := global_position + flat / dist * step
	# follow sidewalks / steps: interpolate height toward the waypoint
	np.y = lerpf(global_position.y, target.y, minf(step / maxf(dist, 0.01), 1.0))
	global_position = np
	_face(flat, minf(delta * 8.0, 1.0))
