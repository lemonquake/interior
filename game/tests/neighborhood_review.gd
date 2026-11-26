extends SceneTree
## Fixed-camera neighborhood review. Run with a native renderer, never --headless.
## --path game --script res://tests/neighborhood_review.gd -- --out=<absolute-dir>
## Optional: --size=1920x1080 --quality=2 --views=all --samples=45.
## Identical cameras and render settings are used before and after the changes.

const VIEWS := [
	["01-street-arrival", Vector3(20.2, -1.32, 6.0), Vector3(20.5, -1.65, 31.0), 72.0],
	["02-west-street", Vector3(17.8, -1.32, 18.2), Vector3(-8.0, -1.7, 18.0), 72.0],
	["03-east-wall-detail", Vector3(21.7, -1.10, 30.0), Vector3(24.25, -1.45, 33.0), 60.0],
	["04-road-and-curb", Vector3(20.8, -1.25, 37.0), Vector3(22.85, -2.71, 42.5), 65.0],
	["05-north-street", Vector3(17.3, -1.32, 48.8), Vector3(-8.0, -1.8, 49.0), 72.0],
	["06-neighborhood-overview", Vector3(38.0, 18.0, 6.0), Vector3(8.0, -1.4, 30.0), 68.0],
]

func _initialize() -> void:
	_run.call_deferred()

func _arg(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + key + "="):
			return argument.trim_prefix("--" + key + "=")
	return fallback

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Neighborhood screenshots require a native renderer.")
		quit(2)
		return
	seed(130013)
	var output := _arg("out", "user://neighborhood-review")
	var size := _arg("size", "1600x900").split("x")
	var quality := int(_arg("quality", "2"))
	var selected := _arg("views", "all")
	var sample_count := maxi(int(_arg("samples", "45")), 10)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(int(size[0]), int(size[1]))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(8)
	main._apply_quality(quality)
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = player.camera
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var results: Array[Dictionary] = []
	for view: Array in VIEWS:
		if selected != "all" and selected != view[0]:
			continue
		player.global_position = view[1] - Vector3.UP * 1.58
		camera.global_position = view[1]
		camera.fov = view[3]
		camera.look_at(view[2])
		await _frames(180 if results.is_empty() else 90)
		var timings: Array[float] = []
		var draw_calls: Array[float] = []
		var primitives: Array[float] = []
		for sample in sample_count:
			var start := Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			timings.append(float(Time.get_ticks_usec() - start) / 1000.0)
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var picture := root.get_texture().get_image()
		var file_name: String = str(view[0]) + ".png"
		var saved := picture.save_png(output.path_join(file_name))
		if saved != OK:
			push_error("Could not save " + file_name)
			quit(3)
			return
		timings.sort()
		draw_calls.sort()
		primitives.sort()
		var result := {"name": view[0], "file": file_name, "camera": _vector(view[1]),
			"target": _vector(view[2]), "fov": view[3], "pixels": [picture.get_width(), picture.get_height()],
			"samples": sample_count, "median_frame_ms": timings[sample_count / 2],
			"p95_frame_ms": timings[mini(int(sample_count * .95), sample_count - 1)],
			"median_draw_calls": draw_calls[sample_count / 2], "median_primitives": primitives[sample_count / 2]}
		results.append(result)
		print("NEIGHBORHOOD_VIEW ", JSON.stringify(result))
	var report := {"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "quality": quality,
		"render_scale": root.scaling_3d_scale, "seed": 130013, "views": results,
		"measurement_note": "Short fixed-camera samples include presentation/vsync; not a hardware performance guarantee."}
	var neighborhood := get_first_node_in_group("neighbourhood")
	if neighborhood != null:
		report["abandoned_town"] = neighborhood.get_meta("abandoned_town", {})
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("NEIGHBORHOOD_REVIEW_COMPLETE ", results.size())
	quit(0)
