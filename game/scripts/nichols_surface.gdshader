shader_type spatial;
// 0.21 Nichols house: a photographic PBR surface aged in place. UVs are world metres (u along the surface, v up for
// walls, so v is the height above the ground-floor boards). Layers, all from one shared noise texture:
// - paint: a coat of paint over the base that has flaked off in patches, with dark lifted edges;
// - grime: mottled darkening; streaks: vertical run-off below sills and cornices;
// - damp: rising damp and moss near `base_height`; dust: a grey film on upward faces (floors, treads, ledges).
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile = 1.0;
uniform float normal_strength = 1.0;
uniform float rough_bias = 0.0;
uniform vec3 paint_color : source_color = vec3(0.7);
uniform float paint_amount = 0.0;
uniform float paint_scale = 0.55;
uniform float grime = 0.4;
uniform float streaks = 0.0;
uniform float damp = 0.0;
uniform float damp_height = 0.8;
uniform float base_height = 0.0;
uniform vec3 damp_color : source_color = vec3(0.07, 0.09, 0.05);
uniform float dust = 0.0;
uniform vec3 dust_color : source_color = vec3(0.47, 0.45, 0.41);
uniform float metallic = 0.0;

float n1(vec2 p) { return texture(noise_tex, p).r; }
float fbm(vec2 p) { return n1(p) * .55 + n1(p * 2.31 + .37) * .3 + n1(p * 5.17 + .71) * .15; }

void fragment() {
	vec2 uv = UV / tile;
	vec3 base = texture(albedo_tex, uv).rgb * tint;
	vec3 nrm = texture(normal_tex, uv).rgb;
	float rough = texture(rough_tex, uv).g;
	vec2 w = UV;
	float g = fbm(w * .11);
	float fine = n1(w * .9);
	// Paint coat, flaked off where the noise is low; a dark rim marks the lifted edge.
	if (paint_amount > 0.0) {
		// Coverage varies by area (weathered patches), the flakes themselves are small.
		float zone = fbm(w * paint_scale * .45);
		float flake = n1(w * paint_scale * 4.5) * .6 + n1(w * paint_scale * 11.0 + .3) * .4;
		float cover = clamp(paint_amount + (zone - .5) * 1.3, 0.0, 1.0);
		float m = smoothstep(1.0 - cover - .025, 1.0 - cover + .025, flake);
		float rim = smoothstep(1.0 - cover - .07, 1.0 - cover - .025, flake) * (1.0 - m);
		vec3 painted = paint_color * (.78 + .32 * dot(base, vec3(.33)) / max(dot(tint, vec3(.33)), .05));
		base = mix(base * (1.0 - rim * .55), painted, m);
		nrm = mix(nrm, vec3(.5, .5, 1.0), m * .65);
		rough = mix(rough, .82, m);
	}
	float wl = mix(1.0, .5 + .6 * g, grime);
	if (streaks > 0.0) {
		float s = n1(vec2(w.x * 2.7, w.y * .06)) * n1(vec2(w.x * 7.3 + .3, w.y * .11));
		wl *= 1.0 - streaks * smoothstep(.12, .45, s) * .55;
	}
	base *= wl;
	if (damp > 0.0) {
		float h = w.y - base_height;
		float edge = damp_height * (.55 + .9 * g);
		float d = (1.0 - smoothstep(edge * .6, edge, h)) * damp;
		base = mix(base, damp_color * (.6 + .8 * fine), d * .8);
		rough = mix(rough, .95, d);
	}
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (dust > 0.0) {
		float up = smoothstep(.55, .9, world_n.y);
		float dm = up * dust * (.55 + .6 * fbm(w * .37));
		base = mix(base, dust_color * (.85 + .3 * fine), clamp(dm, 0.0, .85));
		rough = mix(rough, 1.0, dm);
		nrm = mix(nrm, vec3(.5, .5, 1.0), dm * .7);
	}
	ALBEDO = base;
	ROUGHNESS = clamp(rough + rough_bias, .05, 1.0);
	METALLIC = metallic;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength;
}
