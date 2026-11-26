extends SceneTree
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(8)
	var room: Node3D = main.room
	check(not room.has_node("InteriorLighting/Light_accent_lamp"), "Sofa lamp and its light must be removed")
	check(not room.has_node("ReferenceRoomSurroundings/Room detail - leaf curtain"), "Closet curtains must be removed")
	var door: Node3D = room.get_node("LockedClosetDoor")
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(1.8, .1, .9)
	player.camera.global_position = Vector3(1.8, 1.58, .9)
	player.camera.look_at(Vector3(3.25, 1.2, .9))
	await physics_frame
	player.update_target()
	check(player.door_target == door, "The normal interaction ray must target the closet door")
	var closed := door.transform
	var prior_status: String = main.status_label.text
	var prior_phase: int = main.story.phase
	player.hold_pressed()
	player.hold_released()
	check(main.story.ui.dialogue_active() and main.story.ui.current_line() == "It's.. locked? Weird.", "E / touch Hold must show the exact line in the dialogue box")
	check(main.story.ui.current_speaker() == "You", "The locked door dialogue belongs to the player")
	check(main.status_label.text == prior_status, "Door dialogue must not replace the upper-left objective")
	player.hold_pressed()
	player.hold_released()
	player.hold_pressed()
	player.hold_released()
	check(not main.story.ui.dialogue_active(), "E / touch Hold must reveal and then dismiss the dialogue")
	check(main.story.phase == prior_phase, "Finishing the player's remark must preserve story progress")
	check(door.transform == closed and not player.is_pulling(), "Using the locked door must never pull it open")
	var query := PhysicsRayQueryParameters3D.create(Vector3(2.9, .8, .9), Vector3(3.6, .8, .9), 2)
	var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
	check(hit.get("collider") == door.get_node("ClosedDoor"), "The door must physically block its opening")
	var pillows := 0
	for child in room.get_children():
		if child is InteriorObject and child.has_meta("white_pillow"):
			pillows += 1
			player.grab_object(child)
			check(player.held == child, "White pillow must remain grabbable")
			player.release_object()
			child.recover()
	check(pillows == 4, "All four loose sofa cushions must be white pillows")
	if "--review" in OS.get_cmdline_user_args():
		root.size = Vector2i(1600, 900)
		main._apply_quality(2)
		var output := ProjectSettings.globalize_path("res://../docs/room-furnishings")
		DirAccess.make_dir_recursive_absolute(output)
		for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		for shot in [["sofas", Vector3(.9, 1.7, .0), Vector3(-1.6, .9, 1.15)], ["closed-door", Vector3(1.35, 1.58, .1), Vector3(3.25, 1.2, .9)]]:
			player.camera.global_position = shot[1]
			player.camera.look_at(shot[2])
			await _frames(90)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(shot[0] + ".png"))
		main.ui.visible = true
		player.camera.global_position = Vector3(1.8, 1.58, .9)
		player.camera.look_at(Vector3(3.25, 1.2, .9))
		player.toggle_hold()
		main.story.ui.advance()
		await _frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("locked-message.png"))
	print("ROOM_FURNISHINGS_TEST ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
