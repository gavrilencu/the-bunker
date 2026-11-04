extends Node
## User settings (user://settings.cfg): graphics presets + individual options,
## display, audio, controls. Also registers the input map.

signal changed

const PATH := "user://settings.cfg"
const PRESETS := ["Scăzut", "Mediu", "Ridicat", "Ultra", "Cinematic"]
const CUSTOM := 5

## Option definitions. type: choice | slider | toggle.
## `p` = values per preset [Scăzut, Mediu, Ridicat, Ultra, Cinematic] (graphics only).
const DEFS := [
	# ---------------- GRAFICĂ ----------------
	{"id": "upscaler", "tab": "grafica", "label": "Scalare / upscaling", "type": "choice", "choices": ["Biliniară", "AMD FSR 1.0", "AMD FSR 2.2"], "p": [1, 1, 0, 2, 2],
		"desc": "FSR 2.2 reconstruiește imaginea temporal (calitate apropiată de nativ la rezoluție redusă și antialiasing excelent). FSR 1.0 e mai rapid, dar mai puțin precis."},
	{"id": "render_scale", "tab": "grafica", "label": "Rezoluție de randare", "type": "choice", "choices": ["50%", "59%", "67%", "77%", "85%", "100%", "125%", "150%"], "values": [0.5, 0.59, 0.67, 0.77, 0.85, 1.0, 1.25, 1.5], "p": [2, 4, 5, 5, 5],
		"desc": "Procentul din rezoluția ecranului la care se randează scena 3D. Peste 100% = supersampling (doar cu scalarea biliniară)."},
	{"id": "aa", "tab": "grafica", "label": "Antialiasing", "type": "choice", "choices": ["Dezactivat", "FXAA", "SMAA", "TAA", "TAA + SMAA", "MSAA 2x", "MSAA 4x", "MSAA 8x"], "p": [1, 2, 4, 3, 3],
		"desc": "SMAA: margini curate, cost mic. TAA: elimină pâlpâirea, poate estompa ușor. MSAA: cel mai fin pe geometrie, cost mare. Cu FSR 2.2, antialiasingul e inclus."},
	{"id": "shadows", "tab": "grafica", "label": "Calitatea umbrelor", "type": "choice", "choices": ["Scăzută", "Medie", "Ridicată", "Ultra"], "p": [0, 1, 2, 3, 3],
		"desc": "Rezoluția hărților de umbre și finețea filtrării (umbre moi, realiste)."},
	{"id": "shadow_dist", "tab": "grafica", "label": "Distanța umbrelor", "type": "choice", "choices": ["Aproape", "Normală", "Departe", "Foarte departe"], "values": [0.6, 1.0, 1.5, 2.2], "p": [0, 1, 1, 2, 3],
		"desc": "Până la ce distanță soarele aruncă umbre."},
	{"id": "gi", "tab": "grafica", "label": "Iluminare globală", "type": "choice", "choices": ["Dezactivată", "SSIL", "SDFGI", "SDFGI + SSIL"], "p": [0, 0, 1, 3, 3],
		"desc": "Lumina reflectată de pereți și obiecte. SDFGI = iluminare globală în timp real (impact mare). SSIL = iluminare indirectă în spațiul ecranului."},
	{"id": "gi_quality", "tab": "grafica", "label": "Calitatea iluminării globale", "type": "choice", "choices": ["Scăzută", "Medie", "Ridicată", "Ultra"], "p": [0, 0, 1, 2, 3],
		"desc": "Numărul de raze și rezoluția pentru SDFGI / SSIL."},
	{"id": "ao", "tab": "grafica", "label": "Ocluzie ambientală (SSAO)", "type": "choice", "choices": ["Dezactivată", "Scăzută", "Medie", "Ridicată", "Ultra"], "p": [0, 1, 2, 3, 4],
		"desc": "Umbre de contact în colțuri și sub obiecte. Dă profunzime scenei."},
	{"id": "ssr", "tab": "grafica", "label": "Reflexii în spațiul ecranului", "type": "choice", "choices": ["Dezactivate", "Scăzute", "Ridicate"], "p": [0, 0, 0, 1, 2],
		"desc": "Reflexii pe suprafețe lucioase, bălți, metal."},
	{"id": "vfog", "tab": "grafica", "label": "Ceață volumetrică", "type": "choice", "choices": ["Dezactivată", "Scăzută", "Medie", "Ridicată", "Ultra"], "p": [0, 1, 2, 3, 4],
		"desc": "Raze de lumină prin praf și ceață, atmosferă densă. Ultra folosește o grilă 3D foarte fină."},
	{"id": "glow", "tab": "grafica", "label": "Strălucire (bloom)", "type": "choice", "choices": ["Dezactivată", "Ușoară", "Completă"], "p": [1, 2, 2, 2, 2],
		"desc": "Halou în jurul surselor de lumină puternice. „Ușoară” costă o treime pe plăcile integrate."},
	{"id": "aniso", "tab": "grafica", "label": "Filtrare texturi", "type": "choice", "choices": ["Biliniară", "Anizotropic 2x", "Anizotropic 4x", "Anizotropic 8x", "Anizotropic 16x"], "p": [1, 2, 3, 4, 4],
		"desc": "Claritatea texturilor văzute din unghi (podele, drumuri)."},
	{"id": "lod", "tab": "grafica", "label": "Detaliu geometric (LOD, teren)", "type": "choice", "choices": ["Scăzut", "Mediu", "Ridicat", "Ultra"], "values": [4.0, 2.0, 1.0, 0.5], "p": [0, 1, 2, 3, 3],
		"desc": "Cât de repede modelele trec la variante simplificate cu distanța."},
	{"id": "particles", "tab": "grafica", "label": "Particule", "type": "choice", "choices": ["Puține", "Normale", "Multe"], "values": [0.4, 1.0, 1.6], "p": [0, 1, 1, 2, 2],
		"desc": "Densitatea prafului, cenușii și efectelor (se aplică la următoarea încărcare de nivel)."},
	{"id": "vegetation", "tab": "grafica", "label": "Vegetație", "type": "choice", "choices": ["Rară", "Medie", "Deasă", "Ultra"], "values": [0.3, 0.55, 0.8, 1.0], "p": [0, 1, 2, 3, 3],
		"desc": "Densitatea ierbii uscate de pe suprafață (se aplică la următoarea încărcare de nivel)."},
	# ---------------- ECRAN ----------------
	{"id": "window_mode", "tab": "ecran", "label": "Mod afișare", "type": "choice", "choices": ["Fereastră", "Fereastră fără margini", "Ecran complet", "Ecran complet exclusiv"], "default": 2,
		"desc": "Ecranul complet exclusiv poate reduce latența pe unele sisteme."},
	{"id": "resolution", "tab": "ecran", "label": "Rezoluție fereastră", "type": "choice", "choices": ["1280×720", "1600×900", "1920×1080", "2560×1440", "3840×2160"], "values": [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)], "default": 1,
		"desc": "Se aplică doar în modul fereastră."},
	{"id": "vsync", "tab": "ecran", "label": "Sincronizare verticală", "type": "choice", "choices": ["Dezactivată", "Activată", "Adaptivă", "Mailbox"], "default": 1,
		"desc": "Elimină ruperea imaginii (tearing). Adaptivă = doar când FPS-ul depășește rata monitorului."},
	{"id": "fps_limit", "tab": "ecran", "label": "Limită FPS", "type": "choice", "choices": ["Nelimitat", "30", "60", "90", "120", "144", "165", "240"], "values": [0, 30, 60, 90, 120, 144, 165, 240], "default": 0, "desc": "Limitează cadrele pe secundă (economisește energie / reduce căldura)."},
	{"id": "fov", "tab": "ecran", "label": "Câmp vizual (FOV)", "type": "slider", "min": 60.0, "max": 110.0, "step": 1.0, "default": 78.0, "fmt": "%d°", "desc": "Unghiul vertical al camerei."},
	{"id": "brightness", "tab": "ecran", "label": "Luminozitate", "type": "slider", "min": 0.6, "max": 1.6, "step": 0.02, "default": 1.0, "fmt": "%.2f", "desc": "Expunerea generală a imaginii."},
	{"id": "contrast", "tab": "ecran", "label": "Contrast", "type": "slider", "min": 0.8, "max": 1.3, "step": 0.01, "default": 1.0, "fmt": "%.2f", "desc": "Contrastul final al imaginii."},
	{"id": "grain", "tab": "ecran", "label": "Granulație film", "type": "toggle", "default": 1, "desc": "Zgomot fin de film, pentru atmosferă."},
	{"id": "aberration", "tab": "ecran", "label": "Aberație cromatică", "type": "toggle", "default": 1, "desc": "Separare subtilă a culorilor spre marginile ecranului."},
	{"id": "vignette", "tab": "ecran", "label": "Vignetă", "type": "toggle", "default": 1, "desc": "Întunecarea colțurilor imaginii."},
	{"id": "headbob", "tab": "ecran", "label": "Mișcarea camerei la mers", "type": "choice", "choices": ["Dezactivată", "Redusă", "Normală"], "values": [0.0, 0.5, 1.0], "default": 2, "desc": "Legănarea camerei când mergi și alergi."},
	{"id": "hud", "tab": "ecran", "label": "Mod HUD", "type": "choice", "choices": ["Complet", "Dinamic", "Minimal"], "default": 1,
		"desc": "Dinamic: indicatorii apar doar când contează (ca în jocurile moderne). Minimal: doar esențialul."},
	{"id": "show_fps", "tab": "ecran", "label": "Indicator performanță", "type": "choice", "choices": ["Ascuns", "FPS", "FPS + detalii"], "default": 0, "desc": "Afișează FPS, timpul de cadru și apelurile de desenare."},
	# ---------------- AUDIO ----------------
	{"id": "vol_master", "tab": "audio", "label": "Volum general", "type": "slider", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.9, "fmt": "pct"},
	{"id": "vol_music", "tab": "audio", "label": "Muzică", "type": "slider", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.65, "fmt": "pct"},
	{"id": "vol_sfx", "tab": "audio", "label": "Efecte sonore", "type": "slider", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.9, "fmt": "pct"},
	{"id": "vol_ambient", "tab": "audio", "label": "Ambianță", "type": "slider", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.8, "fmt": "pct"},
	{"id": "vol_ui", "tab": "audio", "label": "Interfață", "type": "slider", "min": 0.0, "max": 1.0, "step": 0.01, "default": 0.7, "fmt": "pct"},
	# ---------------- CONTROL ----------------
	{"id": "sensitivity", "tab": "control", "label": "Sensibilitate mouse", "type": "slider", "min": 0.5, "max": 6.0, "step": 0.05, "default": 2.2, "fmt": "%.2f"},
	{"id": "invert_y", "tab": "control", "label": "Inversează axa Y", "type": "toggle", "default": 0},
]

