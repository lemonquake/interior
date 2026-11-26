shader_type canvas_item;
render_mode unshaded;

// A transparent overlay below the HUD. No blur, screen copy, crushed centre blacks or colour fringes.
uniform float strength : hint_range(0.0, 0.3) = 0.1;
uniform float grain_amount : hint_range(0.0, 0.03) = 0.007;
uniform float elapsed = 0.0;

void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	float edge = smoothstep(0.36, 1.65, dot(centred, centred));
	float tick = floor(elapsed * 18.0);
	float noise = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233)) + tick * 5.73) * 43758.5453);
	COLOR = vec4(vec3(0.012, 0.017, 0.024), edge * strength + noise * grain_amount);
}
