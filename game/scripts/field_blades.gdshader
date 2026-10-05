shader_type spatial;
// Rice and verge grass (0.7): procedural blade clumps instanced by InteriorFieldsBuilder in MultiMesh
// chunks. Gust fronts roll across the paddies as travelling waves; the global wind_gust (driven by
// InteriorNightAudio's wind) makes them stronger, so the rice visibly bows when the wind is heard.
// Per-instance custom data: r = tint shift, g = height scale (already in the transform), b = phase,
// a = ripeness (0 green .. 1 gold). UV.y runs 0 at the root to 1 at the tip.
render_mode cull_disabled, depth_draw_opaque;

global uniform float wind_gust;

uniform vec3 root_color : source_color = vec3(0.07, 0.12, 0.05);
uniform vec3 tip_color : source_color = vec3(0.3, 0.44, 0.2);
uniform vec3 ripe_color : source_color = vec3(0.55, 0.48, 0.22);
uniform vec2 wind_direction = vec2(0.8, 0.6);
uniform float sway = 0.07;
uniform float gust_sway = 0.26;
uniform float wave_length = 9.0;
uniform float wave_speed = 2.3;
uniform float backlight = 0.6;

varying float tip;
varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	tip = UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 dir = normalize(wind_direction);
	float gust = clamp(wind_gust, 0.0, 1.0);
	// A long gust front plus smaller cross ripples, travelling with the wind.
	float along = dot(world.xz, dir);
	float wave = sin(along / wave_length * TAU - TIME * wave_speed + custom.b * 0.8);
	float flutter = sin(dot(world.xz, vec2(1.7, -2.3)) + TIME * (4.0 + custom.b) ) * 0.25;
	float bend = (sway * (0.6 + 0.4 * wave) + gust_sway * gust * (0.55 + 0.45 * wave) + flutter * 0.02) * tip * tip;
	vec3 offset_world = vec3(dir.x, 0.0, dir.y) * bend;
	offset_world.y = -bend * bend * 1.2;
	// Instances are rotated and uniformly scaled: the transpose over the squared scale inverts that.
	mat3 basis = mat3(MODEL_MATRIX);
	VERTEX += transpose(basis) * offset_world / max(dot(basis[0], basis[0]), 0.0001);
}

void fragment() {
	vec3 green = mix(root_color, tip_color, smoothstep(0.0, 1.0, tip));
	vec3 col = mix(green, ripe_color * mix(0.6, 1.0, tip), clamp(custom.a, 0.0, 1.0));
	col *= 0.8 + 0.4 * custom.r;
	ALBEDO = col;
	ROUGHNESS = 0.72;
	SPECULAR = 0.45;
	BACKLIGHT = col * backlight;
	// Blades are double-sided cards: face the normal toward the viewer for lighting.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
