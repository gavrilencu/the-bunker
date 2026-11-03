shader_type spatial;
// World-space triplanar concrete with a Soviet-style painted lower band,
// a thin dark stripe at the paint edge, grime near the floor and water stains.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_textures = false;
uniform float tile = 0.45;
uniform vec3 base_color : source_color = vec3(0.62, 0.61, 0.58);
uniform vec3 upper_tint : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 paint_color : source_color = vec3(0.2, 0.31, 0.26);
uniform float paint_height = 1.35;
uniform float floor_y = 0.0;
uniform float grime = 0.55;
uniform float band_enabled = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec2 uvx = wpos.zy * tile;
	vec2 uvy = wpos.xz * tile;
	vec2 uvz = wpos.xy * tile;

	vec3 alb = base_color;
	float rough = 0.88;
	vec3 wn = n;
	if (has_textures) {
		alb = texture(tex_albedo, uvx).rgb * bw.x + texture(tex_albedo, uvy).rgb * bw.y + texture(tex_albedo, uvz).rgb * bw.z;
		rough = texture(tex_rough, uvx).r * bw.x + texture(tex_rough, uvy).r * bw.y + texture(tex_rough, uvz).r * bw.z;
		vec3 tx = texture(tex_normal, uvx).xyz * 2.0 - 1.0;
		vec3 ty = texture(tex_normal, uvy).xyz * 2.0 - 1.0;
		vec3 tz = texture(tex_normal, uvz).xyz * 2.0 - 1.0;
		// UDN blend (swizzle)
		vec3 nx = vec3(n.x, tx.y + n.y, tx.x + n.z);
		vec3 ny = vec3(ty.x + n.x, n.y, ty.y + n.z);
		vec3 nz = vec3(tz.x + n.x, tz.y + n.y, n.z);
		wn = normalize(nx * bw.x + ny * bw.y + nz * bw.z);
	}

	float wall = 1.0 - smoothstep(0.4, 0.6, abs(n.y));
	float h = wpos.y - floor_y;
	float edge_noise = (fbm(wpos * 3.0) - 0.5) * 0.06;
	float band = step(h, paint_height + edge_noise) * wall * band_enabled;
	float stripe = (1.0 - smoothstep(0.0, 0.012, abs(h - paint_height - edge_noise))) * wall * band_enabled;

	float chip = smoothstep(0.62, 0.7, fbm(wpos * 2.2 + 7.0));
	vec3 paint = paint_color * (0.7 + 0.6 * alb);
	vec3 col = mix(alb * upper_tint, paint, band * (1.0 - chip * 0.85));
	col = mix(col, paint_color * 0.35, stripe);

	float dirt = (1.0 - smoothstep(0.0, 0.45, h)) * wall * grime;
	float stains = smoothstep(0.55, 0.85, fbm(vec3(wpos.x * 0.7, wpos.y * 0.15, wpos.z * 0.7) * 1.5)) * wall;
	col *= 1.0 - dirt * 0.55;
	col *= 1.0 - stains * 0.28 * grime;
	col = mix(col, col * vec3(0.95, 0.88, 0.75), stains * 0.4);

	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.6, band * (1.0 - chip));
	METALLIC = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
