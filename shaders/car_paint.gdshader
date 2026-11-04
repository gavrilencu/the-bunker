shader_type spatial;
// Car body repaint: the red paint of the texture takes the instance colour, rust,
// primer and black trim stay as they are.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
instance uniform vec3 paint : source_color = vec3(0.6, 0.1, 0.08);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float red = smoothstep(0.08, 0.2, c.r - max(c.g, c.b));
	vec3 painted = paint * clamp(l / 0.3, 0.45, 1.5);
	ALBEDO = mix(c, painted, red);
	ROUGHNESS = mix(0.8, 0.38, red);
	METALLIC = mix(0.2, 0.35, red);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
