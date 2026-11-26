shader_type spatial;
render_mode cull_disabled;
uniform vec4 lamp_a = vec4(0.0);
uniform vec4 lamp_b = vec4(0.0);
uniform vec4 lamp_c = vec4(0.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float power = 0.0;
	if (distance(world_position, lamp_a.xyz) < 1.3) { power = lamp_a.w; }
	if (distance(world_position, lamp_b.xyz) < 1.3) { power = lamp_b.w; }
	if (distance(world_position, lamp_c.xyz) < 1.3) { power = lamp_c.w; }
	ALBEDO = vec3(0.055, 0.052, 0.041);
	ROUGHNESS = 0.85;
	EMISSION = vec3(1.0, 0.47, 0.16) * power * 2.0;
}
