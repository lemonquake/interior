extends SceneTree
## Balcony, stair and courtyard behind the hinged navy entry door, driven with the real
## player: closed door blocks, E opens it, walk out to the aquarium wall, down the stair
## to the courtyard and back into the room; thrown props stay inside the bounds; fish
## swim; daylight is isolated from the room.

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var lowest := INF

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

## Steers the actual player toward `target` with the touch move axis.
func _walk_to(target: Vector3, max_frames := 420, tolerance := .22) -> bool:
	for i in max_frames:
		var delta := target - player.global_position
		delta.y = 0.0
		if delta.length() < tolerance:
			player.touch_move = Vector2.ZERO
			return true
		player.rotation = Vector3(0, atan2(-delta.x, -delta.z), 0)
		player.touch_move = Vector2(0, -1)
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
	player.touch_move = Vector2.ZERO
	return false

func _place(at: Vector3, yaw: float) -> void:
	player.reset_motion(at)
	player.rotation = Vector3(0, yaw, 0)
	await _frames(6)

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(4)
	player = main.player
	var balcony := main.get_node_or_null("Balcony") as Node3D
	check(balcony != null, "main.tscn instances the baked balcony scene")
	var doors := get_nodes_in_group("interior_doors")
	check(doors.size() == 1, "Exactly one hinged entry door")
	if balcony == null or doors.is_empty():
		_finish()
		return
	var door := doors[0] as InteriorHingedDoor
	check(not door.is_open(), "Door starts closed")

	# 1. The closed door blocks the player.
	await _place(Vector3(1.91, .05, 1.9), PI)
	player.touch_move = Vector2(0, -1)
	await _frames(70)
	player.touch_move = Vector2.ZERO
	results["blocked_z"] = player.global_position.z
	check(player.global_position.z < 2.45, "Closed door stops the player (z %.2f)" % player.global_position.z)

	# 2. Aim at it and press Hold/E (toggle_hold) to open; the HUD names the action.
	await _place(Vector3(1.91, .05, 1.3), PI)
	player.update_target()
	main._process(1.0 / 60.0)
	results["prompt"] = main.prompt.text
	check(player.door_target == door, "Crosshair on the door targets it")
	check(main.prompt.text.contains("Open door"), "HUD prompts to open the door: '%s'" % main.prompt.text)
	player.toggle_hold()
	await _frames(50)
	check(door.is_open() and not door.is_moving(), "Hold/E opens the door within the swing time")
	var leaf := door.get_child(0) as Node3D
	results["open_angle_deg"] = rad_to_deg(leaf.rotation.y)
	check(absf(rad_to_deg(leaf.rotation.y)) > 80.0, "Leaf swings inward about 88 degrees")
	var leaf_shape := leaf.get_node("LeafCollider") as CollisionShape3D
	var leaf_aabb := leaf_shape.global_transform * AABB(-(leaf_shape.shape as BoxShape3D).size * .5, (leaf_shape.shape as BoxShape3D).size)
	results["open_leaf_aabb"] = [leaf_aabb.position, leaf_aabb.end]
	check(leaf_aabb.end.x < 2.84, "Open leaf stays clear of the white cabinet (x %.2f < 2.84)" % leaf_aabb.end.x)

	# 3. Walk through the doorway, to the aquarium wall, down the stair, round the yard, back.
	lowest = INF
	var route := [
		["doorway", Vector3(1.91, 0, 3.45)],
		["aquarium wall", Vector3(1.55, 0, 3.55)],
		["stair top", Vector3(5.2, 0, 3.38)],
		["stair foot", Vector3(10.1, -2.9, 3.38)],
		["courtyard", Vector3(11.6, -2.9, 4.3)],
		["back to stair foot", Vector3(10.1, -2.9, 3.38)],
		["back up", Vector3(5.2, 0, 3.38)],
		["balcony", Vector3(1.91, 0, 3.4)],
		["room", Vector3(1.91, 0, 1.6)],
	]
	var reached := {}
	for leg: Array in route:
		var ok := await _walk_to(leg[1])
		await _frames(8)
		var p := player.global_position
		var on_level := absf(p.y - (leg[1] as Vector3).y) < .12
		reached[leg[0]] = [snappedf(p.x, .01), snappedf(p.y, .01), snappedf(p.z, .01)]
		check(ok and on_level and player.is_on_floor(), "Player reaches the %s on its floor (at %s)" % [leg[0], str(p)])
	results["route"] = reached
	results["lowest_y"] = lowest
	check(lowest > -2.95, "Player never sinks below the courtyard (lowest %.2f)" % lowest)

	# 4. Thrown props stay on the balcony / inside the yard.
	var bottle := balcony.get_node_or_null("BlueBottle") as InteriorObject
	check(bottle != null, "Blue bottle is a real rigid body on the ledge")
	if bottle != null:
		await _place(Vector3(3.2, .05, 3.3), PI)
		bottle.activate(true)
		bottle.global_position = player.camera.global_position + Vector3(0, -.2, .7)
		bottle.reset_physics_interpolation()
		bottle.linear_velocity = Vector3.ZERO
		await _frames(2)
		player.grab_object(bottle)
		await _frames(20)
		check(player.held == bottle, "Player can pick up the balcony bottle")
		player.rotation = Vector3(0, PI, 0)
		player.camera.rotation.x = .25
		await _frames(10)
		player.charging_throw = true
		player.throw_charge = 1.0
		player.throw_object()
		await _frames(240)
		var b := bottle.global_position
		results["bottle_after_throw"] = [b.x, b.y, b.z]
		check(b.z < 4.75 and b.y > -.05 and b.x > .95 and b.x < 5.75, "Max throw at the railing stays on the balcony (%s)" % str(b))
		var throws := [["stair side", Vector3(7.4, -.9, 3.4), Vector3(0, 3, 11)], ["gate", Vector3(11.0, -2.3, 4.0), Vector3(11, 4, 0)],
			["neighbour wall", Vector3(11.0, -2.3, 4.0), Vector3(0, 6, 11)], ["straight up", Vector3(11.0, -2.3, 4.0), Vector3(0, 11, 0)]]
		for item: Array in throws:
			bottle.global_position = item[1]
			bottle.linear_velocity = item[2]
			bottle.angular_velocity = Vector3.ZERO
			bottle.reset_physics_interpolation()
			await _frames(300)
			var q := bottle.global_position
			var inside := q.x > 5.5 and q.x < 12.6 and q.z > 2.9 and q.z < 5.3 and q.y > -2.95 and q.y < 2.9
			results["bottle_" + str(item[0]).replace(" ", "_")] = [q.x, q.y, q.z]
			check(inside, "Prop thrown toward the %s stays inside the stair/yard bounds (%s)" % [item[0], str(q)])

	# 5. Fish swim in the balcony aquarium.
	var tank: InteriorAquarium = null
	for node in get_nodes_in_group("aquariums"):
		if balcony.is_ancestor_of(node):
			tank = node
	check(tank != null, "Balcony aquarium is rebuilt at runtime")
	if tank != null:
		var first: Vector3 = tank.fish[0].position if not tank.fish.is_empty() else Vector3.ZERO
		await _frames(20)
		results["balcony_fish"] = tank.fish.size()
		check(tank.fish.size() == 5, "Balcony aquarium has five fish")
		check(not tank.fish.is_empty() and tank.fish[0].position.distance_to(first) > .005, "Fish are swimming")

	# 6. Daylight is isolated: outdoor lights only hit layer 2; room lights skip layer 2.
	var outdoor_lights := 0
	for light in balcony.find_children("*", "DirectionalLight3D", true, false):
		outdoor_lights += 1
		check((light as Light3D).light_cull_mask == 2, "Outdoor light %s lights only the outdoor layer" % light.name)
	check(outdoor_lights >= 2, "Balcony has a sun and a sky fill")
	var room_lights := 0
	for light in main.get_node("LivingRoom").find_children("*", "Light3D", true, false):
		room_lights += 1
		check(((light as Light3D).light_cull_mask & 2) == 0, "Room light %s is masked off the outdoor layer" % light.name)
	results["room_lights_masked"] = room_lights
	var leaked := 0
	for mesh in balcony.find_children("*", "GeometryInstance3D", true, false):
		if ((mesh as GeometryInstance3D).layers & 2) == 0:
			leaked += 1
	check(leaked == 0, "Every balcony mesh is on the outdoor layer (%d are not)" % leaked)

	# 7. Close it again: blocks again.
	door.close()
	await _frames(50)
	check(not door.is_open() and absf(leaf.rotation.y) < .01, "Door closes fully")
	await _place(Vector3(1.91, .05, 1.9), PI)
	player.touch_move = Vector2(0, -1)
	await _frames(60)
	player.touch_move = Vector2.ZERO
	check(player.global_position.z < 2.45, "Closed again, the door blocks the player")
	_finish()

func _finish() -> void:
	print("INTERIOR_BALCONY_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
