extends SceneTree
## Geometry and traversal evidence for the three newly photographed room sides.

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _hit(world: World3D, from: Vector3, to: Vector3, mask := 2) -> Dictionary:
	return world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,mask))

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	check(not main.control_lab,"Actual furnished room loads")
	check(main.room.has_meta("reference_room_stats"),"Reference surroundings module is integrated")
	if not main.room.has_meta("reference_room_stats"):
		print("INTERIOR_SURROUNDINGS_INTEGRATION ",JSON.stringify({"passed":false,"checks":checks,"failures":failures}))
		quit(1)
		return
	var stats: Dictionary = main.room.get_meta("reference_room_stats")
	check(stats.triangles_removed > 0,"Previous closed side shell is removed")
	check(stats.static_batches <= 48,"Material batches stay within Android budget")
	check(stats.family_photos >= 5,"Family photo gallery uses actual supplied images (decluttered to five frames)")
	check(stats.dynamic_props == 11,"Eleven styled props (cups, bowl, oranges, bottles, balls) have independent rigid bodies")
	check(stats.colliders >= 30,"New room surfaces and large furniture have collisions")
	var backwards := 0
	var inspected := 0
	var kitchen_cabinet_vertices := 0
	var right_slat_vertices := 0
	var fridge_vertices := 0
	var window_bar_vertices := 0
	var right_cabinet_vertices := 0
	for detail in main.room.get_node("ReferenceRoomSurroundings").get_children():
		if not detail is MeshInstance3D: continue
		for surface in detail.mesh.get_surface_count():
			var arrays: Array = detail.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			# Count only indexed vertices referenced by the final render mesh.
			# This detects a shared-material batching regression even when the
			# construction counters and physical colliders still look correct.
			for index in indices:
				var vertex := vertices[index]
				if "navy" in detail.name and AABB(Vector3(-5.66,.08,-2.55),Vector3(.84,.77,5.06)).has_point(vertex):
					kitchen_cabinet_vertices += 1
				if "slat" in detail.name and AABB(Vector3(3.24,0,-2.7),Vector3(.08,2.91,5.4)).has_point(vertex):
					right_slat_vertices += 1
				if "black steel" in detail.name and AABB(Vector3(-4.24,0,-2.55),Vector3(.71,1.92,.78)).has_point(vertex):
					fridge_vertices += 1
				if "black steel" in detail.name and AABB(Vector3(-5.64,1.47,-2.40),Vector3(.14,1.30,4.62)).has_point(vertex):
					window_bar_vertices += 1
				if "ivory" in detail.name and AABB(Vector3(2.75,0,1.76),Vector3(.55,2.04,.70)).has_point(vertex):
					right_cabinet_vertices += 1
			for i in range(0,indices.size(),3):
				var ia := indices[i]
				var ib := indices[i+1]
				var ic := indices[i+2]
				var cross := (vertices[ib]-vertices[ia]).cross(vertices[ic]-vertices[ia])
				var normal := (normals[ia]+normals[ib]+normals[ic])/3
				if cross.dot(normal) > .0000001: backwards += 1
				inspected += 1
	check(backwards == 0,"All new surfaces use outward Godot clockwise winding (%d reversed of %d)"%[backwards,inspected])
	check(inspected == stats.triangles_added,"Final rendered triangles match construction count (%d actual, %d expected)"%[inspected,stats.triangles_added])
	check(kitchen_cabinet_vertices > 1500,"Final navy material contains the visible kitchen cabinet geometry")
	check(right_slat_vertices > 1500,"Final slat material contains the visible right-wall geometry")
	check(fridge_vertices >= 100,"Final black-steel material contains the visible refrigerator")
	check(window_bar_vertices > 1000,"Final black-steel material contains the visible kitchen window bars")
	check(right_cabinet_vertices > 200,"Final ivory material contains the visible right storage cabinet")
	main._play()
	for i in 5: await physics_frame
	var world: World3D = main.get_world_3d()
	check(_hit(world,Vector3(-3.0,1.3,1.95),Vector3(-4.7,1.3,1.95)).is_empty(),"Kitchen doorway is genuinely open")
	check(not _hit(world,Vector3(-4.35,1,1.95),Vector3(-4.35,-.5,1.95)).is_empty(),"Kitchen extension has supporting floor")
	check(not _hit(world,Vector3(-4.35,1.3,.2),Vector3(-6.0,1.3,.2)).is_empty(),"Kitchen has a solid far wall")
	check(not _hit(world,Vector3(-4.4,2.5,0),Vector3(-4.4,3.5,0)).is_empty(),"Kitchen has a solid ceiling")
	check(not _hit(world,Vector3(1.91,1.2,2.0),Vector3(1.91,1.2,3.2)).is_empty(),"Rear entry door at screen-left is a closed solid boundary")
	check(not _hit(world,Vector3(2.6,1.2,-.2),Vector3(3.8,1.2,-.2)).is_empty(),"Right gallery wall has collision")
	check(_hit(world,Vector3(-2.5,1.6,2.2),Vector3(-2.5,1.6,3.3)).is_empty(),"Studio niche at screen-right has a real opening")
	check(not _hit(world,Vector3(-2.5,1,3.45),Vector3(-2.5,-.5,3.45)).is_empty(),"Reflected studio opening retains its supporting floor")
	check(not _hit(world,Vector3(-2.5,1.3,3.45),Vector3(-2.5,1.3,4.1)).is_empty(),"Reflected studio retains a solid rear boundary")
	check(not _hit(world,Vector3(-2.5,2.5,3.45),Vector3(-2.5,3.5,3.45)).is_empty(),"Reflected studio retains its solid ceiling")
	# Use the actual accelerating player, collider and floor contact to enter.
	main.player.global_position = Vector3(-2.90,.08,1.93)
	main.player.rotation = Vector3.ZERO
	main.player.velocity = Vector3.ZERO
	main.player.touch_move = Vector2(-1,0)
	for i in 52: await physics_frame
	main.player.touch_move = Vector2.ZERO
	check(main.player.position.x < -3.8,"Player can walk through left opening into kitchen")
	for i in 30: await physics_frame
	check(main.player.position.y > -.08 and main.player.position.y < .08,"Player remains on kitchen floor")
	var cup := main.room.get_node_or_null("Kitchen cup 1") as InteriorObject
	check(cup != null,"Reachable cup is a real physics object")
	if cup != null:
		cup.activate(true)
		cup.apply_central_impulse(Vector3(.35,.15,0))
		for i in 90: await physics_frame
		check(cup.position.is_finite() and cup.position.y > -.1,"Kitchen cup collides and stays above floor after an impulse")
	# Idempotence protects restart or repeated visual setup from duplicates.
	var before := get_nodes_in_group("movable").size()
	InteriorRoomSurroundings.apply(main.room,main.room.get_node("LivingRoomVisual"),main.room_manifest)
	check(get_nodes_in_group("movable").size() == before,"Repeated surroundings setup does not duplicate props")
	print("INTERIOR_SURROUNDINGS_INTEGRATION ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"stats":stats,"actual_rendered_triangles":inspected,"visible_geometry_vertices":{"kitchen_cabinets":kitchen_cabinet_vertices,"right_slats":right_slat_vertices,"fridge":fridge_vertices,"window_bars":window_bar_vertices,"right_cabinet":right_cabinet_vertices},"kitchen_player_position":[main.player.position.x,main.player.position.y,main.player.position.z]}))
	quit(0 if failures.is_empty() else 1)
