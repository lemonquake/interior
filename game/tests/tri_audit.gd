extends SceneTree
## 0.33: where the triangles are. Every mesh in the finished world, grouped by mesh, with how many times it stands
## in the world, whether it has levels of detail, whether it throws a shadow and how far it is drawn.
##   godot --path game --script res://tests/tri_audit.gd -- [--near=x,y,z,radius]

func _initialize() -> void:
	call_deferred("_run")

func _triangles(mesh: Mesh) -> Array:
	var total := 0
	var lods := 0
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var array_mesh := mesh as ArrayMesh
			var count := array_mesh.surface_get_array_index_len(surface)
			if count <= 0:
				count = array_mesh.surface_get_array_len(surface)
			total += count / 3
			var data := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
			lods = maxi(lods, (data.get("lods", []) as Array).size())
		else:
			var arrays := mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			total += ((indices as PackedInt32Array).size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return [total, lods]

func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await process_frame
	var centre := Vector3.ZERO
	var radius := 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--near="):
			var parts := argument.trim_prefix("--near=").split(",")
			centre = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
			radius = float(parts[3])
	var groups := {}
	var cache := {}
	var world := 0
	for node in main.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var copies := 1
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
			copies = (node as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null or not (node as Node3D).is_visible_in_tree():
			continue
		var gi := node as GeometryInstance3D
		if radius > 0.0 and (gi.global_transform * gi.get_aabb()).get_center().distance_to(centre) > radius:
			continue
		if not cache.has(mesh):
			cache[mesh] = _triangles(mesh)
		var info: Array = cache[mesh]
		var key := mesh.resource_path if mesh.resource_path != "" else "%s / %s" % [node.get_parent().name, node.name]
		if not groups.has(key):
			groups[key] = {"mesh": key.right(70), "each": info[0], "lods": info[1], "placed": 0, "triangles": 0, "shadow": 0, "range": 0.0, "multi": node is MultiMeshInstance3D}
		var g: Dictionary = groups[key]
		g.placed += copies
		g.triangles += int(info[0]) * copies
		g.shadow += 1 if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
		g.range = maxf(g.range, gi.visibility_range_end)
		world += int(info[0]) * copies
	var rows := groups.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.triangles > b.triangles)
	print("TRI_AUDIT_TOTAL ", world, " triangles in ", rows.size(), " meshes")
	for index in mini(rows.size(), 40):
		print("TRI_AUDIT ", JSON.stringify(rows[index]))
	quit()
