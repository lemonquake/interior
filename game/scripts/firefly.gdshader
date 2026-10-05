shader_type spatial;
// Fireflies (0.7): camera-facing glow sprites for the GPUParticles3D swarms over the pond, the hut,
// the bamboo and the giant tree. Each one flashes on its own rhythm (a quick rise, a slow fade, then
// dark) and fades in and out over its particle lifetime; the haze dims the far ones.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.72, 1.0, 0.32);
uniform float energy = 7.0;

varying float flash;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float id = float(INSTANCE_ID);
	float seed = fract(sin(id * 12.9898 + 4.1) * 43758.5453);
	float rate = 0.22 + seed * 0.35;
	float t = fract(TIME * rate + seed * 17.0);
	flash = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.1, 0.42, t));
	float life = INSTANCE_CUSTOM.y;
	flash *= smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.85, 1.0, life));
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = dot(c, c);
	float a = exp(-d * 5.0) * 0.6 + exp(-d * 45.0);
	ALBEDO = glow_color * energy;
	ALPHA = clamp(a * flash, 0.0, 1.0);
}
