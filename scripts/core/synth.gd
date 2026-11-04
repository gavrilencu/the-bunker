class_name Synth
extends RefCounted
## Procedural fallback sounds, used only when no recorded asset exists for an id.

const RATE := 22050


static func make(id: String) -> AudioStreamWAV:
	var base := id
	# strip variant suffix (_1.._9)
	var re := RegEx.create_from_string("_[0-9]$")
	base = re.sub(base, "")
	match base:
		"siren_air_raid": return _siren(24.0)
		"explosion_nuclear": return _explosion(12.0, 1.0)
		"shockwave_wind": return _wind(7.0, 1.0, true)
		"door_vault_close": return _vault_door()
		"metal_impact": return _metal(1.4)
		"footstep_concrete": return _step(0.18, 2200.0)
		"footstep_grass": return _step(0.22, 4200.0)
		"ambient_bunker": return _hum(10.0)
		"ambient_wasteland": return _wind(12.0, 0.45, false)
		"ambient_morning": return _birds(12.0)
		"generator_loop": return _engine(4.0)
		"car_engine": return _car_engine(3.0)
		"car_horn": return _horn(0.55)
		"city_traffic": return _traffic(14.0)
		"radio_static": return _static(6.0)
		"geiger_click": return _click(0.012, 1.0)
		"ui_click": return _click(0.05, 0.5)
		"ui_hover": return _click(0.03, 0.18)
		"pickup": return _noise_burst(0.18, 0.5, 5000.0)
		"eat": return _noise_burst(0.35, 0.35, 1500.0)
		"drink": return _noise_burst(0.4, 0.3, 900.0)
		"craft": return _hammer()
		"dig": return _noise_burst(0.5, 0.7, 700.0)
		"gunshot_pistol": return _gunshot(0.6, 1.0)
		"gunshot_rifle": return _gunshot(0.9, 1.3)
		"reload": return _reload()
		"melee_swing": return _whoosh(0.35)
		"melee_hit": return _thud(0.3)
		"creature_growl": return _growl(1.6, 70.0)
		"creature_attack": return _growl(0.9, 160.0)
		"heartbeat": return _heartbeat()
		"water_pour": return _noise_burst(1.2, 0.35, 2500.0)
		"gasmask_breath": return _breath(4.0)
		"power_down": return _sweep(1.0, 400.0, 40.0)
		"power_up": return _sweep(1.2, 60.0, 520.0)
		"music_menu", "music_bunker", "music_tension": return _drone(20.0, base)
	return null


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a


