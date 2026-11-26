shader_type canvas_item;

// 0.32: the weapon's view as an action camera on the forehead has it. The lens is focused out in the room, so what is
// within a hand's length of it is soft; and the near end of the weapon is under the wearer's own head and shoulders,
// out of the light. Both grow toward the lower edge of the picture, which is where the near end always is
// (scripts/gun.gd keeps the hands under that edge).
uniform float start : hint_range(0.0, 1.0) = 0.76;      // where it begins, down the picture
uniform float full : hint_range(0.0, 1.2) = 0.96;      // where it is complete
uniform float blur : hint_range(0.0, 0.05) = 0.009;    // radius at the lower edge, as a share of the height
uniform float shade : hint_range(0.0, 1.0) = 0.65;      // how much light is lost at the lower edge
uniform float detail : hint_range(0.0, 1.0) = 1.0;     // 0: no blur (low quality)

void fragment() {
	// A little sooner toward the sides: the lens shows more of the bottom there.
	float side = (UV.x - 0.5) * (UV.x - 0.5);
	float k = smoothstep(start, full, UV.y + side * 0.22);
	vec4 colour = texture(TEXTURE, UV);
	if (k > 0.002 && detail > 0.5) {
		float radius = blur * k * k;
		vec2 scale = vec2(TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y, 1.0) * radius;
		vec3 sum = colour.rgb * colour.a;
		float cover = colour.a;
		// Twelve taps on a spiral.
		for (int i = 1; i <= 12; i++) {
			float t = float(i);
			float r = sqrt(t / 12.0);
			float a = t * 2.39996;
			vec4 tap = texture(TEXTURE, UV + vec2(cos(a), sin(a)) * r * scale);
			sum += tap.rgb * tap.a;
			cover += tap.a;
		}
		colour = vec4(cover > 0.0001 ? sum / cover : vec3(0.0), cover / 13.0);
	}
	colour.rgb *= 1.0 - shade * k;
	COLOR = colour;
}
