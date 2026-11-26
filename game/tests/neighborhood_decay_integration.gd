extends SceneTree
## Inspect emitted geometry and traverse the real scene after the neighborhood update.
## --headless --fixed-fps 60 --path game --script res://tests/neighborhood_decay_integration.gd
## Rendering and appearance are reviewed separately with neighborhood_review.gd.

const DETAIL_NAMES := ["Abandoned town details", "Derelict facades"]
const REVIEW_CAMERAS := [
	[Vector3(20.2, -1.32, 6.0), Vector3(20.5, -1.65, 31.0)],
	[Vector3(17.8, -1.32, 18.2), Vector3(-8.0, -1.7, 18.0)],
	[Vector3(21.7, -1.10, 30.0), Vector3(24.25, -1.45, 33.0)],
	[Vector3(20.8, -1.25, 37.0), Vector3(22.85, -2.71, 42.5)],
]

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var lowest := INF

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _walk_to(target: Vector3, max_frames := 700) -> bool:
	for i in max_frames:
		var direction := target - player.global_position
		direction.y = 0.0
		if direction.length() < .35:
			player.touch_move = Vector2.ZERO
			return true
		player.rotation = Vector3(0, atan2(-direction.x, -direction.z), 0)
		player.touch_move = Vector2(0, -1)
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
	player.touch_move = Vector2.ZERO
	return false

func _inspect_geometry(detail: Node3D) -> Dictionary:
	var triangles := 0
	var reversed := 0
	var invalid := 0
	var degenerates := 0
	var bad_layers := 0
	var upward_street_triangles := 0
	var vertical_triangles := 0
	var batches := 0
	var samples: Array[Array] = []
	var meshes := detail.find_children("*", "MeshInstance3D", true, false)
	if detail is MeshInstance3D:
		meshes.append(detail)
	for node: Node in meshes:
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		if instance.layers != 2:
			bad_layers += 1
		for surface in instance.mesh.get_surface_count():
			if instance.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			batches += 1
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if normals.size() != vertices.size():
				invalid += 1
				continue
			var referenced := indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0, referenced - 2, 3):
				var ia := indices[i] if not indices.is_empty() else i
				var ib := indices[i + 1] if not indices.is_empty() else i + 1
				var ic := indices[i + 2] if not indices.is_empty() else i + 2
				var a := vertices[ia]
				var b := vertices[ib]
				var c := vertices[ic]
				var normal := (normals[ia] + normals[ib] + normals[ic]) / 3.0
				triangles += 1
				if not a.is_finite() or not b.is_finite() or not c.is_finite() or not normal.is_finite() or normal.length_squared() < .01:
					invalid += 1
					continue
				var cross := (b - a).cross(c - a)
				if cross.length_squared() < 0.000000000001:
					degenerates += 1
					continue
				if cross.normalized().dot(normal.normalized()) > .05:
					reversed += 1
				var center := instance.global_transform * ((a + b + c) / 3.0)
				var world_normal := (instance.global_basis.inverse().transposed() * normal).normalized()
				if center.y > -2.95 and center.y < -2.48 and world_normal.y > .75:
					upward_street_triangles += 1
				if absf(world_normal.y) < .15:
					vertical_triangles += 1
				# Sample final mesh faces, not generator metadata, for camera visibility.
				if triangles % 7 == 0:
					samples.append([center, world_normal])
	var camera := player.camera
	var in_view := 0
	for view: Array in REVIEW_CAMERAS:
		camera.global_position = view[0]
		camera.look_at(view[1])
		camera.fov = 72.0
		for sample: Array in samples:
			var center: Vector3 = sample[0]
			var normal: Vector3 = sample[1]
			if camera.is_position_in_frustum(center) and normal.dot(camera.global_position - center) > .02:
				in_view += 1
	check(triangles > 0, str(detail.name) + " contains emitted render triangles")
	check(invalid == 0, "%s has finite vertices and usable normals (%d invalid)" % [detail.name, invalid])
	check(reversed == 0, "%s has outward Godot clockwise winding (%d reversed of %d)" % [detail.name, reversed, triangles])
	check(degenerates == 0, "%s has no zero-area render triangles (%d degenerate)" % [detail.name, degenerates])
	check(bad_layers == 0, "%s geometry is lit only on outdoor layer 2 (%d wrong layers)" % [detail.name, bad_layers])
	check(in_view > 0, "%s includes front-facing geometry inside street-level review camera frusta" % detail.name)
	return {"triangles": triangles, "mesh_instances": meshes.size(), "material_batches": batches,
		"sampled_faces_in_street_views": in_view, "upward_street_triangles": upward_street_triangles,
		"vertical_triangles": vertical_triangles, "reversed": reversed, "invalid": invalid,
		"degenerate": degenerates}

