shader_type spatial;
// Old house paint on plywood and plaster in the abandoned canal settlement (0.17). The photographed
// peeling-paint map supplies cracks and flaked patches; its colour is replaced by the house's own faded
// tint, flakes show the grey substrate, and grime runs down from the top of each wall and up from the
// damp ground. UVs are metres (kit models), so the map is scaled by `tile`.
render_mode cull_back;

uniform sampler2D paint_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paint_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.7, 0.6, 0.3);
uniform float tile = 2.2;
uniform float ground_y = -2.1;

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV / tile;
	vec3 src = texture(paint_map, uv).rgb;
	// The source photo is salmon paint with grey flaked patches: chroma tells the two apart.
	float chroma = max(src.r - src.b, 0.0);
	float painted = smoothstep(0.04, 0.16, chroma);
	float lum = dot(src, vec3(0.3, 0.59, 0.11));
	vec3 colour = mix(vec3(lum * 0.5), tint * (0.42 + lum * 0.7), painted);
	// Rain grime: streaks hanging from above, blotches, and rising damp near the ground.
	float streak = vn(vec2((wp.x + wp.z) * 6.0, wp.y * 0.35)) * vn(vec2((wp.x - wp.z) * 17.0, wp.y * 0.9));
	colour *= mix(1.0, 0.45, smoothstep(0.3, 0.7, streak));
	colour *= mix(1.0, 0.6, smoothstep(0.55, 0.85, vn(wp.xz * 0.8 + wp.y * 0.5)));
	float damp = 1.0 - smoothstep(0.0, 0.9, wp.y - ground_y + (vn(wp.xz * 3.0) - 0.5) * 0.4);
	colour = mix(colour, colour * vec3(0.35, 0.33, 0.25), damp);
	ALBEDO = colour * 0.85;
	ROUGHNESS = mix(0.95, 0.75, painted);
	NORMAL_MAP = texture(paint_normal, uv).rgb;
}
