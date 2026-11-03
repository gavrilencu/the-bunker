extends Node
## Music (crossfaded), ambience layers, 2D and positional one-shots.

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current_id := ""
var _ambient := {}  # layer name -> AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	for i in 12:
		_pool.append(_make_player("SFX"))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# ---------------- Music ----------------

func play_music(id: String, fade := 2.5, volume_db := 0.0) -> void:
	if id == _music_current_id:
		return
	_music_current_id = id
	var old := _music_a if _music_a.playing else _music_b
	var nxt := _music_b if old == _music_a else _music_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if id == "":
		return
	var st := Assets.looped(Assets.sound(id))
	if st == null:
		return
	nxt.stream = st
	nxt.volume_db = -60.0
	nxt.play()
	create_tween().tween_property(nxt, "volume_db", volume_db, fade)


func stop_music(fade := 2.0) -> void:
	play_music("", fade)


# ---------------- Ambience ----------------

## Starts/replaces a looping ambience layer. id "" stops the layer.
func ambient(layer: String, id: String, volume_db := 0.0, fade := 2.0) -> void:
	var p: AudioStreamPlayer = _ambient.get(layer)
	if p and p.has_meta("id") and p.get_meta("id") == id and p.playing:
		create_tween().tween_property(p, "volume_db", volume_db, fade)
		return
	if p:
		var oldp := p
		var tw := create_tween()
		tw.tween_property(oldp, "volume_db", -60.0, fade)
		tw.tween_callback(oldp.queue_free)
		_ambient.erase(layer)
	if id == "":
		return
	var st := Assets.looped(Assets.sound(id))
	if st == null:
		return
	var np := _make_player("Ambient")
	np.stream = st
	np.volume_db = -60.0
	np.set_meta("id", id)
	np.play()
	_ambient[layer] = np
	create_tween().tween_property(np, "volume_db", volume_db, fade)


func ambient_volume(layer: String, volume_db: float, fade := 1.0) -> void:
	var p: AudioStreamPlayer = _ambient.get(layer)
	if p:
		create_tween().tween_property(p, "volume_db", volume_db, fade)


func stop_all_ambient(fade := 1.5) -> void:
	for layer in _ambient.keys():
		ambient(layer, "", 0.0, fade)


# ---------------- One-shots ----------------

func sfx(id: String, volume_db := 0.0, pitch_var := 0.06, bus := "SFX") -> AudioStreamPlayer:
	var st := Assets.sound(id)
	if st == null:
		return null
	var p: AudioStreamPlayer = null
	for c in _pool:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _make_player("SFX")
		_pool.append(p)
	p.bus = bus
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
	return p


func ui(id := "ui_click") -> void:
	sfx(id, -6.0, 0.03, "UI")


## Positional one-shot. Parented to the current scene so it dies with it.
func sfx_at(id: String, pos: Vector3, volume_db := 0.0, max_dist := 40.0, pitch_var := 0.06) -> AudioStreamPlayer3D:
	var st := Assets.sound(id)
	var scene := get_tree().current_scene
	if st == null or scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = st
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.unit_size = 6.0
	p.attenuation_filter_cutoff_hz = 9000.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Looping positional emitter attached to `parent` (e.g. generator hum).
func loop_at(id: String, parent: Node3D, volume_db := 0.0, max_dist := 20.0) -> AudioStreamPlayer3D:
	var st := Assets.looped(Assets.sound(id))
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.stream = st
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.unit_size = 4.0
	parent.add_child(p)
	p.play()
	return p
