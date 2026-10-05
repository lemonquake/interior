shader_type spatial;
// Moonlit water for the rice paddies, the irrigation canal, the pond and road puddles (0.7). Built on the
// CC0 "Water Shader" by StayAtHomeDev (assets/fields/water/water_stayathomedev_cc0.gdshader): two
// scrolling normal maps, fresnel and a low roughness. Instead of screen and depth textures it reflects
// an analytic copy of the night sky (night_common.gdshaderinc), so the full moon, its halo and the
// stars show in every paddy on Forward+ and on the Android Compatibility renderer alike. Fine ripples
// break the moon's reflection into a glittering path; brief sparkles twinkle along it.
// Far away, paddies that hold rice turn from mirror to a fine field of rows (the near rice is real
// geometry, see field_blades.gdshader); fallow paddies stay mirrors all the way to the haze.
render_mode depth_draw_opaque, cull_back;

#include "res://scripts/night_common.gdshaderinc"

uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 wave_direction = vec2(0.9, 0.35);
uniform vec2 wave_direction2 = vec2(-0.3, 0.8);
uniform float time_scale = 0.018;
uniform float ripple_scale_a = 0.11;
uniform float ripple_scale_b = 0.29;
uniform float ripple_strength = 0.32;
uniform float wind_ripples = 0.6;          // extra ripple strength when the wind gusts (global wind_gust)
uniform vec3 water_color : source_color = vec3(0.006, 0.009, 0.012);
uniform float reflection_energy = 1.0;
uniform float glitter_energy = 4.0;
uniform float sparkle_energy = 16.0;
uniform bool reflect_stars = true;
// The paddy grid (same formula as InteriorFieldsBuilder.cell_state()).
uniform vec2 grid_origin = vec2(-150.0, 60.0);
uniform float cell_w = 28.0;
uniform float cell_h = 22.0;
uniform float rice_far_begin = 32.0;
uniform float rice_far_end = 60.0;
uniform vec3 rice_young : source_color = vec3(0.16, 0.24, 0.11);
uniform vec3 rice_ripe : source_color = vec3(0.32, 0.29, 0.14);
uniform vec4 pond = vec4(0.0, 0.0, 0.0, 0.0);   // centre x, z and radii x, z: open water, no rice
uniform bool paddies = true;                    // false: puddles and the pond (no rice rows at all)

global uniform float wind_gust;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 0 fallow mirror, 1 young rice, 2 ripe rice. Integer arithmetic only, so GDScript agrees exactly.
float cell_kind(vec2 p) {
	float i = floor((p.x - grid_origin.x) / cell_w);
	float offset = fract(i * 0.6180339) * cell_h;
	float j = floor((p.y - grid_origin.y - offset) / cell_h);
	float k = mod(i * 7.0 + j * 13.0 + mod(i * j, 5.0), 10.0);
	if (k < 3.0) {
		return 0.0;
	}
	if (k < 7.0 || k > 8.5) {
		return 1.0;
	}
	return 2.0;
}

void fragment() {
	vec2 uv = world_pos.xz;
	float gust = clamp(wind_gust, 0.0, 1.0);
	vec2 t1 = TIME * time_scale * wave_direction * (1.0 + gust);
	vec2 t2 = TIME * time_scale * wave_direction2 * (1.0 + gust * 0.6);
	vec3 na = texture(ripple_a, uv * ripple_scale_a + t1).rgb * 2.0 - 1.0;
	vec3 nb = texture(ripple_b, uv * ripple_scale_b + t2).rgb * 2.0 - 1.0;
	float strength = ripple_strength * (1.0 + gust * wind_ripples);
	vec2 slope = (na.xy + nb.xy) * strength;
	vec3 n = normalize(vec3(slope.x, 1.0, -slope.y));
	vec3 to_eye = CAMERA_POSITION_WORLD - world_pos;
	float dist = length(to_eye);
	vec3 v = to_eye / max(dist, 0.001);
	// Distant water calms down (the ripples average out): a cleaner mirror toward the horizon.
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), smoothstep(40.0, 220.0, dist) * 0.7));
	vec3 r = reflect(-v, n);
	r.y = abs(r.y);
	vec3 m = normalize(moon_direction);
	vec3 sky = sky_colour(r, true);
	if (reflect_stars) {
		sky += vec3(0.85, 0.9, 1.0) * stars(r, 160.0, star_density, 0.0) * star_energy * 0.6 * smoothstep(0.03, 0.3, r.y);
	}
	float cos_v = max(dot(n, v), 0.0);
	float fres = 0.02 + 0.98 * pow(1.0 - cos_v, 5.0);
	// Glitter path: the rippled reflection of the moon, broad and sharp parts.
	float rm = max(dot(r, m), 0.0);
	float glitter = pow(rm, 300.0) * 0.18 + pow(rm, 2600.0) * 2.2;
	float sparkle_noise = noise2(uv * 9.0 + vec2(TIME * 0.9, -TIME * 0.7)) * noise2(uv * 17.0 - vec2(TIME * 1.3, TIME * 0.4));
	float sparkle = smoothstep(0.6, 0.9, sparkle_noise) * pow(rm, 60.0);
	vec3 reflected = sky * fres * reflection_energy;
	reflected += moon_tint * (glitter * glitter_energy + sparkle * sparkle_energy) * (0.35 + fres);
	// Rice rows take over from the mirror with distance in planted paddies.
	float cover = 0.0;
	vec3 rice = rice_young;
	if (paddies) {
		float kind = cell_kind(uv);
		vec2 pd = (uv - pond.xy) / max(pond.zw, vec2(0.001));
		bool in_pond = pond.z > 0.0 && dot(pd, pd) < 1.0;
		if (kind > 0.5 && !in_pond) {
			float far = smoothstep(rice_far_begin, rice_far_end, dist);
			// Rows a quarter metre apart, with a little per-cell drift.
			float rows = 0.5 + 0.5 * sin(uv.x * 25.1 + sin(uv.y * 0.3) * 2.0);
			float clumps = noise2(uv * 6.0);
			float density = kind > 1.5 ? 0.97 : 0.8;
			cover = far * density * mix(0.65, 0.92, rows * clumps);
			rice = kind > 1.5 ? rice_ripe : rice_young;
			rice *= 0.7 + 0.5 * clumps;
		}
	}
	ALBEDO = mix(water_color, rice, cover);
	ROUGHNESS = mix(0.06, 0.85, cover);
	SPECULAR = mix(0.06, 0.2, cover);
	METALLIC = 0.0;
	EMISSION = reflected * (1.0 - cover);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
