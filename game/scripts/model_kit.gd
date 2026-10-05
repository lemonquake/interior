class_name InteriorModelKit
extends RefCounted
## Places downloaded GLB models (res://assets/models/, made by tools/blender/process_downloads.py)
## in builder scripts. Instances stay linked to their GLB: they carry the "keep_instance" meta,
## so editor/bake_room.gd keeps them as scene instances instead of flattening their meshes.
## Every model is pivoted on its bottom centre in metres; `anchor` places it by its bounds.

const ROOT := "res://assets/models/"
## Leaf and frond materials arrive as glTF BLEND; alpha scissor keeps them sorted and shadowed.
const FOLIAGE_HINTS := ["lea", "frond", "leef", "twi", "hair", "bra", "palm", "banana", "plant", "material.001", "lambert1"]

static var _cache: Dictionary = {}

static func scene(path: String) -> PackedScene:
	var full := path if path.begins_with("res://") else ROOT + path + ".glb"
	if not _cache.has(full):
		_cache[full] = load(full)
	return _cache[full]

## Instances `path` under `parent`. `at` is where the anchor point of the (rotated, scaled) bounds
## lands: "bottom" = bottom centre, "back" = centre of the -Z face after rotation, "center".
static func place(parent: Node, path: String, at: Vector3, yaw_deg := 0.0, scale := 1.0, anchor := "bottom",
		tilt := Vector3.ZERO, label := "") -> Node3D:
	var node := scene(path).instantiate() as Node3D
	node.name = (label if label != "" else path.get_file().get_basename()).validate_node_name()
	node.set_meta("keep_instance", true)
	parent.add_child(node, true)
	var basis := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(yaw_deg), deg_to_rad(tilt.z))).scaled(Vector3.ONE * scale)
	node.transform = Transform3D(basis, Vector3.ZERO)
	var box := local_bounds(node)
	var box_in_parent := node.transform * box
	var offset := Vector3.ZERO
	match anchor:
		"bottom":
			offset = Vector3(box_in_parent.get_center().x, box_in_parent.position.y, box_in_parent.get_center().z)
		"back":
			offset = Vector3(box_in_parent.get_center().x, box_in_parent.get_center().y, box_in_parent.position.z)
		"front":
			offset = Vector3(box_in_parent.get_center().x, box_in_parent.get_center().y, box_in_parent.end.z)
		"left":
			offset = Vector3(box_in_parent.position.x, box_in_parent.get_center().y, box_in_parent.get_center().z)
		"right":
			offset = Vector3(box_in_parent.end.x, box_in_parent.get_center().y, box_in_parent.get_center().z)
		"top":
			offset = Vector3(box_in_parent.get_center().x, box_in_parent.end.y, box_in_parent.get_center().z)
		"center":
			offset = box_in_parent.get_center()
		_:
			offset = Vector3.ZERO
	node.position = at - offset
	return node

## Union of every mesh AABB below `node`, in `node`'s own space.
static func local_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null:
			continue
		var relative := Transform3D.IDENTITY
		var walker: Node = mi
		while walker != node and walker != null:
			relative = (walker as Node3D).transform * relative if walker is Node3D else relative
			walker = walker.get_parent()
		var box := relative * mi.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

## Bounds of `node` expressed in the space of `space` (an ancestor).
static func bounds_in(node: Node3D, space: Node3D) -> AABB:
	var relative := Transform3D.IDENTITY
	var walker: Node = node
	while walker != space and walker != null:
		if walker is Node3D:
			relative = (walker as Node3D).transform * relative
		walker = walker.get_parent()
	return relative * local_bounds(node)

## A static box collider around `node` (shrunk by `inset` on each side) as a sibling body.
static func add_box_collider(owner_body: StaticBody3D, node: Node3D, inset := Vector3.ZERO, label := "") -> CollisionShape3D:
	var box := bounds_in(node, owner_body)
	var shape := BoxShape3D.new()
	shape.size = (box.size - inset * 2.0).max(Vector3.ONE * .02)
	shape.margin = .002
	var collision := CollisionShape3D.new()
	collision.name = (label if label != "" else String(node.name) + " collider").validate_node_name()
	collision.shape = shape
	collision.position = box.get_center()
	owner_body.add_child(collision, true)
	return collision

## Runtime: alpha-scissor foliage, put every model mesh on `layers`, and optionally fade by distance.
static func prepare_instance(node: Node, layers: int, visibility_end := 0.0, shadows := true, foliage := false) -> void:
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		geometry.layers = layers
		if visibility_end > 0.0:
			geometry.visibility_range_end = visibility_end
			geometry.visibility_range_end_margin = visibility_end * .1
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not shadows:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if geometry is MeshInstance3D:
			var mesh := (geometry as MeshInstance3D).mesh
			if mesh != null:
				for i in mesh.get_surface_count():
					_fix_alpha(mesh.surface_get_material(i), foliage)

static func _fix_alpha(material: Material, foliage_model := false) -> void:
	var standard := material as BaseMaterial3D
	if standard == null or standard.has_meta("alpha_fixed"):
		return
	standard.set_meta("alpha_fixed", true)
	if foliage_model:
		# Leaves and fronds are single sheets: draw both sides, and honour alpha even when the
		# glTF material was exported opaque (its texture still carries the leaf cut-outs).
		standard.cull_mode = BaseMaterial3D.CULL_DISABLED
		if standard.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and standard.albedo_texture != null:
			var image := standard.albedo_texture.get_image()
			if image != null:
				if image.is_compressed():
					image.decompress()
				if image.detect_alpha() != Image.ALPHA_NONE:
					standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					standard.alpha_scissor_threshold = .45
					standard.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	if standard.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or standard.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		var name := standard.resource_name.to_lower()
		var foliage := false
		for hint: String in FOLIAGE_HINTS:
			if name.contains(hint):
				foliage = true
		if foliage or standard.albedo_texture != null:
			standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			standard.alpha_scissor_threshold = .45
			standard.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			standard.cull_mode = BaseMaterial3D.CULL_DISABLED