## Current values: choice -> index, toggle -> 0/1, slider -> float.
var v := {}
var preset := 2

var _defs_by_id := {}

# legacy accessors used across the code
var mouse_sensitivity: float:
	get: return float(v.get("sensitivity", 2.2)) / 1000.0
var fov: float:
	get: return float(v.get("fov", 78.0))
var invert_y: bool:
	get: return int(v.get("invert_y", 0)) == 1
var show_fps: bool:
	get: return int(v.get("show_fps", 0)) > 0
var quality: int:
	get: return preset


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d in DEFS:
		_defs_by_id[d.id] = d
	_register_inputs()
	_create_buses()
	reset_defaults()
	load_settings()
	if "--windowed" in OS.get_cmdline_user_args():
		v["window_mode"] = 0
	apply()


func def(id: String) -> Dictionary:
	return _defs_by_id.get(id, {})


## Raw stored value (index / float).
func opt(id: String):
	return v.get(id, 0)


## Mapped value: choice with `values` -> value, otherwise raw.
func val(id: String):
	var d := def(id)
	var raw = v.get(id, 0)
	if d.has("values"):
		var arr: Array = d.values
		return arr[clampi(int(raw), 0, arr.size() - 1)]
	return raw


func set_opt(id: String, value, apply_now := true) -> void:
	v[id] = value
	var d := def(id)
	if d.get("tab", "") == "grafica":
		preset = _detect_preset()
	if apply_now:
		apply()


