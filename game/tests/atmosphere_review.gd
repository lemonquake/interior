extends SceneTree
## Rendered atmosphere captures with the real HUD, audio and particle controllers running.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := "user://atmosphere-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await process_frame
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var fields: Node3D = main.get_node("Fields")
	var road: PackedVector2Array = fields.get_meta("road_samples")
	var hut: Vector3 = fields.get_meta("hut")
	var crow: Node3D = fields.find_child("Scarecrow", true, false)
	var at := func(i: int) -> Vector3: return Vector3(road[i].x, -1.32, road[i].y)
	var views := [
		["01-room", Vector3(.6, 1.58, 1.3), Vector3(-1.0, 1.4, -2.5)],
		["02-gate", Vector3(10.4, -1.32, 3.7), Vector3(13.0, -1.6, 4.1)],
		["03-street", Vector3(20.2, -1.32, 6), Vector3(20.5, -1.6, 38)],
		["04-fields", at.call(70), at.call(110)],
		["05-hut", at.call(int(road.size() * .27)), hut + Vector3.UP * 1.6],
		["06-scarecrow", crow.global_position + Vector3(5, 1.58, -7), crow.global_position + Vector3.UP * 1.4],
	]
	for view: Array in views:
		player.global_position = view[1] - Vector3.UP * 1.58
		player.camera.global_position = view[1]
		player.camera.look_at(view[2])
		player.camera.fov = 72.0
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 4200:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view[0] + ".png"))
		print("ATMOSPHERE_VIEW ", view[0])
	print("ATMOSPHERE_REVIEW_COMPLETE")
	quit(0)
