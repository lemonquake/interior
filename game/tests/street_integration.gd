extends SceneTree
## Run 6: the courtyard gate, the walkable ghost-town streets, the adult walking stride and the TV.
## Driven with the real player and the touch move axis:
## - the locked gate does not move when pushed; E unlocks it, and walking into it pushes it open;
## - the player walks out through the gate, up Malasugue Street (B) and along street A, never
##   falling through the ground and never leaving the play area;
## - footsteps come at an adult cadence (about 2 steps/s walking) and name the right surfaces;
## - the TV can't be grabbed: E turns it on, channel 3 shows the news after ~2 s, other channels
##   are static, and coming back to channel 3 shows the news again.
##   godot --headless --path game --script res://tests/street_integration.gd

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var lowest := INF
var steps: Array = []

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

func _walk_to(target: Vector3, max_frames := 900, tolerance := .3) -> bool:
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
	player.stepped.connect(func(surface: String, _strength: float) -> void: steps.append([Time.get_ticks_msec(), surface, Engine.get_physics_frames()]))
	var gate: InteriorPushGate = null
	for door in get_nodes_in_group("interior_doors"):
		if door is InteriorPushGate:
			gate = door
	check(gate != null, "The courtyard gate is a push gate in the interior_doors group")
	if gate == null:
		_finish()
		return

	# 1. Locked: walking into it does nothing.
	await _place(Vector3(11.6, -2.9, 3.6), -PI * .5)
	var frame_start := Engine.get_physics_frames()
	player.touch_move = Vector2(0, -1)
	await _frames(90)
	player.touch_move = Vector2.ZERO
	await _frames(3)
	check(not gate.is_open() and player.global_position.x < 12.6, "A locked gate holds (player x %.2f)" % player.global_position.x)
	# 2. E unlocks; it only drifts ajar by itself.
	player.camera.rotation.x = -.2
	player.update_target()
	check(player.door_target == gate, "Looking at the gate targets it")
	check(gate.prompt_text().contains("Unlock"), "Prompt offers to unlock the gate")
	player.toggle_hold()
	check(not gate.locked, "E unlocks the gate")
	await _frames(60)
	results["ajar_angle"] = gate._angle[0]
	check(not gate.is_open(), "An unlocked gate stays nearly shut until pushed (%.2f rad)" % gate._angle[0])
	# 3. Push it open by walking into it.
	player.touch_move = Vector2(0, -1)
	await _frames(150)
	player.touch_move = Vector2.ZERO
	results["pushed_angle"] = gate._angle[0]
	check(gate._angle[0] > .9, "Walking into the gate swings it open (%.2f rad)" % gate._angle[0])
	# 4. Out through the gate into the lane and the streets.
	var route := [Vector3(13.6, -2.9, 3.9), Vector3(17.0, -2.9, 4.6), Vector3(21.4, -2.9, 6.0),
		Vector3(21.4, -2.9, 18.6), Vector3(10.0, -2.9, 18.0), Vector3(-5.0, -2.9, 18.0)]
	var t0 := Time.get_ticks_msec()
	var steps_before := steps.size()
	var frames_before := Engine.get_physics_frames()
	for point: Vector3 in route:
		var reached := await _walk_to(point)
		check(reached, "Walks to %s (stopped at %s)" % [str(point), str(player.global_position)])
		if not reached:
			break
	var walked_frames := Engine.get_physics_frames() - frames_before
	var walked_steps := steps.size() - steps_before
	var rate := walked_steps / (walked_frames / float(Engine.physics_ticks_per_second))
	results["steps_per_second_walking"] = rate
	check(rate > 1.7 and rate < 2.8, "Adult walking cadence: %.2f steps/s" % rate)
	check(lowest > -3.0, "Never sinks through the street (lowest %.2f)" % lowest)
	var surfaces := {}
	for s: Array in steps:
		surfaces[s[1]] = true
	results["surfaces"] = surfaces.keys()
	check(surfaces.has("asphalt") and surfaces.has("grass"), "Footsteps name the street surfaces (%s)" % str(surfaces.keys()))
	# 5. The barricade / play-area edge stops the player at the end of street A.
	await _walk_to(Vector3(-30.0, -2.9, 18.0), 900)
	check(player.global_position.x > -24.2, "The edge of the play area holds (x %.2f)" % player.global_position.x)

	# 6. The TV.
	var tv: InteriorTelevision = main.find_child("TelevisionController", true, false)
	check(tv != null, "The TV has its controller")
	if tv != null:
		await _place(Vector3(-.55, 0.05, -1.0), 0.0)
		player.camera.rotation.x = .28
		await _frames(4)
		player.update_target()
		check(player.target == tv.body, "Looking at the TV targets it")
		player.toggle_hold()
		check(player.held == null, "The TV can't be carried")
		check(tv.powered, "E turns the TV on")
		check(not tv.is_news(), "No picture during the warm-up")
		await _frames(150)
		check(tv.is_news(), "News Order shows after the warm-up on channel 3")
		player.change_channel(1)
		check(not tv.is_news() and tv.channel == 4, "Channel 4 is static")
		player.change_channel(1)
		player.change_channel(-1)
		player.change_channel(-1)
		check(tv.is_news(), "Back on channel 3 the news returns")
		player.toggle_hold()
		check(not tv.powered, "E turns it off again")
	# 7. The glitching clock ticks.
	var clock: Label3D = main.find_child("GlitchDisplay", true, false)
	check(clock != null, "The digital clock has its glitch display")
	_finish()

func _finish() -> void:
	print("INTERIOR_STREET_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
