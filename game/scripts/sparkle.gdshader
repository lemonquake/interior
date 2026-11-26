shader_type spatial;
// 0.10: a twinkling four-point star over the hut key (camera-facing quad, additive).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float phase = 0.0;
uniform float speed = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.55, 1.0);

varying float twinkle;

void vertex() {
	// Billboard: keep the quad's scale, face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float t = fract(TIME * 0.55 * speed + phase);
	// A quick flash, then dark for most of the cycle.
	twinkle = pow(max(0.0, sin(t * 3.14159 * 2.0)), 6.0);
	float angle = TIME * 0.8 * speed + phase * 6.0;
	mat2 r = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	VERTEX.xy = r * VERTEX.xy * (0.35 + 0.65 * twinkle);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float rays = max(0.0, 1.0 - abs(p.x) * 14.0) * max(0.0, 1.0 - abs(p.y) * 1.1)
		+ max(0.0, 1.0 - abs(p.y) * 14.0) * max(0.0, 1.0 - abs(p.x) * 1.1);
	float core = exp(-d * d * 28.0);
	float a = clamp(rays * 0.8 + core, 0.0, 1.0) * (0.15 + 0.85 * twinkle);
	ALBEDO = tint.rgb * a * 2.2;
	ALPHA = a;
}
