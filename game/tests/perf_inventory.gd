extends SceneTree
## 0.26 performance inventory: what the world costs to draw and to step.
##   Godot --headless --path game --script res://tests/perf_inventory.gd
## Prints the heaviest geometry instances (triangles x instances), totals per area, lights, shadow casters,
## rigid bodies and the nodes that tick every frame.

var main: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

static func tris_of(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for s in mesh.get_surface_count():
		var arrays_len := 0
		if mesh is ArrayMesh:
			var am := mesh as ArrayMesh
			var index_len := am.surface_get_array_index_len(s)
			arrays_len = index_len if index_len > 0 else am.surface_get_array_len(s)
		else:
			var arrays := mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
				arrays_len = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
			elif arrays.size() > 0 and arrays[Mesh.ARRAY_VERTEX] != null:
				arrays_len = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		total += arrays_len / 3
	return total

func _area(node: Node) -> String:
	var path := str(main.get_path_to(node))
	var parts := path.split("/")
	var take := 1
	if parts[0] == "Balcony":
		take = 3 if parts.size() > 2 and parts[1] == "Neighbourhood" else 2
	return "/".join(parts.slice(0, mini(take, parts.size())))

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(40)
	for i in 10: await physics_frame
	var rows: Array = []
	var by_area := {}
	var draws_by_area := {}
	var mesh_cache := {}
	for node in main.find_children("*", "GeometryInstance3D", true, false):
		var tris := 0
		var surfaces := 1
		var label := ""
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh == null: continue
			if not mesh_cache.has(mesh): mesh_cache[mesh] = tris_of(mesh)
			tris = mesh_cache[mesh]
			surfaces = mesh.get_surface_count()
		elif node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null: continue
			if not mesh_cache.has(mm.mesh): mesh_cache[mm.mesh] = tris_of(mm.mesh)
			tris = int(mesh_cache[mm.mesh]) * (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
			surfaces = mm.mesh.get_surface_count()
			label = " x%d" % mm.instance_count
		else:
			continue
		var gi := node as GeometryInstance3D
		var area := _area(node)
		by_area[area] = int(by_area.get(area, 0)) + tris
		draws_by_area[area] = int(draws_by_area.get(area, 0)) + surfaces
		rows.append([tris, str(main.get_path_to(node)) + label, gi.visibility_range_end, gi.cast_shadow, gi.is_visible_in_tree(), gi.global_position])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("PERF_TOP")
	for i in mini(70, rows.size()):
		var r: Array = rows[i]
		print("  %9d  vis=%s range=%.0f shadow=%d  %s  @%s" % [r[0], r[4], r[2], r[3], r[1], str((r[5] as Vector3).snappedf(1.0))])
	print("PERF_AREAS")
	var areas := by_area.keys()
	areas.sort_custom(func(a, b): return by_area[a] > by_area[b])
	for area in areas:
		print("  %10d tris  %6d surfaces  %s" % [by_area[area], draws_by_area[area], area])
	var lights := main.find_children("*", "Light3D", true, false)
	var shadowed := 0
	var visible_lights := 0
	for light: Light3D in lights:
		if light.is_visible_in_tree():
			visible_lights += 1
			if light.shadow_enabled: shadowed += 1
	print("PERF_LIGHTS total=%d visible=%d shadowed=%d" % [lights.size(), visible_lights, shadowed])
	for light: Light3D in lights:
		if light.is_visible_in_tree() and light.shadow_enabled:
			print("  shadow light: ", main.get_path_to(light))
	var bodies := main.find_children("*", "RigidBody3D", true, false)
	var awake := 0
	var frozen := 0
	for body: RigidBody3D in bodies:
		if body.freeze: frozen += 1
		elif not body.sleeping: awake += 1
	print("PERF_BODIES rigid=%d frozen=%d awake=%d static=%d animatable=%d shapes=%d areas=%d" % [bodies.size(), frozen, awake,
		main.find_children("*", "StaticBody3D", true, false).size(), main.find_children("*", "AnimatableBody3D", true, false).size(),
		main.find_children("*", "CollisionShape3D", true, false).size(), main.find_children("*", "Area3D", true, false).size()])
	var ticking := {}
	var physics_ticking := {}
	for node in main.find_children("*", "", true, false):
		var script: Script = node.get_script()
		var key := script.resource_path.get_file() if script != null else node.get_class()
		if node.is_processing() and node.can_process():
			ticking[key] = int(ticking.get(key, 0)) + 1
		if node.is_physics_processing() and node.can_process():
			physics_ticking[key] = int(physics_ticking.get(key, 0)) + 1
	print("PERF_PROCESS ", ticking)
	print("PERF_PHYSICS_PROCESS ", physics_ticking)
	print("PERF_NODES ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " particles=", main.find_children("*", "GPUParticles3D", true, false).size(),
		" decals=", main.find_children("*", "Decal", true, false).size(), " probes=", main.find_children("*", "ReflectionProbe", true, false).size(),
		" audio3d=", main.find_children("*", "AudioStreamPlayer3D", true, false).size())
	quit()
