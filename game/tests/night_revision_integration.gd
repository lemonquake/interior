extends SceneTree
## Real-player traversal in both directions, intermittent lights, window blackout, safe NPC return.
var main: Node
var player: InteriorPlayer
var failures: Array[String] = []
var checks := 0
var lowest := INF

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
	print(("PASS " if ok else "FAIL ") + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func walk(target: Vector3, limit := 700) -> bool:
	for i in limit:
		var to := target - player.global_position
		to.y = 0.0
		if to.length() < .25:
			player.touch_move = Vector2.ZERO
			await frames(3)
			return true
		player.rotation.y = atan2(-to.x, -to.z)
		player.touch_move = Vector2(0, -1)
		lowest = minf(lowest, player.global_position.y)
		await physics_frame
	player.touch_move = Vector2.ZERO
	print("STUCK ", player.global_position, " target ", target)
	return false

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(6)
	player = main.player
	var hut: InteriorHutHouse = main.story.hut
	var man: InteriorStranger = main.get_node("Stranger")
	man.process_mode = Node.PROCESS_MODE_DISABLED
	check(InteriorStory.CALL_LINES == ["You have to hurry!", "Your wife and 2 daughters are with the association, so you can breathe easy.", "Now, I have to give you something. Please follow me."], "All requested opening dialogue is exact")
	check(InteriorStory.RUN_LINE == "Now, take these with you and go back! Hurry, before they notice!", "Requested ammo dialogue is exact")
	check(hut.get_meta("cleared_vegetation", []).has("tree_small_02"), "Hut tree removed from the turning area")
	check(hut.get_meta("cleared_vegetation", []).has("bamboo_clump10"), "Bamboo across the footpath removed")
	print("CLEARED ", hut.get_meta("cleared_vegetation", []))
	var reversed := 0
	var bad_support := 0
	var fields: Node3D = main.get_node("Fields")
	for label in ["Footpath", "Scarecrow dike"]:
		var path_root := fields.get_node(label)
		for mesh: MeshInstance3D in path_root.find_children("*", "MeshInstance3D", true, false):
			var arrays := mesh.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			else:
				for i in vertices.size():
					indices.append(i)
			for i in range(0,indices.size(),3):
				var a := vertices[indices[i]]
				var b := vertices[indices[i+1]]
				var c := vertices[indices[i+2]]
				if (b-a).cross(c-a).dot(normals[indices[i]]) >= 0:
					reversed += 1
			if String(mesh.name).ends_with(" top"):
				var centre_top := Vector3.ZERO
				for v in vertices:
					centre_top += v
				centre_top /= vertices.size()
				var q := PhysicsRayQueryParameters3D.create(centre_top+Vector3.UP,centre_top+Vector3.DOWN,2)
				var hit := fields.get_world_3d().direct_space_state.intersect_ray(q)
				if hit.is_empty() or absf(hit.position.y-centre_top.y) > .015:
					bad_support += 1
	check(reversed == 0, "Path and island triangles face outward and shade correctly")
	check(bad_support == 0, "Visible causeway surfaces match their collision heights")
	var route: Array[Vector3] = hut.route_in.duplicate()
	route.reverse()
	route.append_array(man.road_range(0.0, hut.crow_index, hut.road_index))
	route.append_array(hut.crow_route)
	player.reset_motion(route[0] + Vector3.UP * .55)
	await frames(20)
	var outward := true
	for point in route.slice(1):
		if not await walk(point):
			outward = false
			break
	check(outward, "Continuous walk from inside hut to ammo island without teleporting or jumping")
	var frame := hut.crow_frame()
	var centre: Vector3 = frame[0]
	var to_road: Vector3 = frame[1]
	var across := Vector3(-to_road.z, 0, to_road.x)
	var circle := true
	for offset in [to_road * 1.2, across * 1.25, -to_road * 1.25, -across * 1.25, to_road * 1.2]:
		circle = await walk(centre + offset, 260) and circle
	check(circle, "Player can circle the scarecrow with room to turn")
	var back := true
	route.reverse()
	for point in route:
		if not await walk(point):
			back = false
			break
	check(back, "Continuous return from ammo island through the hut doorway")
	check(lowest > -3.2, "Ground supports the player throughout (lowest %.3f)" % lowest)
	# Test two tracks on each causeway, not just the centre line.
	for path: Array in [hut.route_in.slice(0,3), hut.crow_route.slice(0,3)]:
		var a: Vector3 = path[1]
		var b: Vector3 = path[2]
		var dir := (b-a).normalized()
		var lateral := Vector3(-dir.z,0,dir.x)
		for side in [-.5,.5]:
			player.reset_motion(a + lateral * side + Vector3.UP * .2)
			await frames(12)
			check(await walk(b + lateral * side), "Causeway side track %.1f reaches far end" % side)
	# Bring the box back to someone who stayed on the road; sample support throughout the NPC route.
	man._hut = hut
	man._scarecrow = main.get_node("Fields").find_child("Scarecrow", true, false)
	man.global_position = man.dig_spot()
	man.state = InteriorStranger.State.BRINGING
	man._return_poll = 0.0
	man.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.reset_motion(hut.crow_route[0] + Vector3.UP * .15)
	await frames(10)
	var waded := false
	for i in 1600:
		if man.state == InteriorStranger.State.GIVING:
			break
		waded = waded or man._wading or man.global_position.y < -3.2
		await physics_frame
	check(man.state == InteriorStranger.State.GIVING, "Man reaches a player waiting on the road")
	check(not waded, "Man follows dry ground while returning the ammo")
	var reached_all := true
	for side in 8:
		var angle := TAU * side / 8.0
		player.reset_motion(centre + Vector3(cos(angle), .15, sin(angle)) * 1.5)
		man.global_position = man.dig_spot()
		man.state = InteriorStranger.State.BRINGING
		man._return_poll = 0.0
		for i in 1200:
			if man.state == InteriorStranger.State.GIVING:
				break
			await physics_frame
		reached_all = reached_all and man.state == InteriorStranger.State.GIVING
		if man.state != InteriorStranger.State.GIVING:
			print("ISLAND_APPROACH_FAILED ", side, " man ", man.global_position, " player ",player.global_position)
	check(reached_all, "Ammo reaches a player on any of eight sides of the island")
	man.process_mode = Node.PROCESS_MODE_DISABLED
	# Lighting review is a timed simulation: all three lamps must fail briefly and recover separately.
	var balcony: InteriorBalcony = main.get_node("Balcony")
	player.reset_motion(Vector3(21, -2.75, 33))
	await frames(25)
	var minima := [10.0,10.0,10.0]
	var maxima := [0.0,0.0,0.0]
	var independent := false
	for i in 60 * 32:
		for j in balcony._street_lamps.size():
			var energy := balcony._street_lamps[j].light_energy
			minima[j] = minf(minima[j], energy)
			maxima[j] = maxf(maxima[j], energy)
		independent = independent or absf(balcony._street_lamps[0].light_energy - balcony._street_lamps[1].light_energy) > .3
		await physics_frame
	for j in 3:
		check(minima[j] < .08 and maxima[j] > .8 and maxima[j] < 1.0, "Street lamp %d flickers and recovers at dim energy" % j)
	check(independent, "Street lamps flicker independently")
	var before := balcony._street_lamps[0].light_energy
	paused = true
	await frames(30)
	check(is_equal_approx(before,balcony._street_lamps[0].light_energy), "Flicker freezes while paused")
	paused = false
	var neighborhood: InteriorNeighborhood = get_first_node_in_group("neighbourhood")
	var windows := 0
	for mesh: MeshInstance3D in neighborhood.find_children("*", "MeshInstance3D", true, false):
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null and ("curtain" in mat.resource_name or "window glass" in mat.resource_name):
			windows += 1
			check(not mat.emission_enabled and mat.albedo_color.get_luminance() < .07, "Neighbor window batch is dark: " + str(mesh.name))
	check(windows == 4, "All four window material batches checked")
	var stats: Dictionary = neighborhood.get_meta("abandoned_town").vehicles
	check(stats.models == 12 and stats.surfaces >= 60, "Tricycles, jeepney, carts and drums receive worn PBR surfaces")
	print("NIGHT_REVISION ", JSON.stringify({"checks":checks,"failures":failures,"lowest_y":lowest,"lamp_min":minima,"lamp_max":maxima,"vehicles":stats}))
	quit(0 if failures.is_empty() else 1)
