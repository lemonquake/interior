shader_type canvas_item;
render_mode unshaded, blend_disabled;

// 0.26 body camera lens: one pass over the finished frame (world, hands and gun), under the HUD text.
// Barrel distortion with the image circle cut off at the corners, a warm fringe on the circle's edge, colour
// fringing toward the edges, a short smear on fast turns, sensor grain that is strongest in the dark, and the
// camera's exposure reactions (a muzzle flash whites out, then the gain dips).
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float distortion : hint_range(0.0, 0.8) = 0.34;
uniform float fringe : hint_range(0.0, 0.05) = 0.012;
uniform float circle : hint_range(0.5, 1.6) = 1.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.42;
uniform float grain : hint_range(0.0, 0.2) = 0.05;
uniform float exposure = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 smear = vec2(0.0);
uniform float elapsed = 0.0;
uniform float aspect = 1.7778;
uniform float desaturate : hint_range(0.0, 1.0) = 0.16;
uniform float detail : hint_range(0.0, 1.0) = 1.0;
uniform vec3 shadow_tint : source_color = vec3(0.93, 0.98, 1.06);
// Low light: 0 in a lit room, 1 out in the dark. The sensor turns its gain up: what little there is in the
// shadows comes up cold and flat, and the noise comes up with it.
uniform float night_gain : hint_range(0.0, 1.0) = 0.0;

vec2 lens(vec2 uv, float k) {
	vec2 d = uv - 0.5;
	d.x *= aspect;
	float r2 = dot(d, d);
	// Fitted on the middle of the left and right edges: the corners fall outside the image circle.
	float edge = 0.5 * aspect * 0.97;
	d *= (1.0 + k * r2) / (1.0 + k * edge * edge);
	d.x /= aspect;
	return d + 0.5;
}

vec3 tap(vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(screen_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb * inside.x * inside.y;
}

float hash(vec2 p, float t) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + t * 7.31) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - 0.5;
	centred.x *= aspect;
	float corner = length(vec2(0.5 * aspect, 0.5));
	float rc = length(centred) / corner;
	vec2 src = lens(uv, distortion);
	vec3 colour;
	if (detail > 0.5) {
		// Red and blue leave the glass at slightly different radii; nothing in the middle, most at the rim.
		float spread = fringe * rc * rc;
		vec2 dir = normalize(centred + vec2(0.00001)) * vec2(1.0 / aspect, 1.0);
		float len2 = dot(smear, smear);
		if (len2 > 0.0000004) {
			// 0.33: three places along the swing, the fringe taken once in the middle (five reads, it was fifteen:
			// the smear is only on while the view turns fast, which is when the frame can least afford it).
			vec3 mid = tap(src);
			vec3 sum = mid + tap(src - smear) + tap(src + smear);
			colour = sum / 3.0;
			colour.r += (tap(src + dir * spread).r - mid.r) * 0.6;
			colour.b += (tap(src - dir * spread).b - mid.b) * 0.6;
		} else {
			colour = vec3(tap(src + dir * spread).r, tap(src).g, tap(src - dir * spread).b);
		}
	} else {
		colour = tap(src);
	}
	colour *= exposure;
	// The flash: the sensor clips for a frame or two, warm at first.
	colour = mix(colour, vec3(1.0, 0.95, 0.86), flash * 0.42) + vec3(0.22, 0.17, 0.10) * flash;
	// Cheap sensor: lifted, slightly cool shadows; warm, soft highlights; less colour.
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(luma), desaturate);
	colour *= mix(shadow_tint, vec3(1.03, 1.0, 0.95), smoothstep(0.0, 0.6, luma));
	colour = colour / (1.0 + max(luma - 0.82, 0.0) * 0.9);
	if (night_gain > 0.001) {
		float dark = 1.0 - smoothstep(0.02, 0.42, luma);
		vec3 lifted = pow(max(colour, vec3(0.0)), vec3(0.7)) * vec3(0.88, 0.97, 1.1) + vec3(0.004, 0.006, 0.009);
		colour = mix(colour, lifted, night_gain * dark);
		luma = dot(colour, vec3(0.299, 0.587, 0.114));
	}
	// Falloff toward the rim, then the edge of the image circle itself.
	float rim = rc / circle;
	colour *= 1.0 - vignette * smoothstep(0.25, 1.0, rim) * 0.9;
	float cut = smoothstep(0.9, 1.035, rim);
	float band = smoothstep(0.8, 0.93, rim) * (1.0 - smoothstep(0.93, 1.03, rim));
	colour += vec3(0.5, 0.2, 0.04) * band * (0.05 + luma * 0.9) * detail;
	colour *= 1.0 - cut;
	// Grain: per pixel, new every 1/24 s, strongest where the picture is dark.
	float tick = floor(elapsed * 24.0);
	float n = hash(floor(FRAGCOORD.xy), tick) - 0.5;
	colour += n * grain * (1.0 + 1.1 * night_gain) * (1.15 - smoothstep(0.0, 0.7, luma)) * (1.0 - cut);
	COLOR = vec4(max(colour, vec3(0.0)), 1.0);
}
