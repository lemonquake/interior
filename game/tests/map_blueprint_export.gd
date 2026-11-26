extends SceneTree
## Read-only runtime inventory for docs/map-blueprint. Does not bake or export the game.
var main: Node
var records: Array = []
var output := "res://../docs/map-blueprint/runtime-scene.json"

func _initialize() -> void:
	_run.call_deferred()

func v(p: Vector3) -> Array:
	return [snappedf(p.x, .0001), snappedf(p.y, .0001), snappedf(p.z, .0001)]

func data(value: Variant) -> Variant:
	if value is Vector3: return v(value)
	if value is Vector2: return [value.x, value.y]
	if value is Vector4: return [value.x, value.y, value.z, value.w]
	if value is Dictionary:
		var result := {}
		for key in value: result[String(key)] = data(value[key])
		return result
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedStringArray:
		var result: Array = []
		for item in value: result.append(data(item))
		return result
	if value is Object: return str(value)
	return value

func bounds(points: PackedVector3Array, transform: Transform3D) -> Dictionary:
	if points.is_empty(): return {}
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var projected := PackedVector2Array()
	for p in points:
		var w := transform * p
		lo = lo.min(w)
		hi = hi.max(w)
		projected.append(Vector2(w.x, w.z))
	var footprint: Array = []
	for p in Geometry2D.convex_hull(projected): footprint.append([snappedf(p.x, .0001), snappedf(p.y, .0001)])
	return {"min": v(lo), "max": v(hi), "projected_points_xz": footprint}

func corners(box: AABB) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in 8: result.append(box.get_endpoint(i))
	return result

func visit(node: Node) -> void:
	var path := String(main.get_path_to(node))
	var row := {"id": "N-" + path.sha256_text().substr(0, 12), "path": path, "name": String(node.name), "type": node.get_class()}
	var script = node.get_script()
	if script != null: row["script"] = script.resource_path
	if script != null:
		var properties := {}
		for key in ["display_name", "locked", "angle", "open_angle", "state", "kind", "action", "label", "has_key", "drawer_open", "gun_taken", "flashlight_taken", "lights_on"]:
			if key in node: properties[key] = data(node.get(key))
		if not properties.is_empty(): row["gameplay"] = properties
	if not node.scene_file_path.is_empty(): row["scene"] = node.scene_file_path
	if not node.get_groups().is_empty(): row["groups"] = node.get_groups()
	var metadata := {}
	for key in node.get_meta_list():
		if String(key).begins_with("_"): continue
		metadata[String(key)] = data(node.get_meta(key))
	if not metadata.is_empty(): row["metadata"] = metadata
	if node is InteriorHutHouse:
		row["route_in"] = data(node.route_in)
		row["crow_route"] = data(node.crow_route)
	if node is Node3D:
		row["position"] = v(node.global_position)
		row["local_position"] = v(node.position)
		row["basis_columns"] = [v(node.global_basis.x), v(node.global_basis.y), v(node.global_basis.z)]
		row["visible"] = node.visible
	if node is CollisionObject3D:
		row["collision_layer"] = node.collision_layer
		row["collision_mask"] = node.collision_mask
	if node is Light3D:
		row["light_energy"] = node.light_energy
		row["light_color"] = [node.light_color.r, node.light_color.g, node.light_color.b]
		row["light_cull_mask"] = node.light_cull_mask
	if node is MeshInstance3D and node.mesh != null:
		row["mesh_bounds"] = bounds(corners(node.get_aabb()), node.global_transform)
		row["mesh_resource"] = node.mesh.resource_path
		row["visual_layers"] = node.layers
	if node is MultiMeshInstance3D and node.multimesh != null:
		row["multimesh_count"] = node.multimesh.instance_count
		row["mesh_bounds"] = bounds(corners(node.get_aabb()), node.global_transform)
	if node is CollisionShape3D and node.shape != null:
		row["disabled"] = node.disabled
		row["shape"] = node.shape.get_class()
		var points := PackedVector3Array()
		if node.shape is BoxShape3D:
			row["shape_size"] = v(node.shape.size)
			points = corners(AABB(-node.shape.size * .5, node.shape.size))
		elif node.shape is ConvexPolygonShape3D: points = node.shape.points
		elif node.shape is ConcavePolygonShape3D:
			# Preserve its envelope; an envelope is not a walkability polygon.
			var faces: PackedVector3Array = node.shape.get_faces()
			if not faces.is_empty():
				var box := AABB(faces[0], Vector3.ZERO)
				for p in faces: box = box.expand(p)
				points = corners(box)
		elif node.shape is CylinderShape3D:
			points = corners(AABB(Vector3(-node.shape.radius, -node.shape.height * .5, -node.shape.radius), Vector3(node.shape.radius * 2, node.shape.height, node.shape.radius * 2)))
		elif node.shape is SphereShape3D:
			points = corners(AABB(Vector3.ONE * -node.shape.radius, Vector3.ONE * node.shape.radius * 2))
		elif node.shape is CapsuleShape3D:
			points = corners(AABB(Vector3(-node.shape.radius, -node.shape.height * .5, -node.shape.radius), Vector3(node.shape.radius * 2, node.shape.height, node.shape.radius * 2)))
		if not points.is_empty(): row["collision_bounds"] = bounds(points, node.global_transform)
	records.append(row)
	for child in node.get_children(): visit(child)

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	if not main.has_method("_play"):
		push_error("Main scene could not load; import the project first.")
		quit(1)
		return
	main._play()
	for i in 45: await process_frame
	for i in 10: await physics_frame
	get_tree_pause()
	visit(main)
	var report := {"schema": "sleep-map-runtime-v1", "root": "Interior", "units": "metres", "coordinate_system": "Godot: X east, Y up, Z north by project convention", "precision_m": .0001, "node_count": records.size(), "nodes": records}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("MAP_BLUEPRINT_EXPORTED ", records.size(), " nodes to ", output)
	quit()

func get_tree_pause() -> void:
	paused = true
