class_name InteriorNeighborhoodWeathering
extends RefCounted
## Instance-local surface ageing for the baked neighbourhood. Photographic PBR maps and their
## original metre-scaled UVs stay intact; rainfall, damp and fractures use world coordinates.
## Call apply(neighbourhood) once after the baked scene enters the tree. No mesh rebake is needed.

const WEATHER_SHADER := preload("res://scripts/neighborhood_weathering.gdshader")
const TEXTURES := "res://assets/outdoor/textures/"
const STATS_META := "abandoned_surface_weathering"

static func apply(root: Node3D) -> Dictionary:
	if root.has_meta(STATS_META):
		return root.get_meta(STATS_META) as Dictionary
	var stats := {"meshes": 0, "surfaces": 0, "materials": 0, "plaster": 0, "masonry": 0,
		"asphalt": 0, "pavement": 0, "metal": 0, "timber": 0}
	var cache: Dictionary = {}
	var shader_double_sided := Shader.new()
	shader_double_sided.code = WEATHER_SHADER.code.replace("cull_back", "cull_disabled")
	for item: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if mesh.mesh == null:
			continue
		var changed := false
		if mesh.material_override is StandardMaterial3D:
			var aged := _material(mesh.material_override as StandardMaterial3D, cache, shader_double_sided, stats)
			if aged != null:
				mesh.material_override = aged
				stats.surfaces += mesh.mesh.get_surface_count()
				changed = true
		elif mesh.material_override == null:
			for surface: int in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original == null:
					continue
				var aged := _material(original, cache, shader_double_sided, stats)
				if aged != null:
					mesh.set_surface_override_material(surface, aged)
					stats.surfaces += 1
					changed = true
		if changed:
			stats.meshes += 1
	stats.materials = cache.size()
	root.set_meta(STATS_META, stats)
	return stats

static func _material(source: StandardMaterial3D, cache: Dictionary, double_sided: Shader, stats: Dictionary) -> ShaderMaterial:
	var key := source.resource_name.get_slice(" / ", 1)
	var profile := _profile(key)
	if profile.is_empty() or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var identity := source.get_instance_id()
	if cache.has(identity):
		return cache[identity] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.resource_name = "Weathered / " + key
	material.shader = double_sided if source.cull_mode == BaseMaterial3D.CULL_DISABLED else WEATHER_SHADER
	material.set_shader_parameter("base_color", source.albedo_color)
	material.set_shader_parameter("uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	material.set_shader_parameter("uv_offset", Vector2(source.uv1_offset.x, source.uv1_offset.y))
	material.set_shader_parameter("base_roughness", source.roughness)
	material.set_shader_parameter("base_metallic", source.metallic)
	material.set_shader_parameter("base_specular", source.metallic_specular)
	material.set_shader_parameter("normal_strength", source.normal_scale * .68 if source.normal_enabled else 0.0)
	material.set_shader_parameter("road_paint", key == "n frame white")
	material.set_shader_parameter("roughness_channel", _channel(source.roughness_texture_channel))
	material.set_shader_parameter("has_albedo", source.albedo_texture != null)
	material.set_shader_parameter("has_roughness", source.roughness_texture != null)
	material.set_shader_parameter("has_normal", source.normal_enabled and source.normal_texture != null)
	if source.albedo_texture != null:
		material.set_shader_parameter("albedo_map", source.albedo_texture)
	if source.roughness_texture != null:
		material.set_shader_parameter("roughness_map", source.roughness_texture)
	if source.normal_texture != null:
		material.set_shader_parameter("normal_map", source.normal_texture)
	if profile.category == "plaster":
		# Replace the old painted-wall base with a photographed dirty, broken plaster surface.
		var plaster := TEXTURES + "rough_plaster_broken/"
		material.set_shader_parameter("albedo_map", load(plaster + "albedo.jpg"))
		material.set_shader_parameter("normal_map", load(plaster + "normal.jpg"))
		material.set_shader_parameter("roughness_map", load(plaster + "roughness.jpg"))
		material.set_shader_parameter("has_albedo", true)
		material.set_shader_parameter("has_normal", true)
		material.set_shader_parameter("has_roughness", true)
		material.set_shader_parameter("normal_strength", .55)
		material.set_shader_parameter("uv_scale", Vector2.ONE / 1.5)
	# These are local shader parameters; the original imported/baked material is never edited.
	for parameter: String in ["surface_kind", "wear", "dirt", "cracks", "damp", "substrate_scale"]:
		material.set_shader_parameter(parameter, profile[parameter])
	material.set_shader_parameter("seed", float(absi(key.hash()) % 997) / 31.0)
	var directory := TEXTURES + str(profile.substrate) + "/"
	material.set_shader_parameter("substrate_albedo", load(directory + "albedo.jpg"))
	material.set_shader_parameter("substrate_normal", load(directory + "normal.jpg"))
	material.set_shader_parameter("substrate_roughness", load(directory + "roughness.jpg"))
	cache[identity] = material
	stats[str(profile.category)] += 1
	return material

static func _channel(channel: int) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN: return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE: return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: return Vector4(0, 0, 0, 1)
		BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE: return Vector4(0.333333, 0.333333, 0.333333, 0)
		_: return Vector4(1, 0, 0, 0)

static func _profile(key: String) -> Dictionary:
	# category, shader kind, exposed patches, dust/runoff, fractures, rising damp, photo substrate.
	# Existing brick/block joints and corrugation are kept; only plaster loses broad paint patches.
	if key.begins_with("n plaster") or key == "n peeling":
		return _values("plaster", 0, .88, .94, .75, .92, "damaged_plaster", 1.0 / 1.9)
	if key in ["n concrete", "n pole"]:
		return _values("masonry", 0, .26, .78, .58, .84, "concrete_wall_008", .333333)
	if key in ["n block", "n brick"]:
		return _values("masonry", 0, .12, .77, .24, .91, "concrete_wall_008", .333333)
	if key == "n asphalt":
		return _values("asphalt", 1, .34, .83, .98, .77, "brown_mud_02", .50)
	if key in ["n pavement", "n yard"]:
		return _values("pavement", 2, .40, .86, .80, .79, "concrete_floor_02", .333333)
	if key.begins_with("n roof"):
		if key in ["n roof tile", "n roof grey"]:
			return _values("masonry", 0, .09, .67, .08, .25, "concrete_wall_008", .333333)
		return _values("metal", 3, .52, .72, 0.0, .28, "rusty_corrugated_iron", .50)
	if key in ["n shutter", "n rust", "n gate green", "n gate maroon", "n grille"]:
		return _values("metal", 3, .76, .88, 0.0, .62, "rusty_metal_04", .50)
	if key in ["n planks", "n frame brown"]:
		return _values("timber", 4, .37, .68, .12, .70, "dark_wooden_planks", .625)
	if key in ["n frame white", "n frame dark"]:
		return _values("metal", 3, .52, .82, 0.0, .47, "rusty_metal_04", .50)
	return {}

static func _values(category: String, kind: int, wear: float, dirt: float, cracks: float, damp: float, substrate: String, scale: float) -> Dictionary:
	return {"category": category, "surface_kind": kind, "wear": wear, "dirt": dirt,
		"cracks": cracks, "damp": damp, "substrate": substrate, "substrate_scale": scale}
