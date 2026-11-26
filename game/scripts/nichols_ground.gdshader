shader_type spatial;
// 0.21 Nichols property ground: withered grass and old leaf litter, the dirt path from street B to the gate and
// the gravel drive inside it (painted into `mask_tex`: R path, G gravel, B leaf litter / deep shade), in world space.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 mask_rect = vec4(-46.0, -128.0, 72.0, 110.0);

varying vec3 wpos;

float n1(vec2 p) { return texture(noise_tex, p).r; }
float fbm(vec2 p) { return n1(p) * .55 + n1(p * 2.31 + .37) * .3 + n1(p * 5.17 + .71) * .15; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec4 m = texture(mask_tex, (p - mask_rect.xy) / mask_rect.zw);
	float g = fbm(p * .05);
	float fine = n1(p * .6);
	vec3 grass = texture(grass_tex, p / 2.5).rgb * vec3(.78, .8, .7);
	vec3 leaves = texture(leaves_tex, p / 2.2).rgb * vec3(.7, .66, .6);
	float lm = clamp(smoothstep(.45, .7, g + fine * .15) + m.b, 0.0, 1.0);
	vec3 col = mix(grass, leaves, lm);
	vec3 nrm = mix(texture(grass_normal, p / 2.5).rgb, texture(leaves_normal, p / 2.2).rgb, lm);
	// Path: soft ragged edges, wheel ruts darker.
	float pe = smoothstep(.25, .75, m.r + (fine - .5) * .5);
	vec3 dirt = texture(dirt_tex, p / 2.0).rgb * vec3(.82, .76, .7);
	col = mix(col, dirt * (.85 + .25 * g), pe);
	nrm = mix(nrm, texture(dirt_normal, p / 2.0).rgb, pe);
	float ge = smoothstep(.3, .7, m.g + (fine - .5) * .4);
	vec3 gravel = texture(gravel_tex, p / 1.6).rgb * vec3(.62, .6, .58);
	col = mix(col, mix(gravel, leaves, smoothstep(.55, .8, g) * .6), ge);
	col *= .72 + .4 * g;
	ALBEDO = col;
	ROUGHNESS = .93;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.2;
}
