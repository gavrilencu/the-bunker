class_name LevelBase
extends Node3D
## Common level setup: environment, sky, sun, player spawning, quality.

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var player: Player
var env_profile := {}


func _enter_tree() -> void:
	Game.level = self


func make_environment(opts: Dictionary) -> Environment:
	env = Environment.new()
	var sky_id: String = opts.get("hdri", "")
	var hdr := Assets.hdri(sky_id) if sky_id != "" else null
	if opts.get("sky", true):
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		if hdr:
			var pm := PanoramaSkyMaterial.new()
			pm.panorama = hdr
			pm.energy_multiplier = opts.get("sky_energy", 1.0)
			sky.sky_material = pm
		else:
			var ps := ProceduralSkyMaterial.new()
			ps.sky_top_color = opts.get("sky_top", Color(0.32, 0.47, 0.7))
			ps.sky_horizon_color = opts.get("sky_horizon", Color(0.78, 0.76, 0.72))
			ps.ground_horizon_color = opts.get("sky_horizon", Color(0.7, 0.68, 0.62))
			ps.ground_bottom_color = Color(0.2, 0.19, 0.17)
			ps.sun_angle_max = 20.0
			ps.energy_multiplier = opts.get("sky_energy", 1.0)
			sky.sky_material = ps
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		env.sky = sky
		env.sky_rotation = Vector3(0, deg_to_rad(opts.get("sky_rot", 0.0)), 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = opts.get("ambient_energy", 1.0)
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = opts.get("bg", Color(0.0, 0.0, 0.0))
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = opts.get("ambient", Color(0.05, 0.05, 0.06))
		env.ambient_light_energy = opts.get("ambient_energy", 1.0)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = opts.get("exposure", 1.0)
	env.set_meta("base_exposure", opts.get("exposure", 1.0))
	env.set_meta("base_contrast", opts.get("contrast", 1.06))
	env.tonemap_white = opts.get("white", 6.0)

	env.ssao_radius = opts.get("ssao_radius", 1.2)
	env.ssao_intensity = opts.get("ssao_intensity", 2.2)
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8

	env.glow_intensity = opts.get("glow", 0.5)
	env.glow_strength = 1.0
	env.glow_bloom = opts.get("bloom", 0.04)
	env.glow_hdr_threshold = opts.get("glow_threshold", 1.1)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.4)

	env.fog_enabled = opts.get("fog", true)
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = opts.get("fog_color", Color(0.6, 0.62, 0.65))
	env.fog_density = opts.get("fog_density", 0.002)
	env.fog_sky_affect = opts.get("fog_sky_affect", 0.15)
	env.fog_aerial_perspective = opts.get("aerial", 0.4)
	env.fog_sun_scatter = opts.get("sun_scatter", 0.15)

	env.volumetric_fog_density = opts.get("vfog_density", 0.015)
	env.volumetric_fog_albedo = opts.get("vfog_albedo", Color(0.9, 0.9, 0.88))
	env.volumetric_fog_emission = opts.get("vfog_emission", Color(0, 0, 0))
	env.volumetric_fog_anisotropy = opts.get("vfog_aniso", 0.6)
	env.volumetric_fog_length = opts.get("vfog_length", 64.0)
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = opts.get("vfog_ambient", 0.2)
	env.volumetric_fog_sky_affect = opts.get("vfog_sky", 0.0)
	env.volumetric_fog_temporal_reprojection_enabled = true

	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.0

	env.adjustment_enabled = true
	env.adjustment_contrast = opts.get("contrast", 1.06)
	env.adjustment_saturation = opts.get("saturation", 0.92)
	env.adjustment_brightness = 1.0

	env_profile = opts.get("profile", {})
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	apply_quality()
	return env


func make_sun(dir_deg: Vector2, color: Color, energy: float, shadow_dist := 120.0) -> DirectionalLight3D:
	sun = DirectionalLight3D.new()
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = shadow_dist
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	sun.light_volumetric_fog_energy = 1.0
	sun.rotation_degrees = Vector3(dir_deg.x, dir_deg.y, 0)
	sun.set_meta("base_dist", shadow_dist)
	add_child(sun)
	apply_quality()
	return sun


func apply_quality() -> void:
	Settings.apply_environment(env, env_profile)
	if sun:
		sun.directional_shadow_max_distance = float(sun.get_meta("base_dist", 120.0)) * float(Settings.val("shadow_dist"))
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if int(Settings.opt("shadows")) == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func spawn_player(pos: Vector3, yaw_deg: float, pitch_deg := 0.0) -> Player:
	player = Player.new()
	player.position = pos
	player.rotation.y = deg_to_rad(yaw_deg)
	add_child(player)  # _ready -> Game.register_player may apply a debug --pose
	if not Game.args.has("pose"):
		player.set_pitch(deg_to_rad(pitch_deg))
	return player
