extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 5:
		await physics_frame
	var hut: InteriorHutHouse = main.story.hut
	print("ROUTES ", hut.route_in, " CROW ", hut.crow_route)
	var fields: Node3D = main.get_node("Fields")
	for node: Node in fields.find_children("*", "Node3D", true, false):
		if node.has_meta("tree") and (node as Node3D).global_position.distance_to(hut.global_position) < 22.0:
			print("TREE ", node.get_path(), " ", InteriorModelKit.bounds_in(node, fields))
	var shape := CapsuleShape3D.new()
	shape.radius = .32
	shape.height = 1.72
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 2
	var route: Array[Vector3] = hut.route_out()
	var man: InteriorStranger = main.get_node("Stranger")
	route.append_array(man.road_range(0.0, hut.crow_index, hut.road_index))
	route.append_array(hut.crow_route)
	var found := {}
	for k in range(1, route.size()):
		var a := route[k - 1]
		var b := route[k]
		for j in range(1 + int(a.distance_to(b) / .2)):
			var p := a.lerp(b, clampf(j * .2 / maxf(a.distance_to(b), .001), 0, 1))
			q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.05)
			for hit in fields.get_world_3d().direct_space_state.intersect_shape(q):
				var body: CollisionObject3D = hit.collider
				var owner := body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
				var path := str(owner.get_path())
				if not found.has(path):
					found[path] = true
					print("BLOCK ", path, " at ", p)
	for node: Node in main.find_children("*tricycle*", "Node3D", true, false):
		if not node.has_meta("keep_instance"):
			continue
		print("VEHICLE ", node.get_path())
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for s in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(s) as StandardMaterial3D
				if mat != null:
					print("MAT ", mat.resource_name, " ", mat.albedo_color, " tex ", mat.albedo_texture != null, " metal ", mat.metallic)
		break
	quit()