static func _siren(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var phase := 0.0
	var n := s.size()
	for i in n:
		var t := float(i) / RATE
		var cyc := fmod(t, 12.0) / 12.0
		var f := 260.0 + 460.0 * (0.5 - 0.5 * cos(cyc * TAU))
		phase += f / RATE
		var v := tanh(2.4 * sin(phase * TAU)) * 0.55 + sin(phase * TAU * 2.0) * 0.12
		var env := minf(t / 1.5, 1.0) * minf((sec - t) / 1.5, 1.0)
		s[i] = v * env * 0.7
	return _to_wav(s)


static func _explosion(sec: float, amp: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var lp2 := 0.0
	var n := s.size()
	for i in n:
		var t := float(i) / RATE
		var env := (1.0 - exp(-t * 30.0)) * exp(-t * 0.35)
		var cutoff := lerpf(0.25, 0.015, minf(t / 4.0, 1.0))
		lp += (randf_range(-1, 1) - lp) * cutoff
		lp2 += (lp - lp2) * cutoff
		var rumble := sin(TAU * 34.0 * t + sin(t * 3.0) * 2.0) * 0.5 * exp(-t * 0.25)
		var crackle := (randf_range(-1, 1) if randf() < 0.002 * exp(-t * 0.4) else 0.0) * 0.6
		s[i] = (lp2 * 5.0 + rumble + crackle) * env * amp * 0.8
	return _to_wav(s)


static func _wind(sec: float, amp: float, swell: bool) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var bp := 0.0
	var n := s.size()
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(t * 0.9) * sin(t * 0.37 + 1.0)
		var c := 0.02 + 0.06 * lfo
		lp += (randf_range(-1, 1) - lp) * c
		bp += (lp - bp) * 0.5
		var env := 1.0
		if swell:
			env = minf(t / 1.2, 1.0) * clampf((sec - t) / 3.0, 0.0, 1.0)
		else:
			env = minf(t / 0.5, 1.0) * minf((sec - t) / 0.5, 1.0)
		s[i] = (lp - bp * 0.3) * 6.0 * (0.4 + 0.6 * lfo) * env * amp
	return _to_wav(s)


static func _vault_door() -> AudioStreamWAV:
	var sec := 4.5
	var s := _buf(sec)
	var lp := 0.0
	var n := s.size()
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		if t < 3.2:
			lp += (randf_range(-1, 1) - lp) * 0.05
			var grind := lp * (0.6 + 0.4 * sin(TAU * 7.0 * t)) * minf(t / 0.3, 1.0)
			v += grind * 2.5 + sin(TAU * 55.0 * t) * 0.15
		if t >= 3.2:
			var u := t - 3.2
			var e := exp(-u * 3.0)
			v += (sin(TAU * 58.0 * u) * 0.7 + sin(TAU * 143.0 * u) * 0.35 + sin(TAU * 317.0 * u) * 0.2 + sin(TAU * 611.0 * u) * 0.1) * e
			v += randf_range(-1, 1) * exp(-u * 25.0) * 0.8
		s[i] = v * 0.7
	return _to_wav(s)


static func _metal(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * 420.0 * t) * 0.4 + sin(TAU * 1130.0 * t) * 0.25 + sin(TAU * 2270.0 * t) * 0.15) * exp(-t * 4.0) + randf_range(-1, 1) * exp(-t * 60.0) * 0.4
	return _to_wav(s)


static func _step(sec: float, bright: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var c := bright / RATE
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * c
		s[i] = lp * 2.2 * exp(-t * 28.0) * minf(t * 400.0, 1.0) + sin(TAU * 90.0 * t) * exp(-t * 40.0) * 0.3
	return _to_wav(s)


static func _hum(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var br := 0.0
	for i in s.size():
		var t := float(i) / RATE
		br = (br + randf_range(-1, 1) * 0.02) * 0.995
		s[i] = sin(TAU * 50.0 * t) * 0.12 + sin(TAU * 100.0 * t) * 0.07 + sin(TAU * 150.0 * t) * 0.025 + br * 0.8
	return _to_wav(s)


static func _birds(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var chirps: Array = []
	for k in 26:
		chirps.append([randf_range(0, sec - 0.4), randf_range(2200, 4200), randf_range(0.06, 0.18), randf_range(-1800, 1800)])
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.01
		var v := lp * 0.3
		for c in chirps:
			var u: float = t - c[0]
			if u > 0.0 and u < c[2]:
				var f: float = c[1] + c[3] * (u / c[2])
				v += sin(TAU * f * u) * sin(PI * u / c[2]) * 0.18
		s[i] = v
	return _to_wav(s)


## Petrol engine idling / cruising (loops cleanly: whole cycles of the firing frequency).
static func _car_engine(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var fire := pow(0.5 + 0.5 * sin(TAU * 36.0 * t), 4.0)
		lp += (randf_range(-1, 1) - lp) * 0.05
		lp2 += (lp - lp2) * 0.1
		s[i] = (fire * 0.35 + lp2 * 2.2 * (0.4 + fire) + sin(TAU * 72.0 * t) * 0.08) * 0.55
	return _to_wav(s)


## Two-tone car horn.
static func _horn(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		var v := tanh(3.0 * (sin(TAU * 415.0 * t) + sin(TAU * 523.0 * t) * 0.8))
		var env := minf(t / 0.02, 1.0) * minf((sec - t) / 0.05, 1.0)
		s[i] = v * env * 0.35
	return _to_wav(s)


## Distant city: low traffic rumble with cars swelling past now and then.
static func _traffic(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var lp2 := 0.0
	var passes: Array = []
	for k in 7:
		passes.append([randf_range(0.5, sec - 3.0), randf_range(2.0, 3.5), randf_range(0.5, 1.0)])
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.04
		lp2 += (lp - lp2) * 0.06
		var swell := 0.0
		for p in passes:
			var u: float = (t - p[0]) / p[1]
			if u > 0.0 and u < 1.0:
				swell += sin(PI * u) * sin(PI * u) * p[2]
		var env := minf(t / 1.0, 1.0) * minf((sec - t) / 1.0, 1.0)
		s[i] = lp2 * (1.6 + swell * 2.4) * env + sin(TAU * 55.0 * t) * 0.02 * swell
	return _to_wav(s)


static func _engine(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var fire := pow(0.5 + 0.5 * sin(TAU * 24.0 * t), 6.0)
		lp += (randf_range(-1, 1) - lp) * 0.08
		s[i] = (fire * 0.6 + lp * 1.2 * (0.5 + fire)) * 0.5 + sin(TAU * 48.0 * t) * 0.12
	return _to_wav(s)


static func _static(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	for i in s.size():
		lp += (randf_range(-1, 1) - lp) * 0.45
		var crack := randf_range(-1, 1) * 0.9 if randf() < 0.0015 else 0.0
		s[i] = lp * 0.28 + crack
	return _to_wav(s)


static func _click(sec: float, amp: float) -> AudioStreamWAV:
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (randf_range(-1, 1) * 0.6 + sin(TAU * 1800.0 * t) * 0.4) * exp(-t * 400.0) * amp
	return _to_wav(s)


static func _noise_burst(sec: float, amp: float, bright: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var c := bright / RATE
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * c
		var env := sin(PI * t / sec) * (0.6 + 0.4 * randf())
		s[i] = lp * env * amp * 3.0
	return _to_wav(s)


static func _hammer() -> AudioStreamWAV:
	var sec := 1.4
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for hit in [0.05, 0.5, 0.95]:
			var u: float = t - hit
			if u > 0:
				v += (sin(TAU * 820.0 * u) * 0.5 + sin(TAU * 1730.0 * u) * 0.3 + randf_range(-1, 1) * 0.5 * exp(-u * 80.0)) * exp(-u * 18.0)
		s[i] = v * 0.6
	return _to_wav(s)


static func _gunshot(sec: float, amp: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * lerpf(0.9, 0.05, minf(t * 8.0, 1.0))
		s[i] = (lp * exp(-t * 9.0) + sin(TAU * 60.0 * t) * exp(-t * 18.0) * 0.8) * amp * 0.8
	return _to_wav(s)


static func _reload() -> AudioStreamWAV:
	var s := _buf(0.8)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.08, 0.55]:
			var u: float = t - c
			if u > 0:
				v += (randf_range(-1, 1) * 0.7 + sin(TAU * 2400.0 * u) * 0.3) * exp(-u * 120.0)
		s[i] = v
	return _to_wav(s)


static func _whoosh(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var c := lerpf(0.02, 0.3, sin(PI * t / sec))
		lp += (randf_range(-1, 1) - lp) * c
		s[i] = lp * sin(PI * t / sec) * 1.5
	return _to_wav(s)


static func _thud(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.08
		s[i] = (sin(TAU * 85.0 * t) * 0.8 + lp * 2.0) * exp(-t * 16.0)
	return _to_wav(s)


static func _growl(sec: float, f0: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := f0 * (1.0 + 0.15 * sin(TAU * 3.0 * t)) * (1.0 + 0.3 * t / sec)
		ph += f / RATE
		lp += (randf_range(-1, 1) - lp) * 0.15
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		s[i] = (saw * 0.4 + lp * 1.2) * (0.6 + 0.4 * sin(TAU * 11.0 * t)) * sin(PI * t / sec) * 0.8
	return _to_wav(s)


static func _heartbeat() -> AudioStreamWAV:
	var s := _buf(1.0)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for b in [0.0, 0.28]:
			var u: float = t - b
			if u > 0:
				v += sin(TAU * 52.0 * u) * exp(-u * 22.0)
		s[i] = v * 0.9
	return _to_wav(s)


static func _breath(sec: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var phase := fmod(t, sec) / sec
		var env := pow(sin(PI * clampf(phase / 0.4, 0, 1)), 2) * 0.7 if phase < 0.4 else pow(sin(PI * clampf((phase - 0.5) / 0.45, 0, 1)), 2)
		lp += (randf_range(-1, 1) - lp) * (0.12 if phase < 0.45 else 0.07)
		s[i] = lp * env * 1.6
	return _to_wav(s)


static func _sweep(sec: float, f0: float, f1: float) -> AudioStreamWAV:
	var s := _buf(sec)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / sec)
		ph += f / RATE
		s[i] = (sin(ph * TAU) * 0.5 + sin(ph * TAU * 2.0) * 0.2) * sin(PI * t / sec) * 0.6
	return _to_wav(s)


static func _drone(sec: float, kind: String) -> AudioStreamWAV:
	var s := _buf(sec)
	var root := 55.0 if kind == "music_tension" else (65.41 if kind == "music_bunker" else 49.0)
	var ratios := [1.0, 1.5, 2.0, 2.997, 4.01] if kind != "music_tension" else [1.0, 1.059, 1.5, 2.0, 2.12]
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in ratios.size():
			var r: float = ratios[k]
			var amp := 0.18 / (k + 1.0) * (0.6 + 0.4 * sin(TAU * t / (sec / (k + 1.0)) + k))
			v += sin(TAU * root * r * t) * amp
		lp += (randf_range(-1, 1) - lp) * 0.01
		var env := minf(t / 2.0, 1.0) * minf((sec - t) / 2.0, 1.0)
		s[i] = (v + lp * 0.4) * env
	return _to_wav(s)
