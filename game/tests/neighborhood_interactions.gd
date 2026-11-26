extends SceneTree
var failures: Array[String] = []
var checks := 0
var main: Node
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(12)
	var town := get_first_node_in_group("neighbourhood")
	var interactions := town.get_node("Neighborhood interactions")
	print("COUNTS ", interactions.get_meta("counts"))
	check(interactions.gates.size() >= 20, "Physical lot gates exist")
	check(interactions.doors.size() >= 15, "Actual facade entrances found")
	var gate: InteriorPushGate = interactions.gates[0]
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(20, -2.85, 8)
	gate.toggle()
	await frames(40)
	check(not gate.locked and not gate.is_open() and not gate.is_moving(), "Unlock alone never swings gate")
	var leaf := gate._leaves[0]
	var hand := leaf.to_global(Vector3(0, 1, float(leaf.get_meta("width")) * .8))
	gate.grab(hand, leaf)
	var normal := Vector3(cos(leaf.global_rotation.y), 0, -sin(leaf.global_rotation.y)) * float(leaf.get_meta("open_sign"))
	gate.drag_to(hand + normal * 1.1, .016)
	await frames(80)
	check(gate.is_open(), "Held leaf follows pull")
	var moved := gate.release()
	check(moved > .25, "Release reports manual travel")
	gate.grab(leaf.to_global(Vector3(0, 1, .9)), leaf)
	gate.drag_to(gate.to_global(Vector3(-float(leaf.get_meta("width")) + .9, 1, 0)), .016)
	await frames(100)
	gate.release()
	check(gate._angle[0] < .08, "Hand can bring the open leaf fully closed")
	gate.snap_closed()
	gate.locked = true
	gate.grab(hand, leaf)
	gate.drag_to(hand + normal, .016)
	await frames(35)
	check(not gate.is_open(), "Locked leaf cannot be dragged")
	gate.release()
	gate.locked = false
	var frame := gate._frame(0)
	player.global_position = frame[0] + frame[1] * .9 - frame[2] * .29
	player.wish_velocity = frame[2] * 2.0
	await frames(15)
	check(gate._angle[0] > .03, "Walking into unlocked gate pushes it")
	player.wish_velocity = Vector3.ZERO
	var door: Node3D = interactions.doors[0]
	for candidate in interactions.doors:
		if candidate.position.z < 44 and candidate.position.z > 22 and absf(candidate.position.x) < 17:
			door = candidate
			break
	var controller := interactions.get_node("Quiet encounters")
	player.global_position = door.global_position + door.global_basis.z * .55
	player.global_position.y = -2.9
	player.camera.global_position = player.global_position + Vector3.UP * 1.58
	player.camera.look_at(door.global_position + Vector3.UP * .3)
	await frames(3)
	player.update_target()
	check(player.door_target == door, "Ray selects real locked door ahead of house collider")
	door.toggle()
	check(controller._elapsed >= 0, "Door starts knocking")
	await frames(150)
	check(controller._tap == 3, "Three synchronized knock contacts")
	check(main.story.ui.current_line() == "I guess no one's home..", "First knock has requested dialogue")
	check(door.uses == 1, "Door interaction counted once")
	door.toggle()
	check(door.uses == 1, "Dialogue prevents overlapping door interactions")
	main.story.ui.advance()
	main.story.ui.advance()
	door.cooldown = 0.0
	player.global_position += door.global_basis.z * 1.0
	player.camera.global_position += door.global_basis.z * 1.0
	door.toggle()
	check(door.uses == 1 and door.prompt_text().begins_with("Move closer"), "Door requires physical knocking reach")
	for kind in ["bell", "mailbox"]:
		var object: Node3D
		for candidate in get_nodes_in_group("neighborhood_usables"):
			if candidate.kind == kind and candidate.position.z < 44 and candidate.position.z > 22 and absf(candidate.position.x) < 17:
				object = candidate
				break
		check(object != null, "Accessible " + kind + " exists")
		if object == null: continue
		player.global_position = object.global_position + object.global_basis.z * .6
		player.global_position.y = -2.9
		player.camera.global_position = player.global_position + Vector3.UP * 1.58
		player.camera.look_at(object.global_position)
		await frames(2)
		player.update_target()
		check(player.door_target == object, kind + " is targetable on the actual facade")
		object.toggle()
		await frames(150)
		check(object.uses == 1 and main.story.ui.dialogue_active(), kind + " responds with sound and dialogue")
		main.story.ui.advance()
		main.story.ui.advance()
	# Earlier gate checks now cross the wider approach naturally; isolate the one-shot assertion.
	controller.fired.erase(0)
	check(controller.trigger_zone(0), "Psst crossing fires first time")
	check(not controller.trigger_zone(0), "Psst crossing cannot repeat")
	controller._whisper_voice.stop()
	controller._start_steps()
	controller._update_steps(.01)
	check(controller._step_index == 1, "Unseen footsteps play behind the player")
	player.camera.look_at(controller._step_origin)
	controller._update_steps(.01)
	check(controller._step_time < 0.0 and not controller._event_voice.playing, "Turning toward distant footsteps stops them")
	var before: int = controller.event_count
	paused = true
	await frames(10)
	check(controller.event_count == before, "Paused scene does not trigger encounters")
	paused = false
	player.global_position = Vector3(0, 0, 0)
	await frames(3)
	check(not controller._event_voice.playing and controller._elapsed < 0, "Indoor return stops neighborhood encounters")
	var counts: Dictionary = interactions.get_meta("counts")
	main._restart()
	await frames(15)
	var fresh := get_first_node_in_group("neighbourhood").get_node("Neighborhood interactions")
	check(fresh.gates.size() == counts.gates and fresh.gates[0].locked, "Restart restores gates without duplicates")
	check(fresh.get_node("Quiet encounters").fired.is_empty(), "Restart resets one-time scares")
	print("NEIGHBORHOOD_INTERACTIONS ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "counts": counts}))
	quit(0 if failures.is_empty() else 1)