func _weathered_surfaces(neighborhood: Node) -> int:
	var count := 0
	for node: Node in neighborhood.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface) as ShaderMaterial
			if material != null and material.shader != null and "weather" in material.shader.resource_path.to_lower():
				count += 1
	return count

func _run() -> void:
	seed(130013)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(8)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.camera.global_position = REVIEW_CAMERAS[0][0]
	await _frames(4)
	var details: Array[Node3D] = []
	for label: String in DETAIL_NAMES:
		var detail := main.find_child(label, true, false) as Node3D
		check(detail != null, label + " is integrated into the playable scene")
		if detail != null:
			details.append(detail)
			check(detail.is_visible_in_tree(), label + " is visible while outside")
			results[label] = _inspect_geometry(detail)
	var neighborhood := get_first_node_in_group("neighbourhood")
	check(neighborhood != null, "Existing neighborhood remains integrated")
	if neighborhood != null:
		var weathered := _weathered_surfaces(neighborhood)
		results["weathered_material_surfaces"] = weathered
		check(weathered > 0, "Neighborhood render meshes actually use the weathering shader")
	var world: World3D = main.get_world_3d()
	for point: Vector3 in [Vector3(13.6, -2.9, 3.9), Vector3(21.4, -2.9, 18.6), Vector3(-5, -2.9, 18), Vector3(21, -2.9, 43), Vector3(21, -2.9, 54)]:
		var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN, 2))
		check(not hit.is_empty() and Vector3(hit.get("normal", Vector3.ZERO)).y > .7, "Street route has upward supporting collision at " + str(point))
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.reset_motion(Vector3(13.6, -2.85, 3.9))
	await _frames(8)
	for point: Vector3 in [Vector3(17.0, -2.9, 4.6), Vector3(21.4, -2.9, 6.0), Vector3(21.4, -2.9, 18.6), Vector3(10, -2.9, 18), Vector3(-5, -2.9, 18)]:
		var reached := await _walk_to(point)
		check(reached, "Real player traverses dressed street to %s (reached %s)" % [point, player.global_position])
		if not reached:
			break
	# 0.23: the town wall closes the old exit; the way out is the hole, crouching.
	player.reset_motion(Vector3(InteriorTownSiege.HOLE_X, -2.85, 50.0))
	await _frames(8)
	player.touch_crouching = true
	check(await _walk_to(Vector3(InteriorTownSiege.HOLE_X, -2.9, 57)), "The street-to-fields exit remains walkable (crouching through the hole)")
	player.touch_crouching = false
	check(lowest > -3.05, "Traversal stays on solid ground (lowest y %.3f)" % lowest)
	results["lowest_player_y"] = lowest
	player.reset_motion(Vector3(.6, .08, 1.3))
	await _frames(8)
	for detail: Node3D in details:
		check(not detail.is_visible_in_tree(), str(detail.name) + " is culled behind the closed house door")
	print("INTERIOR_NEIGHBORHOOD_DECAY_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	main.queue_free()
	main = null
	player = null
	for i in 8:
		await process_frame
	quit(0 if failures.is_empty() else 1)
