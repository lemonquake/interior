shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float left = (1.0 - smoothstep(0.08, 0.55, UV.x)) * 0.64;
	float edge = smoothstep(0.3, 0.77, distance(UV, vec2(0.53, 0.48))) * 0.20;
	COLOR = vec4(0.006, 0.011, 0.017, max(left, edge));
}
