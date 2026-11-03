shader_type spatial;
render_mode cull_disabled, depth_draw_never, specular_disabled, shadows_disabled, fog_disabled;
// Expanding blast-wave dust wall. Applied to an open unit cylinder (radius 1, height 1).

uniform vec4 dust_color : source_color = vec4(0.52, 0.44, 0.36, 1.0);
uniform float opacity = 0.95;
uniform float world_noise = 0.012;

varying vec3 wpos;
varying float lh;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	lh = VERTEX.y + 0.5;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fbm(vec3(wpos.x * world_noise, wpos.y * world_noise * 2.0 - TIME * 0.6, wpos.z * world_noise));
	float top = 1.0 - smoothstep(0.35 + n * 0.45, 0.95, lh);
	float a = opacity * top * smoothstep(0.25, 0.55, n + 0.2);
	ALBEDO = dust_color.rgb * (0.55 + 0.7 * n);
	ALPHA = clamp(a, 0.0, 1.0);
}
