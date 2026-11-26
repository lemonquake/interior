shader_type spatial;
// 0.21 Nichols house wallpaper: a generated Victorian pattern (assets/nichols/wallpaper_masks.png: R damask,
// G floral sprigs, B stripes) printed on stained paper (Poly Haven decrepit_wallpaper), then aged: faded and
// yellowed, brown water stains bleeding down from the ceiling with tide lines, black mildew rising from the
// skirting, and sheets peeled away to the cracked plaster beneath with curled, shadowed edges.
// UV: x along the wall in metres, y = height above the ground-floor boards (upper floor from 4.4).
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D paper_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paper_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 paper_color : source_color = vec3(.36, .42, .46);
uniform vec3 ink_color : source_color = vec3(.22, .27, .32);
uniform int channel = 0;
uniform float pattern_scale = 1.6;
uniform float peel = .35;
uniform float stains = .6;
uniform float mildew = .5;

float n1(vec2 p) { return texture(noise_tex, p).r; }
float fbm(vec2 p) { return n1(p) * .55 + n1(p * 2.31 + .37) * .3 + n1(p * 5.17 + .71) * .15; }

void fragment() {
	vec2 w = UV;
	float upper = step(4.4, w.y);
	float h = w.y - upper * 4.4;            // height above this floor
	float ceil_h = mix(4.0, 3.6, upper);
	vec3 paper = texture(paper_tex, w / 1.8).rgb;
	float lum = dot(paper, vec3(.3, .5, .2));
	vec4 masks = texture(pattern_tex, w / pattern_scale);
	float m = channel == 0 ? masks.r : (channel == 1 ? masks.g : masks.b);
	vec3 col = mix(paper_color, ink_color, m) * (.55 + lum * 1.1);
	// Faded and yellowed with age, more toward the top where the light used to fall.
	float g = fbm(w * .09);
	col = mix(col, vec3(dot(col, vec3(.33))) * vec3(1.08, 1.0, .82), .25 + .2 * g);
	// Water stains from the ceiling: blotches with a darker brown tide line.
	float sn = fbm(vec2(w.x * .35, w.y * .12) + 3.1);
	float reach = ceil_h - (1.0 + 2.2 * n1(vec2(w.x * .07, .5)));
	float st = smoothstep(.45, .62, sn) * smoothstep(reach - .3, reach + .6, h) * stains;
	float tide = (smoothstep(.43, .47, sn) - smoothstep(.47, .52, sn)) * smoothstep(reach - .3, reach + .6, h) * stains;
	col = mix(col, col * vec3(.62, .48, .32), st * .8);
	col *= 1.0 - tide * .45;
	// Mildew rising from the skirting.
	float md = (1.0 - smoothstep(.15, .5 + .9 * fbm(w * .5 + 7.0), h)) * mildew;
	float spots = smoothstep(.55, .75, n1(w * 3.1)) * md;
	col = mix(col, vec3(.04, .05, .035), clamp(md * .55 + spots * .5, 0.0, .85));
	// Peeled sheets (more near the ceiling and above the skirting): plaster shows, the torn edge is dark.
	float pz = smoothstep(ceil_h - 1.6, ceil_h, h) * .45 + (1.0 - smoothstep(.2, 1.1, h)) * .25;
	float pn = fbm(vec2(w.x * .55, w.y * .3) + 11.0) + pz * .35 + n1(w * 2.2) * .08;
	float bare = smoothstep(1.0 - peel * .55, 1.0 - peel * .55 + .03, pn);
	float edge = smoothstep(1.0 - peel * .55 - .05, 1.0 - peel * .55, pn) - bare;
	vec3 plaster = texture(plaster_tex, w / 2.0).rgb * vec3(.82, .78, .7);
	col = mix(col * (1.0 - edge * .6), plaster * (.7 + .3 * g), bare);
	vec3 nrm = mix(texture(paper_normal, w / 1.8).rgb, texture(plaster_normal, w / 2.0).rgb, bare);
	ALBEDO = col;
	ROUGHNESS = mix(.86, .95, bare) + st * .05;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.0 + edge * 2.0;
}
