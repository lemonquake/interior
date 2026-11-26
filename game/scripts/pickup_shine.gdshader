// 0.58: the white shine on everything that can be picked up (healthkits, ammunition, dropped weapons, grenade
// pouches, keys). Drawn over the item's own surface as a material overlay (scripts/pickup_shine.gd): a faint
// white rim so it reads in the dark, and a glint that sweeps across it every couple of seconds, offset per item
// by where it lies so a pile of drops does not flash in step.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.94);
uniform float rim_strength = 0.55;
uniform float glint_strength = 1.3;
uniform float fill = 0.075;
uniform float period = 2.4;

varying vec3 world_pos;
varying vec3 item_origin;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	item_origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);
	// The glint: a thin diagonal band across the item, in its own space, once per `period`.
	float phase = fract(TIME / period + fract(dot(item_origin, vec3(0.137, 0.0, 0.211))));
	vec3 local = world_pos - item_origin;
	float along = (local.x + local.y * 1.6 + local.z) * 2.2;
	float sweep = mix(-1.0, 1.0, phase * 1.5);
	float band = 1.0 - smoothstep(0.0, 0.22, abs(along - sweep));
	// A slow breath on the rim so a still item still catches the eye.
	float breath = 0.75 + 0.25 * sin(TIME * 2.1 + item_origin.x * 3.0);
	ALBEDO = tint * (fill + rim * rim_strength * breath + band * glint_strength);
}
