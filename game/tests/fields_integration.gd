extends SceneTree
## Run 7: hold-E pulling and the moonlit fields, driven with the real player:
## - the navy door: holding E on the leaf and stepping back pulls it open part way, it rests where it is
##   let go, and a tap then finishes the swing; the gate (unlocked by a tap) is pulled open from the lane;
## - a prop picked up with a long press is dropped when E is released, a tap keeps carrying it;
## - the dirt road can be walked from street B to the dead end without falling into the paddies,
##   names "dirt" for footsteps, the jetty can be walked out onto, and the barrier at the end holds;
## - the fields only show outside at street level.
##   godot --headless --fixed-fps 60 --path game --script res://tests/fields_integration.gd

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

func _walk_to(target: Vector3, max_frames := 900, tolerance := .5) -> bool:
	for i in max_frames:
		var delta := target - player.global_position
		delta.y = 0.0
		if delta.length() < tolerance:
			return true
		player.rotation = Vector3(0, atan2(-delta.x, -delta.z), 0)
		player.touch_move = Vector2(0, -1)
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
	player.touch_move = Vector2.ZERO
	return false

func _place(at: Vector3, yaw: float, pitch := 0.0) -> void:
	player.reset_motion(at)
	player.rotation = Vector3(0, yaw, 0)
	player.set("_look_pitch", pitch)
	player.camera.rotation.x = pitch
	await _frames(6)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(4)
	player = main.player
	await _door_pull()
	await _gate_pull()
	await _prop_hold()
	await _fields_walk()
	_finish()

func _door_pull() -> void:
	var door: InteriorHingedDoor = main.entry_door()
	check(door != null, "The navy entry door exists")
	if door == null:
		return
	door.snap(false)
	# Inside the room, facing the door (it swings inward, toward the player).
	await _place(Vector3(1.85, .05, 1.55), PI, -.32)
	player.update_target()
	check(player.door_target == door and player.door_hit.is_finite(), "Aiming at the door leaf targets it with a hit point")
	player.hold_pressed()
	check(player.is_pulling(), "Holding E on the leaf takes hold of it")
	player.touch_move = Vector2(0, 1)
	await _frames(40)
	player.touch_move = Vector2.ZERO
	await _frames(20)
	var pulled: float = door.get("_t")
	results["door_pulled_t"] = snappedf(pulled, .01)
	check(pulled > .12 and door.is_open(), "Stepping back while holding pulls the door open (t %.2f)" % pulled)
	player.set("_hold_down_time", _now() - 1.0)
	player.hold_released()
	check(not player.is_pulling(), "Releasing E lets go of the door")
	await _frames(45)
	var rested: float = door.get("_t")
	check(rested > .08 and not door.is_moving(), "The door rests where it was let go (t %.2f)" % rested)
	# A tap now finishes the swing one way or the other.
	player.update_target()
	player.hold_pressed()
	player.hold_released()
	await _frames(70)
	var progress: float = door.get("_progress")
	check(not bool(door.get("_manual")) and (is_equal_approx(progress, 0.0) or is_equal_approx(progress, 1.0)), "A tap after pulling completes the swing (progress %.2f)" % progress)
	door.snap(false)

func _gate_pull() -> void:
	var gate: InteriorPushGate = null
	for node in get_nodes_in_group("interior_doors"):
		if node is InteriorPushGate:
			gate = node
	check(gate != null, "The courtyard gate exists")
	if gate == null:
		return
	await _place(Vector3(11.6, -2.9, 3.6), -PI * .5, -.2)
	player.update_target()
	check(player.door_target == gate, "Looking at the gate targets it")
	player.hold_pressed()
	player.hold_released()
	await _frames(10)
	check(not gate.locked, "A tap on E unlocks the gate")
	# From the lane, hold E on the closed first leaf and step back: the gate swings open toward you.
	gate.snap_closed()
	await _place(Vector3(14.2, -2.9, 3.45), PI * .5, -.25)
	player.update_target()
	var aimed := player.door_target == gate and player.door_hit.is_finite()
	check(aimed, "The closed gate leaf can be aimed at from the lane")
	if aimed:
		player.hold_pressed()
		player.touch_move = Vector2(0, 1)
		await _frames(50)
		player.touch_move = Vector2.ZERO
		player.set("_hold_down_time", _now() - 1.0)
		player.hold_released()
		await _frames(20)
		var after: float = maxf(gate.get("_angle")[0], gate.get("_angle")[1])
		results["gate_pulled_rad"] = snappedf(after, .01)
		check(after > .3 and gate.is_open(), "Pulling a leaf from the lane swings the gate open toward you (%.2f rad)" % after)
	gate.snap_closed()

