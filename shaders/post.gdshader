shader_type canvas_item;
// Full-screen post effect: chromatic aberration, vignette, film grain,
// damage tint, radiation sparkle, gas-mask lenses, flash, desaturation.
// No mipmaps here (a mip chain of the screen every frame is expensive on weak GPUs):
// the blurred variant lives in post_blur.gdshader and is swapped in by the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.38;
uniform float grain : hint_range(0.0, 0.3) = 0.035;
uniform float aberration : hint_range(0.0, 8.0) = 0.9;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float rad : hint_range(0.0, 1.0) = 0.0;
uniform float mask : hint_range(0.0, 1.0) = 0.0;
uniform float mask_fog : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float desat : hint_range(0.0, 1.0) = 0.0;
uniform float blur : hint_range(0.0, 4.0) = 0.0;
uniform vec3 tint = vec3(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 c = uv - 0.5;
	vec2 ca = vec2(c.x * aspect, c.y);
	float d = length(ca);

	// subtle: strongest at the lens edges, never a red halo on the viewmodel
	float ab = (aberration * 0.6 + damage * 3.0 + rad * 1.1) * (0.12 + d * d * 2.2);
	vec2 off = normalize(c + 1e-5) * SCREEN_PIXEL_SIZE * ab;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), desat);
	col *= tint;

	float v = smoothstep(1.05, 0.25, d);
	col *= mix(1.0, v, vignette);

	col = mix(col, vec3(0.45, 0.0, 0.0), damage * smoothstep(0.25, 0.95, d) * 0.85);

	if (mask > 0.0) {
		// Two round GP-5 eyepieces.
		vec2 le = (ca - vec2(-0.25, 0.02)) * vec2(1.0, 0.92);
		vec2 re = (ca - vec2(0.25, 0.02)) * vec2(1.0, 0.92);
		float r = 0.6;
		float dmin = min(length(le), length(re));
		float e = smoothstep(r, r - 0.16, dmin);
		float rim = smoothstep(r - 0.05, r - 0.01, dmin) * smoothstep(r + 0.03, r - 0.01, dmin);
		vec3 fogged = mix(col, vec3(l * 0.9 + 0.08), mask_fog * smoothstep(0.15, 0.55, dmin));
		col = mix(col, fogged * mix(0.12, 1.0, e), mask);
		col += rim * 0.05 * mask;
	}

	float n = hash(uv * res + fract(TIME * 7.13) * 91.7);
	col += (n - 0.5) * (grain + rad * 0.22);
	if (rad > 0.0) {
		float s = hash(floor(uv * res * 0.5) + floor(TIME * 24.0) * 3.1);
		col += step(1.0 - rad * 0.012, s) * vec3(0.9, 1.0, 0.85);
	}

	col = mix(col, vec3(1.0, 0.98, 0.94), flash);
	COLOR = vec4(col, 1.0);
}
