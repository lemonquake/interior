extends SceneTree
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/neighborhood-interactions/" + label + ".png"))
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/neighborhood-interactions"))
	root.size = Vector2i(1600, 900)
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(10)
	main._apply_quality(2)
	var town := get_first_node_in_group("neighbourhood")
	var interactions := town.get_node("Neighborhood interactions")
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var door: Node3D = interactions.doors[0]
	for candidate in interactions.doors:
		if candidate.position.z < 44 and candidate.position.z > 22 and absf(candidate.position.x) < 17:
			door = candidate
			break
	player.global_position = door.global_position + door.global_basis.z * .55
	player.global_position.y = -2.9
	player.camera.global_position = player.global_position + Vector3.UP * 1.58
	player.camera.look_at(door.global_position + Vector3.UP * .3)
	await frames(90)
	door.toggle()
	var encounters := interactions.get_node("Quiet encounters")
	encounters.set_process(false)
	encounters._update_action(.64)
	await frames(8)
	await shot("01-knock")
	encounters._update_action(1.8)
	await frames(60)
	await shot("02-dialogue")
	main.story.ui.advance()
	main.story.ui.advance()
	var gate: InteriorPushGate = interactions.gates[0]
	player.global_position = gate.global_position + Vector3(0, 0, 3)
	player.camera.global_position = player.global_position + Vector3.UP * 1.58
	player.camera.look_at(gate.global_position + Vector3.UP * .8)
	await frames(90)
	await shot("03-gate-closed")
	gate.snap_open()
	await frames(45)
	await shot("04-gate-open")
	print("INTERACTION_VIEWS_COMPLETE")
	quit()
