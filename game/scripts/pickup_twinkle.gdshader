// 0.58: the twinkle on a pickup (scripts/pickup_shine.gd): a small four-pointed white glint that faces the camera,
// flares for a moment every couple of seconds (offset per item by where it lies) and rests as a faint point.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.94);
uniform float period = 2.2;
uniform float strength = 1.6;

varying float phase;

void vertex() {
	// Face the camera, keeping the quad's size.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = origin + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	phase = fract(TIME / period + fract(dot(origin, vec3(0.173, 0.0, 0.291))));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float flare = exp(-pow((phase - 0.5) / 0.07, 2.0));
	float spin = phase * 1.4;
	mat2 turn = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
	vec2 q = turn * p;
	float rays = max(exp(-abs(q.x) * 26.0) * exp(-abs(q.y) * 2.6), exp(-abs(q.y) * 26.0) * exp(-abs(q.x) * 2.6));
	float core = exp(-dot(p, p) * 22.0);
	float glow = rays * flare + core * (0.18 + 0.82 * flare);
	ALBEDO = tint * glow * strength;
}
