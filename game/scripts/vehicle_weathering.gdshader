shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform bool rubber = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(6.0)); weights /= max(dot(weights,vec3(1.0)), .001);
	vec3 p = world_position * 1.2;
	vec3 rust = texture(rust_map,p.zy).rgb * weights.x + texture(rust_map,p.xz).rgb * weights.y + texture(rust_map,p.xy).rgb * weights.z;
	float rough = texture(rust_roughness,p.zy).r * weights.x + texture(rust_roughness,p.xz).r * weights.y + texture(rust_roughness,p.xy).r * weights.z;
	vec2 face = abs(n.x) > abs(n.z) ? p.zy : p.xy;
	if (abs(n.y) > .65) { face = p.xz; }
	float patches = noise(face * 3.2) * .68 + noise(face * 17.0) * .32;
	float wear = smoothstep(.31,.72,patches) * (rubber ? .04 : .87);
	float mud = (1.0-smoothstep(-2.72,-1.85,world_position.y)) * smoothstep(.21,.75,patches);
	float dust = clamp(.14 + max(n.y,0.0) * .34 + noise(face * .7) * .18,0.0,.68);
	vec3 color = base_color.rgb * (has_albedo ? texture(albedo_map,UV*uv_scale+uv_offset).rgb : vec3(1.0));
	color = mix(color * .72, rust * .72, wear);
	color = mix(color,vec3(.12,.10,.065),mud * .8);
	color = mix(color,color * .5 + vec3(.105,.083,.052),dust);
	// Chips and hairline scratches interrupt the remaining paint.
	float scratches = smoothstep(.86,.96,noise(face*vec2(1.8,190.0))) * (1.0-wear);
	ALBEDO = color * (1.0 - scratches * .35);
	ROUGHNESS = clamp(max(.66,rough * wear) + dust * .2, .66, .98);
	METALLIC = rubber ? 0.0 : .22 * (1.0-wear) * (1.0-dust) * (1.0-mud);
	SPECULAR = .28;
	// World-projected height variation adds shallow pitting without relying on the models' UV scale.
	float pits = texture(rust_normal,p.zy).r * weights.x + texture(rust_normal,p.xz).r * weights.y + texture(rust_normal,p.xy).r * weights.z;
	float relief = (dot(rust,vec3(.333)) + pits * .4) * wear * .015;
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL), r2 = cross(NORMAL,dx);
	float det = dot(dx,r1);
	NORMAL = normalize(abs(det)*NORMAL - sign(det)*(dFdx(relief)*r1 + dFdy(relief)*r2));
	if (has_normal) { NORMAL_MAP = texture(normal_map,UV*uv_scale+uv_offset).rgb; NORMAL_MAP_DEPTH = .5; }
}
