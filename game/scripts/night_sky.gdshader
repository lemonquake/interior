shader_type spatial;
// Full-moon night sky for the neighbourhood and the rice fields (0.7). Drawn on the camera-following
// dome built by scripts/neighborhood_builder.gd: a deep blue gradient, a big full moon (NASA LRO colour
// map, public domain) with limb darkening and a halo, small twinkling stars that fade near the moon
// and the haze, thin moonlit clouds drifting past, and far mountain and tree-line silhouettes that melt
// into the fog colour, so the land under the sky dissolves into the same blue haze as the geometry.
// night_water.gdshader repeats sky_colour() so the paddies reflect exactly this sky.
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_opaque, skip_vertex_transform;

#include "res://scripts/night_common.gdshaderinc"

uniform float land_energy = 1.0;             // 0 hides the mountain / tree silhouettes

varying vec3 world_dir;

void vertex() {
	world_dir = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 d = normalize(world_dir);
	vec3 m = normalize(moon_direction);
	vec3 c = sky_colour(d, false);
	float moon_mask;
	vec3 disc = moon_disc(d, m, moon_mask);
	float up = d.y;
	// Stars: fewer near the moon and in the haze, none below the horizon.
	float moon_wash = 1.0 - smoothstep(0.75, 0.995, dot(d, m)) * 0.85;
	float haze = smoothstep(0.02, 0.32, up);
	float s = stars(d, 160.0, star_density, 0.0) + stars(d, 330.0, star_density * 0.9, 3.0) * 0.6;
	c += vec3(0.85, 0.9, 1.0) * s * star_energy * haze * moon_wash;
	// Thin clouds on a plane overhead, drifting; lit silver near the moon, dark grey elsewhere.
	if (up > 0.0) {
		vec2 plane = d.xz / (up + 0.18);
		vec2 drift = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(plane * 1.6 + drift) * 0.7 + fbm(plane * 4.1 - drift * 1.7) * 0.3;
		float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, n) * smoothstep(0.0, 0.18, up);
		float lit = pow(max(dot(d, m), 0.0), 8.0);
		vec3 cloud = mix(vec3(0.03, 0.04, 0.06), vec3(0.42, 0.47, 0.56), lit) + halo_color * 0.05;
		c = mix(c, cloud, cover * 0.85);
		// Clouds drift across the moon and veil it.
		moon_mask *= 1.0 - cover * 0.75;
	}
	c = mix(c, disc, moon_mask);
	// Far land: a mountain range and a ragged tree line, both melting into the horizon haze.
	if (land_energy > 0.0) {
		float az = atan(d.x, d.z) / TAU + 0.5;
		float mountains = 0.012 + 0.07 * pow(ridge(az * 9.0), 1.6) + 0.02 * ridge(az * 37.0);
		float trees = 0.006 + 0.014 * ridge(az * 160.0) + 0.006 * hash11(floor(az * 2200.0));
		vec3 far_land = mix(horizon_color * 0.55, horizon_color, 0.35);
		vec3 near_land = horizon_color * 0.32;
		c = mix(c, far_land, (1.0 - smoothstep(mountains - 0.002, mountains + 0.002, up)) * land_energy);
		c = mix(c, near_land, (1.0 - smoothstep(trees - 0.0015, trees + 0.0015, up)) * land_energy);
	}
	// Below the horizon the dome shows the fog colour, matching the geometry's haze.
	c = mix(horizon_color, c, smoothstep(-0.03, 0.0, up));
	ALBEDO = c;
}
