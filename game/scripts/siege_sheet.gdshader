shader_type spatial;
// 0.23: the town's sheet-iron wall (scripts/town_siege.gd). Every sheet is real corrugated geometry (pitch 76 mm);
// this shader weathers it per sheet, from galvanised steel through orange bloom to deep brown rust, with faded roofing
// paint on some, rust running down from the nail heads along the rails, and mud splashed up from the ground.
// Vertex colour (set per sheet by the builder): r = rust (0..1), g = paint (0 none, else a palette index / 4),
// b = a random seed, a = how much the bottom edge has rotted.
// UV is in metres: x across the sheet, y up from its bottom edge. UV2.x is the sheet's height above the ground at
// its bottom edge, so the rails' nail rows land at the same heights on every sheet.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D galv_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D galv_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deep_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deep_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_galv = 2.0;
uniform float tile_rust = 1.4;
uniform float tile_deep = 2.0;
uniform float rail_low = 0.45;
uniform float rail_high = 2.02;
uniform vec3 paint_a : source_color = vec3(0.16, 0.27, 0.42);   // faded blue roofing paint
uniform vec3 paint_b : source_color = vec3(0.21, 0.33, 0.22);   // green
uniform vec3 paint_c : source_color = vec3(0.45, 0.13, 0.09);   // red oxide
uniform vec3 paint_d : source_color = vec3(0.62, 0.6, 0.55);    // white, chalked
uniform vec3 mud : source_color = vec3(0.16, 0.13, 0.09);

varying vec3 world_pos;
varying vec4 sheet;
varying float base_height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sheet = COLOR;
	base_height = UV2.x;
}

void fragment() {
	vec2 uv = UV;
	float seed = sheet.b * 37.0;
	vec3 galv = texture(galv_albedo, uv / tile_galv + seed).rgb;
	vec3 rust = texture(rust_albedo, uv / tile_rust + seed * 1.3).rgb;
	vec3 deep = texture(deep_albedo, uv / tile_deep + seed * .7).rgb;
	vec3 n_galv = texture(galv_normal, uv / tile_galv + seed).rgb;
	vec3 n_rust = texture(rust_normal, uv / tile_rust + seed * 1.3).rgb;
	vec3 n_deep = texture(deep_normal, uv / tile_deep + seed * .7).rgb;
	float h = base_height + uv.y;                     // height above the ground
	// Rust: the sheet's own amount, more toward the bottom edge and the overlaps, broken up by noise.
	float blotch = fbm(uv * vec2(2.2, 1.4) + seed);
	float edge = smoothstep(0.35, 0.0, uv.y) * 0.45 + smoothstep(0.25, 0.0, min(uv.x, 1.0)) * 0.1;
	float rust_amount = clamp(sheet.r + edge + (blotch - 0.5) * 0.9, 0.0, 1.0);
	// Nail rows along the rails: dark heads on every second crest, with rust run down below each.
	float nail = 0.0;
	float streak = 0.0;
	for (int k = 0; k < 2; k++) {
		float rail = k == 0 ? rail_low : rail_high;
		float dy = h - rail;
		float col = fract(uv.x / 0.152 + 0.25) - 0.5;
		float id = floor(uv.x / 0.152 + 0.25);
		float keep = step(0.35, hash(vec2(id, seed + float(k))));
		nail = max(nail, keep * smoothstep(0.012, 0.006, length(vec2(col * 0.152, dy))));
		float below = smoothstep(0.0, -0.02, dy) * smoothstep(-0.55 - 0.4 * hash(vec2(id, seed)), -0.05, dy);
		streak = max(streak, keep * below * smoothstep(0.022, 0.0, abs(col * 0.152 + sin(dy * 31.0) * 0.003)));
	}
	rust_amount = clamp(rust_amount + streak * 0.8, 0.0, 1.0);
	float bloom = smoothstep(0.25, 0.55, rust_amount);
	float heavy = smoothstep(0.62, 0.9, rust_amount);
	// Old galvanising goes dull grey, never mirror-bright; rain streaks and grime run down from the top.
	float streaks = fbm(vec2(uv.x * 11.0 + seed, uv.y * 0.35));
	float grime = smoothstep(0.35, 0.8, streaks) * (0.35 + 0.65 * smoothstep(0.2, 1.6, uv.y));
	vec3 albedo = mix(galv * vec3(0.43, 0.44, 0.45), rust * vec3(0.72, 0.62, 0.55), bloom);
	albedo = mix(albedo, deep * 0.7, heavy);
	albedo *= 1.0 - grime * 0.45;
	vec3 nmap = mix(n_galv, n_rust, bloom);
	nmap = mix(nmap, n_deep, heavy);
	// Paint (roofing enamel, chalked by the sun) flakes off where the rust has come through.
	if (sheet.g > 0.05) {
		vec3 paint = sheet.g < 0.3 ? paint_a : (sheet.g < 0.55 ? paint_b : (sheet.g < 0.8 ? paint_c : paint_d));
		float chalk = 0.75 + 0.35 * fbm(uv * 3.0 + seed * 2.0);
		float flake = smoothstep(0.42, 0.62, rust_amount + (fbm(uv * 9.0 + seed) - 0.5) * 0.5);
		albedo = mix(paint * chalk * (0.8 + 0.4 * galv.r), albedo, flake);
	}
	// Dirt: dust in the troughs, mud splashed up from the ground, the bottom edge rotted dark.
	float splash = smoothstep(0.55 + 0.25 * fbm(uv * 4.0 + seed), 0.0, h);
	albedo = mix(albedo, mud, splash * 0.85);
	albedo *= mix(1.0, 0.45, smoothstep(0.08, 0.0, uv.y) * sheet.a);
	albedo = mix(albedo, vec3(0.03, 0.028, 0.025), nail);
	albedo = mix(albedo, albedo * vec3(0.55, 0.32, 0.2), streak * 0.7);
	ALBEDO = albedo;
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = 1.0;
	METALLIC = mix(0.3, 0.04, max(max(bloom, splash), grime));
	ROUGHNESS = clamp(mix(0.62, 0.94, bloom) + splash * 0.2 + grime * 0.2, 0.0, 1.0);
}
