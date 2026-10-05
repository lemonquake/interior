shader_type fog;
// Low ground mist outside the house (0.8), for the streets, the courtyard and the rice fields alike. Adapted
// from "Moving gradient noise fog/ mist for Godot 4" by alghost (MIT, reference copy and licence in
// assets/fields/fog/mist_alghost_mit.gdshader.txt; gradient noise by Inigo Quilez, MIT): three octaves of
// 3D gradient noise drift in different directions and the mist thins out with height. Changes: much
// broader and slower so it reads as a soft, faint layer rather than puffs; it never fully clears, it rests
// on the ground (ground_y) and fades out before the balcony and the rooms upstairs; and it fades at the
// edges of its camera-following box (scripts/neighborhood.gd) so the box itself is never seen.

uniform float base_density : hint_range(0.0, 1.0) = 0.02;
uniform vec3 base_color : source_color = vec3(0.6, 0.66, 0.82);
uniform float ground_y = -2.9;
uniform float fade_out_height = 0.5;       // metres above ground_y where the mist starts to thin
uniform float fade_out_distance = 2.2;     // and over how many metres it is gone
uniform float clear_floor = 0.35;          // the thinnest patches keep this much of the density
uniform vec3 noise_amounts = vec3(0.5, 0.32, 0.18);
uniform vec3 noise_scales = vec3(1.0, 2.1, 4.3);
uniform vec3 noise_velocity1 = vec3(0.05, 0.0, 0.02);
uniform vec3 noise_velocity2 = vec3(0.07, 0.0, -0.06);
uniform vec3 noise_velocity3 = vec3(-0.03, 0.02, 0.05);

vec3 hash(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			dot(p, vec3(269.5, 183.3, 246.1)),
			dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(dot(hash(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0)),
						dot(hash(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x),
					mix(dot(hash(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)),
						dot(hash(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x), u.y),
				mix(mix(dot(hash(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)),
						dot(hash(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x),
					mix(dot(hash(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)),
						dot(hash(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

void fog() {
	// World space (the volume follows the camera; the mist itself stays put and drifts with the air).
	vec3 base_pos = WORLD_POSITION * vec3(0.035, 0.25, 0.035);
	float n = noise(base_pos * noise_scales.x + TIME * noise_velocity1) * noise_amounts.x
			+ noise(base_pos * noise_scales.y + TIME * noise_velocity2) * noise_amounts.y
			+ noise(base_pos * noise_scales.z + TIME * noise_velocity3) * noise_amounts.z;
	float patches = mix(clear_floor, 1.0, smoothstep(-0.25, 0.3, n));
	float height = WORLD_POSITION.y - ground_y;
	float layer = 1.0 - smoothstep(fade_out_height, fade_out_height + fade_out_distance, height);
	vec2 edge = abs(UVW.xz - 0.5) * 2.0;
	float edges = 1.0 - smoothstep(0.7, 1.0, max(edge.x, edge.y));
	DENSITY = base_density * patches * layer * edges;
	ALBEDO = base_color;
}
