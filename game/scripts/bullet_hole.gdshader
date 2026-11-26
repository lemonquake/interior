// 0.11: a bullet hole on the Compatibility renderer (Android has no decals). The card is drawn pulled a little
// toward the camera along its own view ray, so it sits on the visible surface even when that stands a few cm
// off the collider the shot hit, without sliding sideways on screen.
shader_type spatial;
render_mode skip_vertex_transform, depth_draw_never, cull_disabled;

uniform sampler2D hole : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float pull = 0.1;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX -= normalize(VERTEX) * pull;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 c = texture(hole, UV) * tint;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.9;
}
