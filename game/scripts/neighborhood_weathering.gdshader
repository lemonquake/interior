shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Original photographic PBR set. UVs in the baked meshes are authored in metres.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D substrate_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D substrate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D substrate_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(0.4);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform float base_roughness = 1.0;
uniform float base_metallic = 0.0;
uniform float base_specular = 0.5;
uniform float normal_strength = 1.0;
uniform bool has_albedo = true;
uniform bool has_normal = true;
uniform bool has_roughness = true;
// 0: masonry/plaster, 1: asphalt, 2: pavement, 3: metal, 4: timber.
uniform int surface_kind = 0;
uniform float wear : hint_range(0.0, 1.0) = 0.7;
uniform float dirt : hint_range(0.0, 1.0) = 0.8;
uniform float cracks : hint_range(0.0, 1.0) = 0.7;
uniform float damp : hint_range(0.0, 1.0) = 0.8;
uniform float substrate_scale = 0.4;
uniform float ground_y = -2.9;
uniform float seed = 0.0;
uniform bool road_paint = false;

varying vec3 weather_position;
varying vec3 weather_normal;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), u.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), u.x), u.y);
}

float layered_noise(vec2 p) {
	return noise21(p) * 0.57 + noise21(p * 2.13 + 17.2) * 0.28 + noise21(p * 4.61 - 9.3) * 0.15;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0);
	return length(p - a - ab * t);
}

// Sparse independent settlement fractures, never a Voronoi web. Each fracture has an uneven
// five-point path and one shorter branch; many cells deliberately contain no damage at all.
vec2 fracture(vec2 p, float coverage, float width) {
	vec2 cell = floor(p);
	vec2 q = fract(p) - 0.5;
	float r = hash21(cell + 11.1);
	float active = step(1.0 - coverage, r);
	float angle = hash21(cell + 37.9) * 6.2831853;
	q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * q;
	float length_scale = mix(0.48, 0.95, hash21(cell - 7.3));
	q.y /= length_scale;
	vec2 a = vec2((hash21(cell + 3.1) - 0.5) * 0.11, -0.37);
	vec2 b = vec2((hash21(cell + 4.2) - 0.5) * 0.16, -0.18);
	vec2 c = vec2((hash21(cell + 5.3) - 0.5) * 0.12, 0.01);
	vec2 d = vec2((hash21(cell + 6.4) - 0.5) * 0.16, 0.18);
	vec2 e = vec2((hash21(cell + 7.5) - 0.5) * 0.13, 0.37);
	// Sub-centimetre edge meander breaks the mathematically straight segment silhouettes.
	q.x += (noise21(vec2(q.y * 57.0, r * 19.0)) - 0.5) * 0.007;
	float distance = min(min(segment_distance(q, a, b), segment_distance(q, b, c)),
		min(segment_distance(q, c, d), segment_distance(q, d, e)));
	float branch = min(segment_distance(q, c, c + vec2(0.13, 0.085)),
		segment_distance(q, c + vec2(0.13, 0.085), c + vec2(0.25, 0.21)));
	distance = min(distance, branch + width * 0.32);
	float taper = 1.0 - smoothstep(0.27, 0.38, abs(q.y));
	float antialias = max(length(fwidth(p)) * 0.52, 0.00012);
	float core = 1.0 - smoothstep(width * taper, width * taper + antialias, distance);
	float lip = 1.0 - smoothstep(width * 3.5, width * 3.5 + antialias, distance);
	return vec2(core * taper, lip) * active;
}

