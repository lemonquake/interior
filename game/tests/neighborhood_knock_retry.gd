extends SceneTree
## Regression: real Hold input, interrupted gestures, repeated attempts and moving contact.
var failures: Array[String] = []
var checks := 0
var player: InteriorPlayer
var door: Node3D
var controller: Node3D
var main: Node

func _initialize() -> void: _run.call_deferred()
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func press_e() -> void:
	player.hold_pressed()
	player.hold_released()
func approach() -> void:
	player.global_position = door.global_position + door.global_basis.z * .55
	player.global_position.y = -2.9
	player.camera.global_position = player.global_position + Vector3.UP * 1.58
	player.camera.look_at(door.global_position + Vector3.UP * .30)
	await frames(3)
	player.update_target()
func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(12)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var interactions := get_first_node_in_group("neighbourhood").get_node("Neighborhood interactions")
	controller = interactions.get_node("Quiet encounters")
	for candidate in interactions.doors:
		if candidate.position.z < 44 and candidate.position.z > 22 and absf(candidate.position.x) < 17:
			door = candidate
			break
	for delay in [0, 20, 45]:
		await approach()
		check(door.prompt_text() == "Open door", "Door prompt says Open door")
		press_e()
		check(controller._elapsed == 0.0 and not controller._arms.visible, "Attempt begins below view without a raised-pose flash")
		await frames(delay)
		player.global_position += door.global_basis.z * 1.2
		player.camera.global_position += door.global_basis.z * 1.2
		await frames(3)
		check(controller._elapsed < 0 and controller._active_object == null, "Walking away cancels at frame %d" % delay)
		check(not controller._arms.visible and not player.get_meta("knocking", false) and not controller._object_voice.playing, "Cancellation clears hand, weapon block and audio")
		check(door.cooldown == 0 and not main.story.ui.dialogue_active(), "Cancelled attempt leaves no cooldown or dialogue")
		await approach()
		press_e()
		check(controller._elapsed == 0 and controller._tap == 0, "Immediate E retry starts a fresh knock")
		await frames(28)
		check(controller._arms.visible, "Retry animates hand into view")
		# Move sideways inside reach; the fist's resting contact must remain on the door.
		player.global_position += door.global_basis.x * .06
		player.camera.global_position += door.global_basis.x * .06
		await frames(2)
		var skeleton: Skeleton3D = controller._skeleton
		var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand.R"))
		var knuckles := skeleton.to_global(hand * Vector3(0, .065, .01))
		var error: Vector3 = knuckles - controller._contact_point(door)
		check(absf(error.dot(door.global_basis.x)) < .01, "Sideways movement keeps fist aligned with door")
		await frames(120)
		check(controller._tap == 3 and main.story.ui.dialogue_active(), "Retry completes all three taps and dialogue")
		check(not controller._arms.visible and not player.get_meta("knocking", false), "Completed gesture restores hand and weapon state")
		press_e()
		press_e()
		check(not main.story.ui.dialogue_active(), "E dismisses remark normally")
	# Also interrupt by turning away, then retry without touching any private cooldown state.
	await approach()
	press_e()
	await frames(20)
	player.camera.rotate_y(PI)
	await frames(3)
	check(controller._elapsed < 0 and door.cooldown == 0, "Looking away cancels and allows immediate retry")
	await approach()
	press_e()
	await frames(150)
	check(controller._tap == 3 and main.story.ui.dialogue_active(), "Completed attempts can be repeated without a nine-second lockout")
	press_e()
	press_e()
	await approach()
	player.camera.look_at(door.global_position + door.global_basis.x * .32)
	press_e()
	await frames(48)
	check(controller._elapsed > .6 and controller._tap == 1, "Aiming at the handle at close range does not falsely cancel")
	player.camera.rotate_y(PI)
	await frames(3)
	await approach()
	player.camera.global_position.y -= .5
	player.camera.look_at(door.global_position + Vector3.DOWN * .20)
	press_e()
	await frames(150)
	check(controller._tap == 3 and main.story.ui.dialogue_active(), "Crouched player can complete a fresh knock")
	print("NEIGHBORHOOD_KNOCK_RETRY ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
