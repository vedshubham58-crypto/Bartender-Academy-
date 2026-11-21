shader_type canvas_item;
// Soft dark corners: pulls the eye to the bar and makes the frame feel filmed.
uniform float strength = 0.38;
uniform float inner = 0.42;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.75);
	float v = smoothstep(inner, 0.85, length(d) * 1.4);
	COLOR = vec4(0.0, 0.0, 0.02, v * strength);
}
