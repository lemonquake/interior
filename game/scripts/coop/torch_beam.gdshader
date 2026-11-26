shader_type spatial;
// 0.54: Heavy-arm's flashlight beam (scripts/coop/heavyarm.gd): a cone from the lens, seen as light caught in the
// dust and the damp of the field. Brightest by the lens, thinning out along its length; soft at its sides (by how
// squarely it faces the eye); motes drifting through it; faded where it meets the ground or a body so it never
// shows a hard line there. The cone mesh is a unit CylinderMesh (narrow end at +Y = the lens).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.58, 1.0);
uniform float energy = 1.0;
uniform float drift = 0.0;
uniform sampler2D dust : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float along;

void vertex() {
	along = clamp(0.5 - VERTEX.y, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float side = pow(facing, 2.2);
	float fall = mix(1.0, 0.08, pow(along, 0.7));
	vec2 uv = vec2(UV.x * 2.0, along * 3.0 - drift);
	float d = texture(dust, uv).r * 0.6 + texture(dust, uv * 2.7 + vec2(drift * 0.31, 0.17)).r * 0.4;
	float motes = mix(0.45, 1.6, d);
	float start = smoothstep(0.0, 0.035, along);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	world.xyz /= world.w;
	float near = clamp((VERTEX.z - world.z) / 0.9, 0.0, 1.0);
	float cam = clamp(-VERTEX.z / 1.5, 0.0, 1.0);
	ALBEDO = tint.rgb * energy * side * fall * motes * start * near * cam;
}