func apply_preset(p: int) -> void:
	preset = p
	if p >= CUSTOM:
		return
	for d in DEFS:
		if d.has("p"):
			v[d.id] = d.p[p]
	apply()


func _detect_preset() -> int:
	for p in PRESETS.size():
		var ok := true
		for d in DEFS:
			if d.has("p") and int(v.get(d.id, -1)) != int(d.p[p]):
				ok = false
				break
		if ok:
			return p
	return CUSTOM


func reset_defaults() -> void:
	for d in DEFS:
		if d.has("default"):
			v[d.id] = d.default
		elif d.has("p"):
			v[d.id] = d.p[2]
	preset = 2


## Picks a starting preset from the GPU (first launch only).
func _autodetect() -> void:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var strong := ["rtx 30", "rtx 40", "rtx 50", "rtx 60", "rx 6", "rx 7", "rx 9", "arc b", "rtx 2080", "titan"]
	var weak := ["intel(r) uhd", "intel(r) hd", "iris", "vega 8", "mx", "gt 10", "gtx 9", "gtx 7"]
	for s in strong:
		if gpu.contains(s):
			apply_preset(3)
			return
	for s in weak:
		if gpu.contains(s):
			apply_preset(0)
			return
	apply_preset(2)


# --------------------------------------------------------------------------
# Input / audio buses
# --------------------------------------------------------------------------