void vertex() {
	weather_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	weather_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 world_n = normalize(weather_normal);
	float horizontal = smoothstep(0.55, 0.9, abs(world_n.y));
	vec2 face = abs(world_n.x) > abs(world_n.z) ? weather_position.zy : weather_position.xy;
	face = mix(face, weather_position.xz, horizontal);
	vec2 p = face + vec2(seed * 4.37, seed * 1.91);
	vec2 uv = UV * uv_scale + uv_offset;
	vec2 under_uv = UV * substrate_scale + vec2(0.271, 0.139);
	vec3 photo = has_albedo ? texture(albedo_map, uv).rgb : vec3(1.0);
	vec3 color = photo * base_color.rgb;
	float rough = base_roughness * (has_roughness ? dot(texture(roughness_map, uv), roughness_channel) : 1.0);
	vec2 photo_normal = has_normal ? texture(normal_map, uv).rg * 2.0 - 1.0 : vec2(0.0);
	photo_normal *= normal_strength;
	float macro = layered_noise(p * 0.24);
	float grain = noise21(p * 19.0 + 11.7);
	// The shared white trim batch also contains road markings. Abrade only those at road level.
	if (road_paint && horizontal > 0.9 && weather_position.y < ground_y + 0.065) {
		float erased = noise21(weather_position.xz * 8.0) * 0.6 + noise21(weather_position.xz * 43.0) * 0.4;
		if (erased > 0.53) { discard; }
		color *= 0.67;
	}
	float broken = layered_noise(p * 2.7 + vec2(macro * 2.3));
	float age = layered_noise(p * 0.61 + vec2(13.3, -8.1));
	float base_height = max(weather_position.y - ground_y, 0.0);
	float runoff = smoothstep(0.50, 0.83, noise21(vec2(p.x * 6.2, p.y * 0.22)) * 0.65
		+ noise21(vec2(p.x * 19.0, p.y * 0.47)) * 0.35);
	float runoff_mask = runoff * (0.3 + 0.7 * macro) * (1.0 - horizontal) * dirt;
	float tide_height = 0.24 + layered_noise(weather_position.xz * 0.57 + seed) * 1.10;
	float tide = (1.0 - smoothstep(tide_height - 0.24, tide_height + 0.19, base_height)) * (1.0 - horizontal) * damp;
	float moss = tide * smoothstep(0.37, 0.72, broken) * (0.4 + 0.6 * grain);
	float exposed = 0.0;
	float wet = 0.0;
	vec2 fissure = vec2(0.0);
	vec3 under = texture(substrate_albedo, under_uv).rgb;
	float under_rough = texture(substrate_roughness, under_uv).g;
	float dust = smoothstep(0.40, 0.77, macro) * dirt;
	if (surface_kind == 1 || surface_kind == 2) {
		// Ground wear is patchy and broad. Aggregate stays matte; only settled damp is smoother.
		exposed = smoothstep(0.50, 0.72, age * 0.61 + broken * 0.39) * wear;
		float wet_mask = layered_noise(weather_position.xz * 0.34 + vec2(7.9, 19.8));
		wet = smoothstep(0.58, 0.77, wet_mask) * damp;
		fissure = fracture(p / (surface_kind == 1 ? 3.7 : 2.6), surface_kind == 1 ? 0.54 : 0.35,
			surface_kind == 1 ? 0.0024 : 0.0014) * cracks;
		under *= surface_kind == 1 ? vec3(0.77, 0.72, 0.64) : vec3(0.79, 0.75, 0.66);
		color = mix(color, under, exposed);
		color *= mix(0.72, 1.13, macro);
		color = mix(color, color * vec3(0.76, 0.68, 0.54) + vec3(0.022, 0.018, 0.009), dust * 0.35);
		color = mix(color, color * 0.39, wet);
		// Tiny pale chips edge the asphalt; the core remains dark earth, not painted black lines.
		color = mix(color, color * 0.71 + vec3(0.028, 0.024, 0.015), fissure.y * 0.34);
		color = mix(color, vec3(0.020, 0.017, 0.012), fissure.x * 0.82);
		rough = mix(rough, under_rough, exposed);
		rough = mix(max(rough, 0.76), 0.37, wet);
	} else if (surface_kind == 3) {
		// Rust exposes oxidised metal in irregular islands while preserving photographed ridges.
		exposed = smoothstep(0.44, 0.68, age * 0.67 + broken * 0.33) * wear;
		color = mix(color, under * vec3(0.88, 0.81, 0.68), exposed);
		color *= mix(0.67, 1.03, macro);
		color *= 1.0 - runoff_mask * 0.36 - tide * 0.20;
		rough = mix(max(rough, 0.46), max(under_rough, 0.86), exposed);
	} else {
		float flake_field = age * 0.42 + broken * 0.46 + grain * 0.12;
		float flake_threshold = mix(0.68, 0.48, wear);
		exposed = smoothstep(flake_threshold, flake_threshold + 0.055, flake_field) * wear;
		float chipped_edge = smoothstep(flake_threshold - 0.024, flake_threshold, flake_field)
			* (1.0 - smoothstep(flake_threshold, flake_threshold + 0.037, flake_field)) * wear;
		under *= surface_kind == 4 ? vec3(0.71, 0.66, 0.56) : vec3(0.68, 0.66, 0.57);
		color = mix(color, under, exposed);
		color *= mix(0.69, 1.06, macro);
		color *= 1.0 - runoff_mask * 0.57 - chipped_edge * 0.25;
		color = mix(color, color * vec3(0.43, 0.44, 0.35), tide * 0.67);
		color = mix(color, color * vec3(0.48, 0.57, 0.31) + vec3(0.008, 0.012, 0.003), moss * 0.47);
		float salt = (1.0 - smoothstep(0.055, 0.18, abs(base_height - tide_height)))
			* (1.0 - horizontal) * damp * smoothstep(0.39, 0.69, broken);
		color = mix(color, color * 1.22 + vec3(0.035, 0.030, 0.020), salt * 0.23);
		fissure = fracture(p / 3.3, 0.32, 0.0009) * cracks * (1.0 - horizontal * 0.72);
		color *= 1.0 - fissure.y * 0.15;
		color = mix(color, vec3(0.035, 0.031, 0.024), fissure.x * 0.75);
		rough = mix(rough, under_rough, exposed);
		rough = max(rough, 0.79 - tide * 0.18);
	}
	// Both photographic sets share the mesh UV basis. Never mix a world-space normal directly
	// into a tangent-space normal: this keeps relief correctly lit on every street orientation.
	vec2 substrate_n = texture(substrate_normal, under_uv).rg * 2.0 - 1.0;
	vec2 tangent_xy = mix(photo_normal, substrate_n, exposed * 0.68);
	float tangent_z = sqrt(max(1.0 - dot(tangent_xy, tangent_xy), 0.001));
	NORMAL_MAP = vec3(tangent_xy * 0.5 + 0.5, tangent_z * 0.5 + 0.5);
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = clamp(color, vec3(0.008), vec3(0.96));
	ROUGHNESS = clamp(rough + grain * 0.035, 0.29, 0.98);
	METALLIC = base_metallic * (1.0 - exposed * 0.90);
	SPECULAR = base_specular;
	AO = clamp(1.0 - fissure.x * 0.23 - exposed * 0.08, 0.65, 1.0);
	AO_LIGHT_AFFECT = 0.25;
}
