shader_type spatial;
// 0.21 Nichols house: veined marble. `checker` lays the foyer's black-and-white tiles on the diagonal, with
// grimy grout, a few cracked and sunken tiles and a dust film that thins along the old walking line to the stair.
// UV = world metres on the floor plane.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D noise_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool checker = true;
uniform float tile_size = .6;
uniform vec3 light_marble : source_color = vec3(.74, .72, .68);
uniform vec3 dark_marble : source_color = vec3(.06, .065, .07);
uniform float dust = .55;

float n1(vec2 p) { return texture(noise_tex, p).r; }
float fbm(vec2 p) { return n1(p) * .55 + n1(p * 2.31 + .37) * .3 + n1(p * 5.17 + .71) * .15; }

float veins(vec2 p) {
	float t = fbm(p * .35) * 6.0 + p.x * .9 + p.y * .4;
	return pow(1.0 - abs(sin(t)), 9.0);
}

void fragment() {
	vec2 w = UV;
	vec2 d = checker ? vec2(w.x + w.y, w.x - w.y) * .7071 / tile_size : w / tile_size;
	vec2 cell = floor(d);
	vec2 f = fract(d);
	bool dark = checker && mod(cell.x + cell.y, 2.0) > .5;
	float id = n1(cell * .137 + .5);
	vec2 vp = w * 1.3 + id * 9.0;
	float v = veins(vp) + veins(vp * 1.9 + 3.0) * .5;
	vec3 col = dark ? dark_marble * (.8 + .5 * fbm(vp)) + vec3(.35) * v * .35 : light_marble * (.9 + .15 * fbm(vp)) - vec3(.28, .27, .26) * v;
	float rough = dark ? .32 : .38;
	// Grout.
	vec2 gd = min(f, 1.0 - f) * tile_size;
	float grout = 1.0 - smoothstep(.003, .007, min(gd.x, gd.y));
	col = mix(col, vec3(.05, .045, .04), grout * .9);
	// Cracked tiles.
	if (id > .8) {
		float c = abs(f.x - .2 - .6 * fbm(cell + f * .7));
		col *= 1.0 - (1.0 - smoothstep(.0, .012, c)) * .8;
	}
	// Dust and grime, thinner along the line from the door to the stair (x near 0 in house space).
	float g = fbm(w * .2);
	float path = smoothstep(.6, 1.6, abs(w.x + (fbm(w * .1) - .5) * 1.5));
	float dm = dust * (.35 + .65 * path) * (.55 + .6 * g);
	col = mix(col, vec3(.42, .4, .37) * (.85 + .3 * n1(w * 2.0)), clamp(dm, 0.0, .8));
	col *= .8 + .25 * g;
	ALBEDO = col;
	ROUGHNESS = mix(rough, .95, clamp(dm * 1.2, 0.0, 1.0));
	NORMAL_MAP = mix(vec3(.5, .5, 1.0), texture(grit_normal, w * .8).rgb, clamp(dm, 0.0, 1.0) * .6);
}