func _prop_hold() -> void:
	var prop: InteriorObject = null
	for body in get_nodes_in_group("movable"):
		var object := body as InteriorObject
		if object != null and not object.anchored and object.grab_mode != "none" and object.mass < 3.0 and main.room.is_ancestor_of(object):
			prop = object
			break
	check(prop != null, "A light loose prop exists")
	if prop == null:
		return
	await _place(prop.global_position + Vector3(0, -.2, 1.2), 0.0, -.4)
	# Long press: the prop is dragged and let go with E.
	player.set("_hold_down", true)
	player.set("_hold_down_time", _now() - 1.0)
	player.grab_object(prop)
	player.set("_grabbed_on_press", true)
	player.hold_released()
	check(player.held == null, "Releasing a long press drops the prop")
	# Tap: it stays in hand until E is pressed again.
	player.set("_hold_down", true)
	player.set("_hold_down_time", _now())
	player.grab_object(prop)
	player.set("_grabbed_on_press", true)
	player.hold_released()
	check(player.held == prop, "A tap keeps carrying the prop")
	player.release_object()

func _fields_walk() -> void:
	var fields: Node3D = main.get_node_or_null("Fields")
	check(fields != null, "The fields scene is in main.tscn")
	if fields == null:
		return
	await _place(Vector3(0.6, .05, 1.3), 0.0)
	await _frames(3)
	check(not fields.visible, "The fields are hidden while the player is in the room")
	var road: PackedVector2Array = fields.get_meta("road_samples")
	check(road.size() > 400, "The dirt road is sampled (%d points)" % road.size())
	await _place(Vector3(road[0].x, -2.85, road[0].y), PI)
	await _frames(3)
	check(fields.visible, "The fields show from the end of street B")
	player.touch_sprinting = true
	lowest = INF
	var reached := 0
	var surfaces := {}
	for i in range(8, road.size() - 6, 8):
		if not await _walk_to(Vector3(road[i].x, 0, road[i].y), 400, .9):
			break
		reached = i
		surfaces[InteriorSurfaces.under(player)] = true
	player.touch_sprinting = false
	results["road_reached"] = [reached, road.size()]
	results["road_lowest_y"] = snappedf(lowest, .01)
	results["road_surfaces"] = surfaces.keys()
	check(reached >= road.size() - 16, "The whole dirt road can be walked (sample %d of %d)" % [reached, road.size()])
	check(lowest > -3.05, "Nobody falls off the road into the paddies (lowest y %.2f)" % lowest)
	check(surfaces.has("dirt"), "Footsteps on the road name dirt (%s)" % str(surfaces.keys()))
	# The barrier at the end holds.
	var last := road[road.size() - 1]
	var beyond := last + (last - road[road.size() - 8]).normalized() * 10.0
	await _walk_to(Vector3(beyond.x, 0, beyond.y), 150, .5)
	var past := Vector2(player.global_position.x, player.global_position.z).distance_to(beyond)
	check(past > 8.0, "The barrier at the dead end stops the player (%.1f m short)" % past)
	# The jetty: walk from the road out over the pond.
	var pond: Vector4 = fields.get_meta("pond")
	var near := 0
	var best := INF
	for i in road.size():
		var d := road[i].distance_to(Vector2(pond.x, pond.y))
		if d < best:
			best = d
			near = i
	var out := (Vector2(pond.x, pond.y) - road[near]).normalized()
	await _place(Vector3(road[near].x, -2.85, road[near].y), 0.0)
	lowest = INF
	var tip := road[near] + out * 9.0
	await _walk_to(Vector3(tip.x, 0, tip.y), 300, .6)
	var walked_out := Vector2(player.global_position.x, player.global_position.z).distance_to(road[near])
	results["jetty_out_m"] = snappedf(walked_out, .1)
	check(walked_out > 6.0 and lowest > -3.05, "The jetty can be walked out over the pond (%.1f m, lowest %.2f)" % [walked_out, lowest])
	check(InteriorSurfaces.under(player) == "wood", "The jetty sounds like wood (%s)" % InteriorSurfaces.under(player))

func _finish() -> void:
	print("INTERIOR_FIELDS_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
