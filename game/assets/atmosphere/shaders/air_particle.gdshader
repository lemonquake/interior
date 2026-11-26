shader_type spatial;
// Soft, lit atmospheric sprites. Depth fading uses Godot 4 reverse-Z projection.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.72, 0.77, 0.83, 0.12);
uniform float presence = 1.0;
uniform float elapsed = 0.0; // Supplied by the pausable controller, rather than global shader TIME.
uniform float glow = 0.0;
uniform float softness = 0.5;
uniform int shape = 0; // 0: dust, 1: ground wisp, 2: moth
uniform float ground_y = -2.9;
uniform bool exclude_hut = false;
uniform mat4 hut_inverse;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
#endif
varying float particle_id;
varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), u.x), u.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	particle_id = float(INSTANCE_ID);
	world_position = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float alpha = exp(-dot(p, p) * 5.5) * (1.0 - smoothstep(0.64, 1.0, dot(p, p)));
	if (shape == 1) {
		vec2 drift = vec2(elapsed * 0.018, elapsed * -0.009) + vec2(particle_id * 0.173);
		float clouds = noise(UV * 3.7 + drift) * 0.68 + noise(UV * 8.1 - drift) * 0.32;
		alpha *= smoothstep(0.17, 0.74, clouds);
		// No sprite ends below the road or extends as a vertical veil into the rooms.
		alpha *= smoothstep(ground_y - 0.06, ground_y + 0.22, world_position.y);
		alpha *= 1.0 - smoothstep(ground_y + 1.1, ground_y + 1.8, world_position.y);
	} else if (shape == 2) {
		float flutter = 0.3 + 0.7 * abs(sin(elapsed * 27.0 + particle_id * 7.3));
		vec2 wings = vec2(p.x / flutter, p.y * 1.9);
		alpha = exp(-dot(wings, wings) * 4.0);
	}
	// The nearest particles dissolve before they cross the eye; no billboard flashes.
	float distance_fade = smoothstep(0.22, shape == 1 ? 2.5 : 0.7, -VERTEX.z);
	if (exclude_hut) {
		vec3 hut = (hut_inverse * vec4(world_position, 1.0)).xyz;
		if (hut.x > -1.82 && hut.x < 1.78 && hut.z > -1.73 && hut.z < 1.78 && hut.y > -0.5 && hut.y < 3.0) {
			distance_fade = 0.0;
		}
	}
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 scene_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_depth = -scene_position.z / scene_position.w;
	distance_fade *= smoothstep(0.0, softness, scene_depth + VERTEX.z);
#endif
	ALBEDO = tint.rgb * COLOR.rgb;
	EMISSION = tint.rgb * glow;
	ROUGHNESS = 1.0;
	ALPHA = alpha * tint.a * COLOR.a * presence * distance_fade;
}
