shader_type spatial;
// Procedural dry grass: crossed cards carved into tapered, leaning blades by alpha
// scissor; wind sway at the tips; colour varies per instance and per blade.

render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 base_col : source_color = vec3(0.13, 0.11, 0.08);
uniform vec3 tip_col : source_color = vec3(0.56, 0.48, 0.34);
uniform vec3 alt_col : source_color = vec3(0.42, 0.40, 0.3);
uniform float wind_strength = 1.0;
uniform float blades = 11.0;

varying float seed;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	seed = fract(o.x * 0.371 + o.z * 0.917);
	float t = 1.0 - UV.y;
	float w = sin(TIME * 1.6 + o.x * 0.21 + o.z * 0.17) * 0.6 + sin(TIME * 3.7 + o.x * 0.9) * 0.25;
	VERTEX.x += w * 0.09 * t * t * wind_strength;
	VERTEX.z += cos(TIME * 1.2 + o.z * 0.23) * 0.05 * t * t * wind_strength;
	// soften lighting: bend the card normals up
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	float t = 1.0 - UV.y;
	float id = floor(UV.x * blades);
	float fx = fract(UV.x * blades) - 0.5;
	float r = hash(id + seed * 57.0);
	float height = 0.35 + 0.65 * r;
	float lean = (hash(id * 1.7 + seed * 13.0) - 0.5) * 0.9;
	float x = fx - lean * t;
	float width = 0.46 * (1.0 - clamp(t / height, 0.0, 1.0));
	float a = step(abs(x), width) * step(t, height);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 tip = mix(tip_col, alt_col, hash(id * 3.1 + seed * 7.0) * 0.8);
	vec3 col = mix(base_col, tip, smoothstep(0.0, 0.9, t / height));
	col *= 0.78 + 0.4 * hash(id * 5.3 + seed * 3.0);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.25, 0.2, 0.12) * t;
}
