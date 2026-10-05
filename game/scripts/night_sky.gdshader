shader_type spatial;
// Full-moon night sky for the neighbourhood and the rice fields (0.7). Drawn on the camera-following
// dome built by scripts/neighborhood_builder.gd: a deep blue gradient, a big full moon (NASA LRO colour
// map, public domain) with limb darkening and a halo, about twenty fixed, slightly twinkling stars,
// moonlit clouds drifting past, and far mountain and tree-line silhouettes that melt into the fog
// colour, so the land under the sky dissolves into the same blue haze as the geometry.
// Clouds (0.8): after "AAA Fake Volumetric Clouds" by Velvet Katana Studios (CC0, see
// assets/fields/sky/clouds_velvetkatana_cc0.txt): a cloud deck of layered, domain-warped texture noise,
// thick bodies shadowed, thin edges and the parts near the moon lit silver, the moon veiled behind them.
// night_water.gdshader repeats sky_colour() so the paddies reflect exactly this sky.
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_opaque, skip_vertex_transform;

#include "res://scripts/night_common.gdshaderinc"

uniform float land_energy = 1.0;             // 0 hides the mountain / tree silhouettes
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_scale = 0.11;
uniform float cloud_softness = 0.16;
uniform vec2 cloud_direction = vec2(0.8, 0.35);
uniform vec3 cloud_dark : source_color = vec3(0.022, 0.027, 0.04);
uniform vec3 cloud_lit : source_color = vec3(0.12, 0.135, 0.175);

varying vec3 world_dir;

// Cloud deck: rgb colour, a coverage. Layers of the seamless noise (R big shapes, G detail, B warp)
// drift slowly and evolve; coverage comes from cloud_cover.
vec4 clouds(vec3 d, vec3 m, float up) {
	vec2 plane = d.xz / (up + 0.12);
	vec2 drift = normalize(cloud_direction) * TIME * cloud_speed;
	vec2 uv = plane * cloud_scale + drift;
	vec2 evolve = vec2(sin(TIME * 0.011), cos(TIME * 0.009)) * 0.05;
	vec2 warp = (texture(cloud_noise, uv * 0.5 + evolve).bb - 0.5) * 0.07;
	float base = texture(cloud_noise, uv + warp).r;
	float second = texture(cloud_noise, uv * 0.41 + vec2(0.23, 0.37) - evolve).r;
	float n = base * 0.6 + second * 0.4;
	float threshold = 1.0 - cloud_cover;
	float cover = smoothstep(threshold, threshold + cloud_softness, n);
	// Fine detail only frays the thin edges a little; it never shows inside the body.
	float detail = texture(cloud_noise, uv * 2.3 + warp + evolve).g;
	cover *= mix(1.0, smoothstep(0.15, 0.85, detail), 0.45 * (1.0 - cover));
	float thickness = smoothstep(threshold, threshold + cloud_softness * 3.0, n);
	// Fewer, fainter clouds toward the horizon, where the deck would stretch into streaks.
	cover *= smoothstep(0.04, 0.3, up);
	// Moonlight: thin parts and anything near the moon glow silver; thick bodies stay dark.
	float mc = max(dot(d, m), 0.0);
	float scatter = pow(mc, 6.0) * 0.45 + pow(mc, 50.0) * 1.2 + pow(mc, 600.0) * 2.0;
	vec3 col = mix(cloud_lit, cloud_dark, thickness * 0.75);
	col += halo_color * scatter * mix(1.0, 0.35, thickness);
	col = mix(horizon_color * 0.9, col, smoothstep(0.02, 0.35, up));
	return vec4(col, cover * 0.92);
}

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
	// A handful of fixed stars, dimmed by the moon's glare and the horizon haze.
	float moon_wash = 1.0 - smoothstep(0.8, 0.995, dot(d, m)) * 0.9;
	float haze = smoothstep(0.05, 0.3, up);
	float px = max(length(fwidth(d)), 0.0004);
	float star_light = night_stars(d, px) * star_energy * haze * moon_wash;
	if (up > 0.0) {
		vec4 cl = clouds(d, m, up);
		// Clouds hide the stars and the moon behind their thick parts; thin veils let a glow through.
		star_light *= 1.0 - cl.a;
		c = mix(c, cl.rgb, cl.a);
		moon_mask *= 1.0 - cl.a * mix(0.55, 0.97, cl.a);
	}
	c += vec3(0.85, 0.9, 1.0) * star_light;
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
