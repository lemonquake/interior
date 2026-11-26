shader_type spatial;
// Ravine ground of the canal settlement (0.17): one river-aligned heightfield, textured in world space.
// Photographic Poly Haven maps are blended by height, slope and position across the river:
// stained concrete on the east retaining wall (runoff streaks, a black-green tide line, slime at the
// foot), trodden mud on the lanes and the far-bank path, withered weeds on the high ground, dark wet
// silt under and beside the water. No hard seams: every blend is noise-broken and smooth.
render_mode cull_back;

uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D track_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D track_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float water_y = -6.0;
uniform float floor_y = -2.1;

varying vec3 wp;
varying vec3 wn;

float river_x(float z) {
	return -66.0 + 2.4 * sin((z - 4.0) * 0.052);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.13) * 0.3 + vnoise(p * 4.7) * 0.15;
}

// Rubble masonry for the east retaining wall: irregular stones in dark mortar (cellular noise on the
// wall plane). Returns stone mask in x, cell id hash in y, gradient toward mortar in zw.
vec4 masonry(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	vec2 dir = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3)) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; best = i + g; dir = r; }
			else if (d < d2) { d2 = d; }
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float stone = smoothstep(0.03, 0.14, edge);
	return vec4(stone, hash(best * 1.7), -normalize(dir + 1e-4) * (1.0 - stone));
}

