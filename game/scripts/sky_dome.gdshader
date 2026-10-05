shader_type spatial;
// Misty afternoon sky for the neighbourhood (scripts/neighborhood_builder.gd). The panorama is a
// Reinhard-compressed HDRI (tools/assets/make_sky.py); this inverts it, adds a 3 pm sun where the
// DirectionalLight is, and melts the horizon into the fog colour so distant houses fade into haze.
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_opaque, skip_vertex_transform;

uniform sampler2D sky_texture : source_color, filter_linear, repeat_enable;
uniform float yaw = 0.0;
uniform float exposure = 0.55;
uniform vec3 sun_direction = vec3(0.74, 0.64, 0.2);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.76);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.73, 0.76);
uniform float horizon_energy = 1.0;
uniform float horizon_band = 0.22;

varying vec3 world_dir;

void vertex() {
	world_dir = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 d = normalize(world_dir);
	float az = atan(d.x, -d.z) + yaw;
	float u = fract(az / TAU + 0.5);
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	vec3 packed = texture(sky_texture, vec2(u, v)).rgb;
	vec3 c = packed / max(vec3(1.0) - packed, vec3(0.04)) * exposure;
	float s = max(dot(d, normalize(sun_direction)), 0.0);
	c += sun_color * (pow(s, 2400.0) * 30.0 + pow(s, 90.0) * 0.5 + pow(s, 8.0) * 0.12);
	float h = smoothstep(-0.02, horizon_band, d.y);
	c = mix(horizon_color * horizon_energy, c, h);
	ALBEDO = c;
}
