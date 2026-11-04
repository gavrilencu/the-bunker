shader_type spatial;
// Townsperson variety from one texture: the light-blue shirt, the blue jeans and the
// dark hair are recoloured per instance (instance uniforms), keeping the texture shading.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
instance uniform vec3 shirt : source_color = vec3(0.6, 0.8, 0.9);
instance uniform vec3 trousers : source_color = vec3(0.12, 0.18, 0.3);
instance uniform vec3 hair : source_color = vec3(0.12, 0.08, 0.05);
instance uniform float skin = 1.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float blue = smoothstep(0.06, 0.18, c.b - c.r);
	float light = smoothstep(0.32, 0.5, l);
	vec3 shirt_c = shirt * clamp(l / 0.68, 0.35, 1.3);
	vec3 pants_c = trousers * clamp(l / 0.22, 0.4, 1.6);
	vec3 col = mix(c, mix(pants_c, shirt_c, light), blue);
	// dark, non-blue pixels: hair and beard
	float dark = (1.0 - smoothstep(0.1, 0.2, l)) * (1.0 - blue);
	col = mix(col, hair * clamp(l / 0.08, 0.5, 1.8), dark * 0.85);
	// warm, bright, non-blue pixels: skin
	float warm = smoothstep(0.05, 0.2, c.r - c.b) * (1.0 - dark) * step(0.25, l);
	col = mix(col, col * skin, warm);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
