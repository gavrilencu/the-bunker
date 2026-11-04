class_name TrafficCar
extends AnimatableBody3D
## A car driving down the main street on the morning of Day Zero. Keeps its lane and a
## safe gap, stops at the red light and for people on the road (with a honk). At the
## siren the drivers panic: some floor it out of town, some brake hard and are left
## slewed across the lane. The flash (EMP) kills every engine: the cars coast to a stop.

enum M { DRIVE, PANIC, ABANDON, DEAD }

## +1 = eastbound (+X, south lane), -1 = westbound
var dir := 1.0
var lane_z := 1.3
var cruise := 11.0
var speed := 0.0
var mode := M.DRIVE
var city: Node
## past this |x| the car reappears at the other end (before the panic) or leaves
var wrap_x := 210.0

var _engine: AudioStreamPlayer3D
var _honked := 0.0
var _abandon_at := -1.0
var _swerve := 0.0
var _t := 0.0


func setup(p_dir: float, x: float, p_city: Node, model_id := "car_sedan") -> TrafficCar:
	dir = p_dir
	lane_z = 1.3 * dir
	city = p_city
	position = Vector3(x, 0.0, lane_z)
	rotation.y = PI * 0.5 if dir > 0.0 else -PI * 0.5
	var m := Assets.model(model_id)
	add_child(m)
	CityLife.paint_car(m, CityLife.CAR_COLORS.pick_random())
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 1.4, 4.2)
	cs.shape = bs
	cs.position.y = 0.7
	add_child(cs)
	cruise = randf_range(9.5, 12.5)
	speed = cruise
	return self


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	_engine = Audio.loop_at("car_engine", self, -6.0, 45.0)
	if _engine:
		_engine.pitch_scale = 0.8


## Front bumper position along the street (x).
func front() -> float:
	return position.x + dir * 2.1


func back() -> float:
	return position.x - dir * 2.1


func panic() -> void:
	if mode != M.DRIVE:
		return
	mode = M.PANIC
	cruise = randf_range(14.0, 18.0)
	_t = 0.0
	# about half the drivers give up a few seconds later and leave the car askew
	if randf() < 0.55:
		_abandon_at = randf_range(1.5, 6.0)
		_swerve = randf_range(-0.5, 0.5)
	_honk()


## The flash fries the electronics: engine off, coast to a stop.
func emp() -> void:
	if mode == M.DEAD:
		return
	mode = M.DEAD
	if _engine:
		_engine.queue_free()
		_engine = null


func _honk() -> void:
	if _honked > 0.0:
		return
	_honked = randf_range(2.5, 4.0)
	Audio.sfx_at("car_horn", global_position + Vector3.UP, -2.0, 55.0, 0.08)


func _physics_process(delta: float) -> void:
	_t += delta
	_honked = maxf(_honked - delta, 0.0)
	var want := cruise
	match mode:
		M.DEAD:
			want = 0.0
		M.ABANDON:
			want = 0.0
		M.PANIC:
			if _abandon_at > 0.0 and _t >= _abandon_at:
				mode = M.ABANDON
				_honk()
	if mode in [M.DRIVE, M.PANIC]:
		# keep a gap to the car in front
		var gap: float = city.gap_ahead(self)
		if gap < 18.0:
			want = minf(want, maxf(gap - 4.0, 0.0) * 1.1)
		# red light
		if mode == M.DRIVE:
			var to_line: float = city.distance_to_stop_line(self)
			if to_line > -0.5 and to_line < 28.0 and city.light_red():
				want = minf(want, maxf(to_line - 0.3, 0.0) * 0.9)
		# people on the road ahead (the player included)
		var obst: float = city.obstacle_ahead(self)
		if obst < 14.0:
			want = minf(want, maxf(obst - 4.5, 0.0) * 1.2)
			if obst < 10.0 and speed > 2.0:
				_honk()
	var accel := 3.0 if want > speed else (11.0 if mode == M.ABANDON else 7.0)
	if mode == M.DEAD:
		accel = 2.2
	speed = move_toward(speed, want, accel * delta)
	position.x += dir * speed * delta
	if mode == M.ABANDON and speed > 0.5:
		# slewing across the lane while braking
		rotation.y = lerp_angle(rotation.y, (PI * 0.5 if dir > 0.0 else -PI * 0.5) + _swerve, delta * 2.0)
		position.z += _swerve * speed * delta * 0.25
	if _engine:
		_engine.pitch_scale = 0.75 + speed / 14.0 * 0.6
		_engine.volume_db = -10.0 + minf(speed, 14.0) * 0.4
	if absf(position.x) > wrap_x and signf(position.x) == dir:
		if mode == M.DRIVE:
			position.x = -dir * wrap_x
			speed = cruise
		else:
			queue_free()
