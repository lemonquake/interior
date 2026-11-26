shader_type canvas_item;
render_mode unshaded;
// 0.29: the view through the sniper rifle's scope (scripts/gun.gd), drawn over the picture once the eye is at the glass.
// The lens is the game's own camera at the scope's power; this is the tube round it: the black of the scope body,
// the bright circle of the exit pupil with a shadow that swims in from whichever side the eye is off the axis, glass
// that is sharp in the middle and softer and colour-fringed toward the edge, focus that goes when the rifle moves,
// fires or the power ring is turned, and the reticle: fine cross hairs with a mark every mil and heavy posts outside.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;
uniform float radius = 0.445;
uniform vec2 eye = vec2(0.0);
uniform float blur = 0.0;
uniform float mil = 0.031;
uniform float night = 0.0;
uniform float gain = 1.0;
// 0.48: the reticle: 0 mil-dot (the .338, the Titan), 1 chevron (the Drakon), 2 duplex (the Longreach).
uniform int style = 0;

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.55, w * 1.25, abs(d));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	vec2 dir = r > 0.00001 ? p / r : vec2(0.0);
	float edge = smoothstep(radius * 0.4, radius, r);
	float lod = blur * 3.4 + edge * edge * 2.4;
	vec2 fringe = dir * (edge * 0.005 + blur * 0.0015) / vec2(aspect, 1.0);
	vec3 c;
	c.r = textureLod(screen, uv + fringe, lod).r;
	c.g = textureLod(screen, uv, lod).g;
	c.b = textureLod(screen, uv - fringe, lod).b;
	if (blur > 0.02) {
		// Out of focus: the same picture again, a little off on each side.
		vec2 o = vec2(blur * 0.006) / vec2(aspect, 1.0);
		vec3 soft = textureLod(screen, uv + o, lod).rgb + textureLod(screen, uv - o, lod).rgb
			+ textureLod(screen, uv + vec2(o.x, -o.y), lod).rgb + textureLod(screen, uv + vec2(-o.x, o.y), lod).rgb;
		c = mix(c, soft * 0.25, clamp(blur * 1.4, 0.0, 0.8));
	}
	// What the glass does to the light: a little less of it, the coating's tint, darker toward the edge.
	c *= vec3(0.95, 1.0, 0.93) * (1.0 - 0.3 * edge * edge);
	// A big objective gathers light: by night the picture is brighter than the naked eye's (and flatter).
	c = mix(c, pow(c, vec3(0.72)), clamp(gain - 1.0, 0.0, 1.0)) * gain;
	// The reticle (second focal plane: the same size at every power).
	float px = SCREEN_PIXEL_SIZE.y;
	float w = px * 1.15;
	float ax = abs(p.x);
	float ay = abs(p.y);
	float ink = 0.0;
	if (style == 1) {
		// A chevron, its point on the aim, a short bar either side of it and range ticks under it.
		// (Screen y runs down: the chevron's arms open downward from the aim.)
		float arm = abs(ax - p.y * 0.6);
		ink = max(ink, line(arm, w * 1.4) * step(0.0, p.y) * step(p.y, mil * 1.6));
		ink = max(ink, line(p.y, w * 1.3) * step(mil * 3.0, ax) * step(ax, mil * 9.0));
		for (int k = 1; k <= 3; k++) {
			float yk = mil * (2.4 + float(k) * 1.4);
			ink = max(ink, line(p.y - yk, w) * step(ax, mil * (0.9 - float(k) * 0.18)));
		}
		ink = max(ink, line(p.x, w) * step(mil * 8.5, ay) * step(0.0, p.y));
	} else if (style == 2) {
		// Duplex: thick posts from the edge to four mils out, a thin cross between them.
		float thin = w;
		float thick = mil * 0.16;
		ink = max(ink, line(p.y, thin) * step(ax, mil * 4.0));
		ink = max(ink, line(p.x, thin) * step(ay, mil * 4.0));
		ink = max(ink, (1.0 - smoothstep(thick, thick + px, ay)) * step(mil * 4.0, ax));
		ink = max(ink, (1.0 - smoothstep(thick, thick + px, ax)) * step(mil * 4.0, ay));
	} else {
		float gap = mil * 0.22;
		ink = max(ink, line(p.y, w) * step(gap, ax));
		ink = max(ink, line(p.x, w) * step(gap, ay));
		// A mark every mil out to five, every other one longer.
		float mx = abs(fract(p.x / mil + 0.5) - 0.5) * mil;
		float my = abs(fract(p.y / mil + 0.5) - 0.5) * mil;
		float nx = floor(ax / mil + 0.5);
		float ny = floor(ay / mil + 0.5);
		float tick_x = mil * (mod(nx, 2.0) < 0.5 ? 0.3 : 0.17);
		float tick_y = mil * (mod(ny, 2.0) < 0.5 ? 0.3 : 0.17);
		ink = max(ink, line(mx, w) * step(ay, tick_x) * step(0.5, nx) * step(nx, 5.5));
		ink = max(ink, line(my, w) * step(ax, tick_y) * step(0.5, ny) * step(ny, 5.5));
		// The posts: left, right and below, from six mils out.
		float post = mil * 0.11;
		ink = max(ink, (1.0 - smoothstep(post, post + px, ay)) * step(mil * 6.5, ax));
		ink = max(ink, (1.0 - smoothstep(post, post + px, ax)) * step(mil * 6.5, -p.y * -1.0) * step(0.0, p.y));
		// A dot in the middle.
		ink = max(ink, 1.0 - smoothstep(px * 1.3, px * 2.4, r));
	}
	// Black on anything lit; over the dark the reticle's own red lamp is what shows.
	float behind = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 lamp = vec3(0.78, 0.045, 0.02) * (1.0 - smoothstep(0.03, 0.2, behind)) * night;
	c = mix(c, lamp, ink * 0.93);
	// The tube, and the shadow of the eye being off the axis.
	float tube = 1.0 - smoothstep(radius - px * 3.0, radius, r);
	float pupil = 1.0 - smoothstep(radius * 0.72, radius * 1.04, length(p - eye));
	float see = tube * pupil;
	// A thin grey ring where the light catches the edge of the ocular.
	float rim = (1.0 - smoothstep(0.0, px * 5.0, abs(r - radius - px * 4.0))) * 0.035 * (1.0 - night * 0.7);
	COLOR = vec4(mix(vec3(rim), c, see), amount);
}
