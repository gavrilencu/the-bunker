shader_type spatial;
// Splat terrain: ash ground, dirt (slopes / craters / patches), gravel, asphalt roads.
// Masks come from vertex colour (r road, g dirt, b gravel, a dry-grass tint).
// Two-scale sampling + macro noise break up tiling; height-aware blending.

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D ash_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ash_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;

uniform float ash_tile = 0.22;
uniform float dirt_tile = 0.3;
uniform float gravel_tile = 0.45;
uniform float road_tile = 0.18;
uniform vec3 ash_tint : source_color = vec3(1.0);
uniform vec3 dirt_tint : source_color = vec3(0.95, 0.9, 0.85);
uniform vec3 grass_tint : source_color = vec3(0.78, 0.7, 0.52);
uniform float normal_strength = 1.0;
// 0 = single-scale sampling (10 fetches instead of 17; the "Scăzut" geometry preset)
uniform int detail = 1;

varying vec3 wpos;
varying vec4 mask;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	mask = COLOR;
}

vec3 two_scale(sampler2D tex, vec2 uv) {
	vec3 a = texture(tex, uv).rgb;
	vec2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.31 + vec2(0.37, 0.11);
	vec3 b = texture(tex, r).rgb;
	return mix(a, b, 0.38);
}

vec3 two_scale_n(sampler2D tex, vec2 uv) {
	vec3 a = texture(tex, uv).rgb;
	vec2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.31 + vec2(0.37, 0.11);
	vec3 b = texture(tex, r).rgb;
	return normalize(mix(a, b, 0.3) * 2.0 - 1.0) * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = wpos.xz;
	float macro = texture(macro_noise, uv * 0.012).r;
	float macro2 = texture(macro_noise, uv * 0.047 + vec2(0.3, 0.7)).r;
	float slope = 1.0 - clamp(wnormal.y, 0.0, 1.0);

	vec3 c_ash, c_dirt, c_grav, n_ash, n_dirt;
	if (detail > 0) {
		c_ash = two_scale(ash_albedo, uv * ash_tile);
		c_dirt = two_scale(dirt_albedo, uv * dirt_tile);
		c_grav = two_scale(gravel_albedo, uv * gravel_tile);
		n_ash = two_scale_n(ash_normal, uv * ash_tile);
		n_dirt = two_scale_n(dirt_normal, uv * dirt_tile);
	} else {
		c_ash = texture(ash_albedo, uv * ash_tile).rgb;
		c_dirt = texture(dirt_albedo, uv * dirt_tile).rgb;
		c_grav = texture(gravel_albedo, uv * gravel_tile).rgb;
		n_ash = texture(ash_normal, uv * ash_tile).rgb;
		n_dirt = texture(dirt_normal, uv * dirt_tile).rgb;
	}
	c_ash *= ash_tint * mix(0.82, 1.12, macro);
	c_dirt *= dirt_tint;
	c_grav *= vec3(0.62, 0.6, 0.57);
	vec3 c_road = texture(road_albedo, uv * road_tile).rgb * mix(0.85, 1.05, macro2);
	vec3 n_grav = texture(gravel_normal, uv * gravel_tile).rgb;
	vec3 n_road = texture(road_normal, uv * road_tile).rgb;

	// weights (height-aware: brighter / higher texels win the transition)
	float w_dirt = clamp(max(mask.g, smoothstep(0.18, 0.42, slope)) + (macro2 - 0.5) * 0.5, 0.0, 1.0);
	float w_grav = clamp(mask.b + (macro - 0.5) * 0.4, 0.0, 1.0);
	float w_road = mask.r;
	float h_ash = dot(c_ash, vec3(0.33));
	float h_dirt = dot(c_dirt, vec3(0.33));
	float h_grav = dot(c_grav, vec3(0.33));
	w_dirt = smoothstep(0.0, 1.0, clamp(w_dirt * 1.6 - 0.3 + (h_dirt - h_ash) * 0.8, 0.0, 1.0));
	w_grav = smoothstep(0.0, 1.0, clamp(w_grav * 1.6 - 0.3 + (h_grav - h_ash) * 0.8, 0.0, 1.0));
	float road_break = detail > 0 ? texture(road_albedo, uv * road_tile * 0.5).r : c_road.r;
	float w_r = smoothstep(0.25, 0.75, w_road + (road_break - 0.4) * 0.35);

	vec3 col = mix(c_ash, c_dirt, w_dirt);
	vec3 nrm = mix(n_ash, n_dirt, w_dirt);
	float rough = mix(0.95, 0.9, w_dirt);
	col = mix(col, c_grav, w_grav);
	nrm = mix(nrm, n_grav, w_grav);
	col = mix(col, c_road, w_r);
	nrm = mix(nrm, n_road, w_r);
	rough = mix(rough, 0.82, w_r);
	// dry-grass areas: warmer, paler ground
	col = mix(col, col * grass_tint * 1.25, mask.a * (1.0 - w_r) * 0.6);
	// far distance: fade fine detail into the macro colour (kills tiling at range)
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	col *= mix(1.0, mix(0.9, 1.08, macro2), smoothstep(40.0, 160.0, dist));

	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - smoothstep(60.0, 200.0, dist) * 0.7);
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
