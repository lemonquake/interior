// Shared by night_sky.gdshader (the dome) and night_water.gdshader (paddies, canal, pond): the same moon,
// stars and sky gradient, so every reflection matches the sky above it. Values are set by InteriorNight.
uniform sampler2D moon_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 moon_direction = vec3(-0.539, 0.342, 0.770);
uniform float moon_radius = 0.028;          // radians (about 3.2 degrees across: a dramatic, low moon)
uniform float moon_energy = 5.5;
uniform vec3 moon_tint : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 zenith_color : source_color = vec3(0.004, 0.007, 0.02);
uniform vec3 sky_color : source_color = vec3(0.012, 0.02, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.06, 0.075, 0.105);
uniform vec3 halo_color : source_color = vec3(0.35, 0.42, 0.55);
uniform float star_density = 0.11;
uniform float star_energy = 2.2;
uniform float cloud_cover = 0.38;
uniform float cloud_speed = 0.004;


float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise2(p) * a;
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

float ridge(float x) {
	// 1D fbm over the azimuth for the mountain line (periodic around the horizon).
	float v = 0.0;
	float a = 0.5;
	float f = 1.0;
	for (int i = 0; i < 5; i++) {
		float xi = x * f;
		float i0 = floor(xi);
		float t = fract(xi);
		t = t * t * (3.0 - 2.0 * t);
		v += mix(hash11(i0), hash11(i0 + 1.0), t) * a;
		f *= 2.1;
		a *= 0.5;
	}
	return v;
}

// One layer of stars: a random point in each cell of a cube-projected grid.
float stars(vec3 d, float scale, float density, float time_offset) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float h = hash13(cell);
	if (h > density) {
		return 0.0;
	}
	vec3 jitter = vec3(hash13(cell + 11.3), hash13(cell + 37.9), hash13(cell + 71.1));
	vec3 star_pos = normalize(cell + 0.15 + jitter * 0.7);
	float dist = length(normalize(d) - star_pos) * scale;
	float size = mix(0.012, 0.045, pow(hash13(cell + 5.7), 6.0));
	float core = smoothstep(size, 0.0, dist);
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.3 + h * 7.0) + h * 91.0 + time_offset);
	float brightness = mix(0.25, 1.0, pow(hash13(cell + 2.1), 3.0));
	return core * brightness * twinkle;
}

vec3 moon_disc(vec3 d, vec3 m, out float mask) {
	float c = dot(d, m);
	float ang = acos(clamp(c, -1.0, 1.0));
	mask = 1.0 - smoothstep(moon_radius * 0.96, moon_radius, ang);
	if (mask <= 0.0) {
		return vec3(0.0);
	}
	// Point on the visible hemisphere of the moon, in a frame facing the viewer.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), m));
	vec3 up = cross(m, right);
	vec2 q = vec2(dot(d, right), dot(d, up)) / sin(moon_radius);
	float r2 = dot(q, q);
	float z = sqrt(max(0.0, 1.0 - r2));
	// Longitude / latitude of the near side (equirectangular LRO map centred on longitude 0).
	float lon = atan(q.x, z);
	float lat = asin(clamp(q.y, -1.0, 1.0));
	vec2 uv = vec2(0.5 + lon / TAU, 0.5 - lat / PI);
	vec3 albedo = texture(moon_texture, uv).rgb;
	float limb = mix(0.55, 1.0, pow(z, 0.45));
	return albedo * limb * moon_tint * moon_energy * 1.6;
}

vec3 sky_colour(vec3 d, bool with_moon_disc) {
	vec3 m = normalize(moon_direction);
	float up = clamp(d.y, -1.0, 1.0);
	vec3 c = mix(horizon_color, sky_color, smoothstep(0.0, 0.28, up));
	c = mix(c, zenith_color, smoothstep(0.25, 0.95, up));
	float mc = max(dot(d, m), 0.0);
	// Moonlit haze: a broad glow around the moon and a brighter horizon under it.
	c += halo_color * (pow(mc, 12.0) * 0.08 + pow(mc, 90.0) * 0.18 + pow(mc, 900.0) * 0.6);
	c += halo_color * 0.05 * pow(max(dot(normalize(vec3(d.x, 0.0, d.z) + vec3(0.0001)), normalize(vec3(m.x, 0.0, m.z))), 0.0), 6.0) * (1.0 - smoothstep(0.0, 0.35, up));
	if (with_moon_disc) {
		float mask;
		vec3 disc = moon_disc(d, m, mask);
		c = mix(c, disc, mask);
	}
	return c;
}

