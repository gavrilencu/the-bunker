shader_type spatial;
// Grass clumps from scanned / modelled assets: alpha-tested, two-sided, translucent-ish,
// swaying in the wind more at the tips (height in the clump's own space).

render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.42;
uniform float height = 0.5;
uniform float wind = 1.0;
uniform float normal_up = 0.55;

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = clamp(VERTEX.y / max(height, 0.01), 0.0, 1.0);
	float w = sin(TIME * 1.7 + o.x * 0.23 + o.z * 0.19) * 0.6 + sin(TIME * 3.9 + o.x * 0.8 + o.z * 0.5) * 0.25;
	VERTEX.x += w * 0.07 * t * t * wind;
	VERTEX.z += cos(TIME * 1.3 + o.z * 0.27) * 0.045 * t * t * wind;
	// grass lit from above (no harsh card shading)
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), normal_up));
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.88;
	SPECULAR = 0.2;
	BACKLIGHT = c.rgb * 0.35;
}