func _register_inputs() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("sprint", [KEY_SHIFT])
	_bind("crouch", [KEY_CTRL, KEY_C])
	_bind("interact", [KEY_E])
	_bind("inventory", [KEY_TAB, KEY_I])
	_bind("build", [KEY_B])
	_bind("rotate", [KEY_R])
	_bind("flashlight", [KEY_F])
	_bind("pause", [KEY_ESCAPE])
	_bind("journal", [KEY_J])
	_bind("slot_1", [KEY_1])
	_bind("slot_2", [KEY_2])
	_bind("slot_3", [KEY_3])
	_bind("slot_4", [KEY_4])
	_bind("map", [KEY_M])
	_bind("upgrades", [KEY_U])
	_bind("demolish", [KEY_X])
	_bind("move_object", [KEY_G])
	_bind("snap_toggle", [KEY_T])
	_bind("heal", [KEY_H])
	_bind("attack", [], [MOUSE_BUTTON_LEFT])
	_bind("aim", [], [MOUSE_BUTTON_RIGHT])
	_bind("wheel_up", [], [MOUSE_BUTTON_WHEEL_UP])
	_bind("wheel_down", [], [MOUSE_BUTTON_WHEEL_DOWN])


func _bind(action: StringName, keys: Array, buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var m := InputEventMouseButton.new()
		m.button_index = b
		InputMap.action_add_event(action, m)


func _create_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambient", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.55
		rev.damping = 0.6
		rev.wet = 0.12
		rev.dry = 1.0
		AudioServer.add_bus_effect(sfx, rev)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		AudioServer.add_bus_effect(master, AudioEffectHardLimiter.new())


func set_reverb(wet: float, room: float = 0.55) -> void:
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) > 0:
		var rev := AudioServer.get_bus_effect(sfx, 0) as AudioEffectReverb
		if rev:
			rev.wet = wet
			rev.room_size = room


# --------------------------------------------------------------------------
# Apply
# --------------------------------------------------------------------------

func _rs(method: String, args: Array) -> void:
	if RenderingServer.has_method(method):
		RenderingServer.callv(method, args)


