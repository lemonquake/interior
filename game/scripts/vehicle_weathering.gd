class_name InteriorVehicleWeathering
extends RefCounted
## Keep each imported vehicle's paint colours/UVs, replacing bare materials with dusty, pitted PBR.
const SHADER := preload("res://scripts/vehicle_weathering.gdshader")
const MAPS := "res://assets/outdoor/textures/rusty_metal_04/"

static func apply(root: Node3D) -> Dictionary:
	var stats := {"models": 0, "surfaces": 0}
	var cache := {}
	for model: Node in root.find_children("*", "Node3D", true, false):
		var label := String(model.name).to_lower()
		if not model.has_meta("keep_instance") or not (label.begins_with("tricycle") or label.begins_with("jeepney") or label.begins_with("food_cart") or label.begins_with("oil_drum")):
			continue
		stats.models += 1
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var source := mesh.get_active_material(surface) as StandardMaterial3D
				if source == null:
					continue
				var identity := source.get_instance_id()
				if not cache.has(identity):
					cache[identity] = _material(source)
				mesh.set_surface_override_material(surface, cache[identity])
				stats.surfaces += 1
	return stats

static func _material(source: StandardMaterial3D) -> Material:
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		var glass := source.duplicate() as StandardMaterial3D
		glass.emission_enabled = false
		glass.roughness = .75
		glass.albedo_color *= Color(.45, .42, .36, 1.0)
		return glass
	var material := ShaderMaterial.new()
	material.resource_name = "Aged vehicle / " + source.resource_name
	material.shader = SHADER
	material.set_shader_parameter("base_color", source.albedo_color)
	material.set_shader_parameter("has_albedo", source.albedo_texture != null)
	material.set_shader_parameter("has_normal", source.normal_enabled and source.normal_texture != null)
	material.set_shader_parameter("uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	material.set_shader_parameter("uv_offset", Vector2(source.uv1_offset.x, source.uv1_offset.y))
	if source.albedo_texture != null:
		material.set_shader_parameter("albedo_map", source.albedo_texture)
	if source.normal_texture != null:
		material.set_shader_parameter("normal_map", source.normal_texture)
	var rubber := maxf(source.albedo_color.r, maxf(source.albedo_color.g, source.albedo_color.b)) < .28
	material.set_shader_parameter("rubber", rubber)
	material.set_shader_parameter("rust_map", load(MAPS + "albedo.jpg"))
	material.set_shader_parameter("rust_normal", load(MAPS + "normal.jpg"))
	material.set_shader_parameter("rust_roughness", load(MAPS + "roughness.jpg"))
	return material
