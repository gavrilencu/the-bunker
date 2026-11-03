shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled, fog_disabled;
// Billowing smoke / fireball surface for the mushroom cloud.
// Meshes are unit-sized and scaled by their node; displacement is relative.

uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform float disp = 0.28;
uniform float noise_scale = 2.2;
uniform float speed = 0.12;
uniform vec3 roll_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 hot_color : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 core_color : source_color = vec3(1.0, 0.9, 0.6);
uniform vec3 cool_color : source_color = vec3(0.5, 0.45, 0.41);
uniform vec3 dark_color : source_color = vec3(0.16, 0.13, 0.11);
uniform float emission_strength = 8.0;
uniform float lightness = 1.0;

varying float vn;
varying float vy;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(dot(hash3(i + vec3(0, 0, 0)), f - vec3(0, 0, 0)), dot(hash3(i + vec3(1, 0, 0)), f - vec3(1, 0, 0)), u.x),
				   mix(dot(hash3(i + vec3(0, 1, 0)), f - vec3(0, 1, 0)), dot(hash3(i + vec3(1, 1, 0)), f - vec3(1, 1, 0)), u.x), u.y),
			   mix(mix(dot(hash3(i + vec3(0, 0, 1)), f - vec3(0, 0, 1)), dot(hash3(i + vec3(1, 0, 1)), f - vec3(1, 0, 1)), u.x),
				   mix(dot(hash3(i + vec3(0, 1, 1)), f - vec3(0, 1, 1)), dot(hash3(i + vec3(1, 1, 1)), f - vec3(1, 1, 1)), u.x), u.y), u.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * abs(gnoise(p));
		p = p * 2.07 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	float t = TIME * speed;
	vec3 p = VERTEX * noise_scale + roll_dir * t;
	float n = fbm(p);
	vn = n;
	vy = VERTEX.y;
	VERTEX += NORMAL * (n - 0.3) * disp;
}

void fragment() {
	float n = clamp(vn * 1.6, 0.0, 1.0);
	vec3 col = mix(dark_color, cool_color, smoothstep(0.15, 0.8, n)) * lightness;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	float h = heat * smoothstep(0.1, 0.7, 1.0 - n * 0.8);
	vec3 e = mix(hot_color, core_color, smoothstep(0.75, 1.0, heat) * (1.0 - n));
	EMISSION = e * h * emission_strength;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO *= 1.0 - rim * 0.25;
}