func apply() -> void:
	# audio
	for pair in [[0, "vol_master"], [AudioServer.get_bus_index("Music"), "vol_music"], [AudioServer.get_bus_index("SFX"), "vol_sfx"],
			[AudioServer.get_bus_index("Ambient"), "vol_ambient"], [AudioServer.get_bus_index("UI"), "vol_ui"]]:
		if pair[0] >= 0:
			AudioServer.set_bus_volume_db(pair[0], linear_to_db(maxf(float(v.get(pair[1], 0.8)), 0.0001)))
	# display
	var wm := int(v.get("window_mode", 2))
	if not Engine.is_editor_hint():
		match wm:
			0:
				if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				var res: Vector2i = val("resolution")
				var screen := DisplayServer.screen_get_size()
				res = Vector2i(mini(res.x, screen.x), mini(res.y, screen.y))
				if DisplayServer.window_get_size() != res:
					DisplayServer.window_set_size(res)
					DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - res) / 2)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				DisplayServer.window_set_position(DisplayServer.screen_get_position())
				DisplayServer.window_set_size(DisplayServer.screen_get_size())
			2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			3:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var vs := [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX]
	DisplayServer.window_set_vsync_mode(vs[clampi(int(v.get("vsync", 1)), 0, 3)])
	Engine.max_fps = int(val("fps_limit"))

	# viewport
	var vp := get_viewport()
	var up := int(v.get("upscaler", 0))
	var scale: float = val("render_scale")
	match up:
		0:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		1:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			scale = minf(scale, 1.0)
		2:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			scale = minf(scale, 1.0)
	vp.scaling_3d_scale = scale
	vp.fsr_sharpness = 0.25
	var aa := int(v.get("aa", 2))
	var fsr2 := up == 2
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][aa]
	vp.use_taa = (aa == 3 or aa == 4) and not fsr2
	var ssaa := Viewport.SCREEN_SPACE_AA_DISABLED
	if aa == 1:
		ssaa = Viewport.SCREEN_SPACE_AA_FXAA
	elif aa == 2 or aa == 4:
		ssaa = Viewport.SCREEN_SPACE_AA_SMAA
	vp.screen_space_aa = ssaa
	vp.use_debanding = true
	vp.mesh_lod_threshold = float(val("lod"))
	vp.set("anisotropic_filtering_level", int(v.get("aniso", 3)))
	vp.texture_mipmap_bias = -0.5 if (vp.use_taa or fsr2) else 0.0

	# shadows
	var sq := int(v.get("shadows", 2))
	var dir_size: int = [2048, 4096, 4096, 8192][sq]
	RenderingServer.directional_shadow_atlas_set_size(dir_size, true)
	# ShadowQuality: 1 very low, 2 low, 3 medium, 4 high, 5 ultra
	var filt: int = [1, 2, 3, 4][sq]
	RenderingServer.directional_soft_shadow_filter_set_quality(filt)
	RenderingServer.positional_soft_shadow_filter_set_quality(filt)
	vp.positional_shadow_atlas_size = int([2048, 4096, 8192, 8192][sq])
	vp.positional_shadow_atlas_16_bits = true

	# global GI parameters
	var gq := int(v.get("gi_quality", 1))
	# enum values as ints (ray count: 2=16 .. 5=96; converge: 5=30 frames .. 1=10 frames;
	# SSIL/SSAO quality: 0 very low .. 4 ultra; SSR roughness: 1 low .. 3 high)
	_rs("environment_set_sdfgi_ray_count", [int([2, 3, 4, 5][gq])])
	_rs("environment_set_sdfgi_frames_to_converge", [int([5, 3, 2, 1][gq])])
	_rs("gi_set_use_half_resolution", [gq <= 1])
	_rs("environment_set_ssil_quality", [int([1, 2, 3, 4][gq]), gq <= 1, 0.5, 4, 50.0, 300.0])
	var ao := int(v.get("ao", 2))
	if ao > 0:
		_rs("environment_set_ssao_quality", [int([0, 1, 2, 3, 4][ao]), ao <= 2, 0.5, 2, 50.0, 300.0])
	var vf := int(v.get("vfog", 2))
	if vf > 0:
		var sz: int = [0, 48, 64, 96, 160][vf]
		_rs("environment_set_volumetric_fog_volume_size", [sz, sz])
		_rs("environment_set_volumetric_fog_filter_active", [vf >= 2])
	changed.emit()
	if has_node("/root/Game"):
		get_node("/root/Game").reapply_environment()


## Tunes an Environment created by LevelBase. `profile` lets a level opt out of
## features (keys: sdfgi, ssil, vfog, ssr -> false). Base values are read from
## env metadata so the call is idempotent.
func apply_environment(env: Environment, profile: Dictionary = {}) -> void:
	if env == null:
		return
	var gi := int(v.get("gi", 1))
	env.sdfgi_enabled = (gi == 2 or gi == 3) and profile.get("sdfgi", true)
	env.ssil_enabled = (gi == 1 or gi == 3) and profile.get("ssil", true)
	var ao := int(v.get("ao", 2))
	env.ssao_enabled = ao > 0
	var ssr := int(v.get("ssr", 0))
	env.ssr_enabled = ssr > 0 and profile.get("ssr", true)
	env.ssr_max_steps = 48 if ssr == 1 else 96
	var vf := int(v.get("vfog", 2))
	env.volumetric_fog_enabled = vf > 0 and profile.get("vfog", true)
	var glow := int(v.get("glow", 1))
	env.glow_enabled = glow > 0
	# light glow: linear upscale and three levels (about a third of the cost on an iGPU)
	RenderingServer.environment_glow_set_use_bicubic_upscale(glow >= 2)
	env.set_glow_level(4, 0.6 if glow >= 2 else 0.0)
	env.set_glow_level(5, 0.4 if glow >= 2 else 0.0)
	env.tonemap_exposure = float(env.get_meta("base_exposure", 1.0)) * float(v.get("brightness", 1.0))
	env.adjustment_contrast = float(env.get_meta("base_contrast", 1.0)) * float(v.get("contrast", 1.0))
	if env.sdfgi_enabled:
		env.sdfgi_cascades = 6 if int(v.get("gi_quality", 1)) >= 2 else 4


# --------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 2)
	cfg.set_value("meta", "preset", preset)
	for k in v:
		cfg.set_value("opts", k, v[k])
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or int(cfg.get_value("meta", "version", 1)) < 2:
		_autodetect()
		return
	for k in cfg.get_section_keys("opts"):
		if _defs_by_id.has(k):
			v[k] = cfg.get_value("opts", k)
	preset = _detect_preset()
