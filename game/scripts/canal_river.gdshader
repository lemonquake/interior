shader_type spatial;
// The canal river (0.17): slow, filthy water in a ravine. Two scrolling ripple maps drift with the
// current (south), oily scum and foam collect in patches and along the banks, and the near-mirror surface
// takes its reflections from the box-projected ReflectionProbes (houses, bulbs) plus the analytic night
// sky from night_common, dimmed where the ravine walls and the overhanging shanties hide the sky.
render_mode depth_draw_opaque, cull_back;

#include "res://scripts/night_common.gdshaderinc"

global uniform float wind_gust;

uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 water_color : source_color = vec3(0.016, 0.019, 0.011);
uniform vec3 scum_color : source_color = vec3(0.07, 0.07, 0.04);
uniform float flow_speed = 0.035;
uniform float ripple_strength = 0.045;
uniform float sky_reflection = 0.55;
uniform float glitter_energy = 0.35;

varying vec3 world_pos;
varying float across;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	across = UV.x;
}

void fragment() {
	vec2 p = world_pos.xz;
	float gust = clamp(wind_gust, 0.0, 1.0);
	vec2 flow = vec2(0.0, -TIME * flow_speed);
	vec3 na = texture(ripple_a, p * vec2(0.18, 0.09) + flow).rgb * 2.0 - 1.0;
	vec3 nb = texture(ripple_b, p * vec2(0.37, 0.21) + flow * 1.7 + vec2(TIME * 0.004, 0.0)).rgb * 2.0 - 1.0;
	float strength = ripple_strength * (1.0 + gust * 1.5);
	// Scum: a slow-moving oily film, thicker in the margins and caught on the stilts.
	float edge = smoothstep(1.6, 3.6, across) + smoothstep(-3.0, -5.2, across);
	float film = fbm(p * vec2(0.45, 0.2) + flow * 2.0);
	float scum = clamp(smoothstep(0.52, 0.75, film) * 0.7 + edge * 0.45 * smoothstep(0.3, 0.6, film), 0.0, 1.0);
	vec2 slope = (na.xy + nb.xy) * strength * (1.0 - scum * 0.7);
	vec3 n = normalize(vec3(slope.x, 1.0, -slope.y));
	vec3 to_eye = CAMERA_POSITION_WORLD - world_pos;
	vec3 v = to_eye / max(length(to_eye), 0.001);
	vec3 r = reflect(-v, n);
	r.y = abs(r.y);
	// Open sky only shows down the middle; the east side is under the shanties.
	float open_sky = smoothstep(-5.5, -2.0, across) * (1.0 - smoothstep(-0.5, 3.0, across)) * 0.85 + 0.15;
	open_sky *= smoothstep(0.05, 0.5, r.y);
	float cos_v = max(dot(n, v), 0.0);
	float fres = 0.02 + 0.98 * pow(1.0 - cos_v, 5.0);
	vec3 m = normalize(moon_direction);
	float rm = max(dot(r, m), 0.0);
	vec3 reflected = sky_colour(r, true) * fres * sky_reflection * open_sky;
	reflected += moon_tint * (pow(rm, 400.0) * 0.2 + pow(rm, 3000.0) * 1.6) * glitter_energy * open_sky;
	ALBEDO = mix(water_color, scum_color, scum);
	ROUGHNESS = mix(0.035, 0.55, scum);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	EMISSION = reflected * (1.0 - scum * 0.8);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