// Biplanar-style sample: top projection for flat ground, side projections for steep faces.
void tri(sampler2D alb, sampler2D nrm, float scale, vec3 w, out vec3 a, out vec3 n) {
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec2 uy = wp.xz * scale;
	vec2 ux = wp.zy * scale;
	vec2 uz = wp.xy * scale;
	a = texture(alb, uy).rgb * bw.y + texture(alb, ux).rgb * bw.x + texture(alb, uz).rgb * bw.z;
	vec3 ty = texture(nrm, uy).rgb * 2.0 - 1.0;
	vec3 tx = texture(nrm, ux).rgb * 2.0 - 1.0;
	vec3 tz = texture(nrm, uz).rgb * 2.0 - 1.0;
	vec3 ny = vec3(ty.x + wn.x, abs(ty.z) * wn.y, ty.y + wn.z);
	vec3 nx = vec3(abs(tx.z) * wn.x, tx.y + wn.y, tx.x + wn.z);
	vec3 nz = vec3(tz.x + wn.x, tz.y + wn.y, abs(tz.z) * wn.z);
	n = normalize(nx * bw.x + ny * bw.y + nz * bw.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float u = wp.x - river_x(wp.z);
	float big = fbm(wp.xz * 0.18);
	float fine = fbm(wp.xz * 1.3);
	float flat_ = smoothstep(0.55, 0.9, wn.y);
	vec3 a_mud; vec3 n_mud;
	tri(mud_albedo, mud_normal, 1.0 / 1.7, wp, a_mud, n_mud);
	vec3 a_trk; vec3 n_trk;
	tri(track_albedo, track_normal, 1.0 / 2.8, wp, a_trk, n_trk);
	vec3 a_grs; vec3 n_grs;
	tri(grass_albedo, grass_normal, 1.0 / 1.6, wp, a_grs, n_grs);
	vec3 a_wal; vec3 n_wal;
	tri(wall_albedo, wall_normal, 1.0 / 1.3, wp, a_wal, n_wal);
	vec3 a_rck; vec3 n_rck;
	tri(rock_albedo, rock_normal, 1.0 / 1.4, wp, a_rck, n_rck);

	// High ground: the lanes and path are trodden mud; the far bank and verges carry dead weeds.
	float lane = smoothstep(5.0, 6.5, u) * (1.0 - smoothstep(22.0, 24.0, u));
	float path = smoothstep(-8.4, -7.6, u) * (1.0 - smoothstep(-6.4, -5.8, u));
	float weeds = clamp((1.0 - lane) * (1.0 - path) * smoothstep(0.35, 0.6, big + 0.15), 0.0, 1.0);
	weeds = max(weeds, lane * smoothstep(0.72, 0.85, big) * 0.6);
	vec3 albedo = mix(a_mud, a_trk, clamp(lane + path, 0.0, 1.0) * 0.8);
	vec3 n = normalize(mix(n_mud, n_trk, clamp(lane + path, 0.0, 1.0) * 0.8));
	albedo = mix(albedo, a_grs * vec3(0.8, 0.85, 0.7), weeds * flat_);
	n = normalize(mix(n, n_grs, weeds * flat_));
	// Steep faces: the east bank is a stained concrete wall; the far bank's steep bits are broken earth.
	float steep = 1.0 - flat_;
	float east_wall = smoothstep(4.6, 5.4, u);
	vec3 wall = a_wal * vec3(0.78, 0.78, 0.72);
	// Runoff: vertical streaks from the drains and the rain.
	float streak = vnoise(vec2(wp.x * 3.1 + wp.z * 3.1, wp.y * 0.25)) * vnoise(vec2((wp.x + wp.z) * 11.0, wp.y * 0.6));
	wall *= mix(1.0, 0.45, smoothstep(0.25, 0.6, streak));
	wall = mix(wall, vec3(0.13, 0.12, 0.08), smoothstep(0.5, 0.8, fine) * 0.4);
	vec3 rough_rock = mix(a_rck * vec3(0.55, 0.5, 0.42), a_mud, 0.4);
	vec3 battered = mix(wall, rough_rock * 0.8, smoothstep(0.35, 0.65, big + fine * 0.4 - 0.2));
	// Rubble stones laid in mortar, patched with concrete where the wall was repaired.
	vec2 along = vec2(wp.z + wp.x * 0.3, wp.y * 1.35) / 0.42;
	vec4 mason = masonry(along);
	vec3 stone_col = a_rck * mix(0.45, 0.85, mason.y) * vec3(0.95, 0.92, 0.85);
	vec3 mortar = vec3(0.05, 0.05, 0.04);
	vec3 rubble_wall = mix(mortar, stone_col, mason.x);
	float patch_ = smoothstep(0.55, 0.62, vnoise(wp.zy * 0.35 + 7.0));
	battered = mix(rubble_wall, battered, patch_) * mix(1.0, 0.45, smoothstep(0.25, 0.6, streak));
	vec3 steep_col = mix(rough_rock, battered * 0.75, east_wall);
	vec3 wall_dir = normalize(vec3(-1.0, 0.0, 0.0));
	vec3 mason_n = normalize(n_rck + (vec3(mason.z * 0.3, mason.w * 0.6, mason.z * 0.6) + wall_dir * 0.0) * (1.0 - patch_));
	vec3 steep_n = normalize(mix(n_rck, mason_n, east_wall));
	albedo = mix(albedo, steep_col, steep);
	n = normalize(mix(n, steep_n, steep));
	// Rubble slope under the catwalk: broken concrete in black mud.
	float rubble = smoothstep(3.7, 4.1, u) * (1.0 - smoothstep(5.45, 5.6, u)) * flat_;
	albedo = mix(albedo, mix(a_rck * 0.5, a_mud * 0.35, smoothstep(0.4, 0.6, fine)), rubble);

	// Water: the tide line, slime and wet silt. Heights are broken by noise so no line is ruler-straight.
	float h = wp.y - water_y + (big - 0.5) * 0.25;
	float wet = 1.0 - smoothstep(0.1, 0.9, h);
	float tide = smoothstep(0.0, 0.25, h) * (1.0 - smoothstep(0.9, 1.6, h)) * steep;
	float slime = 1.0 - smoothstep(-0.15, 0.35, h);
	albedo = mix(albedo, albedo * 0.38, wet);
	albedo = mix(albedo, vec3(0.035, 0.045, 0.025), tide * 0.85);
	albedo = mix(albedo, vec3(0.03, 0.04, 0.02) + a_mud * 0.08, slime);
	// General filth: dark blotches and oil stains on the lanes.
	albedo *= mix(1.0, 0.55, smoothstep(0.55, 0.85, fbm(wp.xz * 0.7 + 13.0)) * (1.0 - steep));
	ALBEDO = albedo * 0.9;
	ROUGHNESS = mix(0.95, 0.3, max(wet, slime * 0.9));
	SPECULAR = mix(0.3, 0.55, wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
