shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Old CRT television look for the living-room TV (scripts/television.gd): barrel curvature,
// RGB fringing, scanlines and an aperture mask, flicker, a slow rolling bar, grain, static snow,
// tearing glitches and the power-on / power-off squeeze to a bright line.

uniform sampler2D screen_tex : source_color, filter_linear, repeat_disable;
uniform float power : hint_range(0.0, 1.0) = 1.0;      // 0 = off (a line), 1 = full raster
uniform float static_mix : hint_range(0.0, 1.0) = 0.0; // 1 = pure snow (no signal)
uniform float picture : hint_range(0.0, 1.0) = 1.0;    // fades the broadcast image in
uniform float glitch : hint_range(0.0, 1.0) = 0.0;     // tearing / roll burst
uniform float brightness = 1.35;
uniform vec2 resolution = vec2(640.0, 360.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 curve(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(6.0, 5.0);
	uv = uv + uv * offset * offset;
	return uv * 0.5 + 0.5;
}

void fragment() {
	float t = TIME;
	vec2 uv = curve(UV);
	vec3 col = vec3(0.0);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);

	// Power squeeze: the raster collapses vertically to a line, then the line shrinks to a dot.
	float squeeze_v = clamp(power * 1.4 - 0.4, 0.004, 1.0);
	float squeeze_h = clamp(power * 3.0, 0.0, 1.0);
	vec2 suv = vec2((uv.x - 0.5) / max(squeeze_h, 0.001) + 0.5, (uv.y - 0.5) / squeeze_v + 0.5);
	float raster = step(0.0, suv.y) * step(suv.y, 1.0) * step(0.0, suv.x) * step(suv.x, 1.0);

	// Tearing: horizontal line jitter, stronger while glitching.
	float line = floor(suv.y * resolution.y);
	float jitter = (hash(vec2(line, floor(t * 30.0))) - 0.5) * (0.002 + glitch * 0.06);
	jitter += sin(suv.y * 40.0 + t * 25.0) * glitch * 0.01;
	vec2 iuv = vec2(suv.x + jitter, fract(suv.y + glitch * sin(t * 3.0) * 0.08));

	float ca = 0.0016 + glitch * 0.006;
	vec3 image;
	image.r = texture(screen_tex, iuv + vec2(ca, 0.0)).r;
	image.g = texture(screen_tex, iuv).g;
	image.b = texture(screen_tex, iuv - vec2(ca, 0.0)).b;
	// Slight ghosting / bleed to the right, like a weak analogue signal.
	image += texture(screen_tex, iuv - vec2(0.006, 0.0)).rgb * 0.12;
	image *= picture;

	float snow = hash(floor(suv * resolution * vec2(1.0, 0.5)) + fract(t * 61.3) * 97.0);
	snow = pow(snow, 1.6);
	vec3 noise_col = vec3(snow) * (0.75 + 0.25 * sin(suv.y * 6.0 + t * 40.0));
	col = mix(image, noise_col, clamp(static_mix + glitch * 0.35, 0.0, 1.0));

	// Grain, flicker and the slow rolling bright bar.
	col += (hash(suv * 300.0 + t) - 0.5) * 0.06;
	col *= 0.94 + 0.06 * sin(t * 120.0) + 0.03 * hash(vec2(floor(t * 20.0), 1.0));
	float bar = smoothstep(0.0, 0.08, fract(suv.y * 0.5 - t * 0.11)) * smoothstep(0.16, 0.08, fract(suv.y * 0.5 - t * 0.11));
	col += bar * 0.05;

	// Scanlines and a vertical RGB aperture mask.
	float scan = 0.72 + 0.28 * sin(suv.y * resolution.y * 3.14159);
	col *= scan;
	float mask_x = mod(floor(suv.x * resolution.x * 1.5), 3.0);
	vec3 mask = vec3(mask_x < 1.0 ? 1.0 : 0.9, (mask_x >= 1.0 && mask_x < 2.0) ? 1.0 : 0.9, mask_x >= 2.0 ? 1.0 : 0.9);
	col *= mask;

	// Vignette toward the curved corners.
	vec2 v = uv * (1.0 - uv.yx);
	float vig = clamp(pow(v.x * v.y * 18.0, 0.28), 0.0, 1.0);
	col *= vig;

	// While collapsing the line glows white-hot.
	float hot = (1.0 - smoothstep(0.3, 0.7, power)) * step(0.001, power);
	col = mix(col, vec3(1.0), hot * 0.85);

	col *= raster * inside * brightness * step(0.001, power);
	// Faint glass sheen so the tube still reads as glass.
	float sheen = smoothstep(0.55, 0.0, distance(UV, vec2(0.25, 0.2))) * 0.035;
	ALBEDO = col + vec3(sheen);
}
