shader_type spatial;
// 0.21 Nichols house: a shaft of moonlight from a window to where it lands (nichols_property.gd builds the volume
// by ray-casting the window's corners along the moon). Additive and double-sided, so looking through it sums the
// near and far faces; it fades at grazing angles (soft silhouette), toward its far end, and where it meets the
// floor or a wall (soft depth fade). Slow dust drifts through it.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 beam_color : source_color = vec3(.55, .66, .9);
uniform float intensity = .06;
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft_edge = mix(.35, 1.0, facing);
	// Each card is one slice through the shaft: feathered across its width, faded along its length.
	float across = smoothstep(0.0, .5, UV.x) * smoothstep(1.0, .5, UV.x);
	float along = UV.y;
	float fade = smoothstep(0.0, .05, along) * mix(1.0, .3, along);
	vec2 p = wpos.xz * .45 + wpos.y * .25;
	float dust = texture(noise_tex, p + vec2(TIME * .006, TIME * .004)).r * .6 + texture(noise_tex, p * 2.7 - vec2(TIME * .009, 0.0)).r * .4;
	float specks = smoothstep(.84, .9, texture(noise_tex, wpos.xz * 17.0 + wpos.y * 13.0 + TIME * .02).r) * .8;
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / .5, 0.0, 1.0);
	float near = smoothstep(.4, 2.2, -VERTEX.z);
	float a = intensity * soft_edge * across * fade * (.45 + .9 * dust + specks) * soft * near;
	ALBEDO = beam_color * a;
}
