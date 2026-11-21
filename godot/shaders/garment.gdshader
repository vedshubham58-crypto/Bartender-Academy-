shader_type spatial;
render_mode cull_disabled;
// Recolours a guest's top while keeping the fabric's shading, folds and normal map.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap;
uniform bool has_nrm = false;
uniform vec3 tint : source_color = vec3(0.6, 0.15, 0.15);
uniform float amount = 0.85;
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(c, tint * (0.45 + l * 1.4), amount);
	if (has_nrm) {
		NORMAL_MAP = texture(nrm, UV).rgb;
	}
	ROUGHNESS = 0.8;
	SPECULAR = 0.15;
}
