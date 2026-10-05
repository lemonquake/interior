extends SceneTree
## RENDERED look review (do not run with --headless).
##   godot --path game --script res://tests/look_preview.gd -- --render-size=1920x1080 --quality=2 --out=<dir> [--tag=high] [--perf-seconds=10]
##   add --door-open to open the entry door (balcony visible), --perf-outdoor to orbit on the balcony instead
##   godot --rendering-method gl_compatibility --path game --script res://tests/look_preview.gd -- --mobile-test --render-size=1920x1080 --quality=0 --out=<dir> --tag=compat
## Saves <out>/<tag>-<view>.png and prints one INTERIOR_LOOK_PREVIEW {json} marker.

const VIEWS := [
	["room-wide", Vector3(.62, 1.58, 1.30), Vector3(-.20, 1.30, -2.35)],
	["tv-wall", Vector3(-.45, 1.72, 1.05), Vector3(-.50, 1.15, -2.70)],
	["room-reverse", Vector3(.75, 1.58, -1.30), Vector3(-.30, 1.20, 2.70)],
	["kitchen", Vector3(-2.3, 1.6, 1.70), Vector3(-5.15, 1.20, -.25)],
	["right-wall", Vector3(-.25, 1.58, .35), Vector3(3.25, 1.42, .30)],
	["table", Vector3(.75, 1.35, .30), Vector3(-.30, .80, .30)],
	["sofa", Vector3(.10, 1.55, .20), Vector3(-2.05, .65, .40)],
]

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.get_slice("=", 1)
	return fallback

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var quality := int(_arg("quality", "2"))
	var out := _arg("out", ProjectSettings.globalize_path("user://look_preview"))
	var tag := _arg("tag", "q%d" % quality)
	var perf_seconds := float(_arg("perf-seconds", "0"))
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(10)
	main._apply_quality(quality)
	main._play()
	paused = false
	main.player.playing = false
	main.hud.hide()
	main.menu.hide()
	if main.get("touch") != null:
		main.touch.set_enabled(false)
		main.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera: Camera3D = main.player.camera
	var door_open := OS.get_cmdline_user_args().has("--door-open")
	var outdoor := OS.get_cmdline_user_args().has("--perf-outdoor")
	if door_open or outdoor:
		for door in main.get_tree().get_nodes_in_group("interior_doors"):
			door.snap(true)
	var lighting := InteriorLighting.find_in(main.room)
	var saved: Array[String] = []
	for index in VIEWS.size():
		var view: Array = VIEWS[index]
		camera.global_position = view[1]
		camera.look_at(view[2])
		camera.reset_physics_interpolation()
		# GI and reflection probes settle over a few dozen frames.
		await create_timer(2.5 if index == 0 else 0.6).timeout
		await RenderingServer.frame_post_draw
		var path: String = out.path_join("%s-%s.png" % [tag, view[0]])
		if root.get_texture().get_image().save_png(path) == OK:
			saved.append(path)
	var report := {"quality": quality, "tag": tag, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "door_open": door_open, "outdoor": outdoor, "window": str(root.size), "saved": saved.size(),
		"lighting": lighting.stats() if lighting != null else {}}
	if perf_seconds > 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		var samples: Array[float] = []
		var started := Time.get_ticks_usec()
		var last := started
		while Time.get_ticks_usec() - started < int(perf_seconds * 1e6):
			var t := float(Time.get_ticks_usec() - started) / 1e6
			# Slow orbit around the living room covering every wall.
			if outdoor:
				# Pace the balcony looking all round: aquarium wall, room through the door, stair, yard.
				camera.global_position = Vector3(3.0 + sin(t * .3) * 1.6, 1.55, 3.7)
				camera.look_at(camera.global_position + Vector3(sin(t * .5), -.25, cos(t * .5)))
			else:
				camera.global_position = Vector3(.2 + sin(t * .5) * .6, 1.58, .4 + cos(t * .5) * .6)
				camera.look_at(Vector3(.2 + sin(t * .5 + PI) * 3.0, 1.2, .4 + cos(t * .5 + PI) * 2.4))
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - last) / 1000.0)
			last = now
		samples = samples.slice(10)
		samples.sort()
		report["perf"] = {"seconds": perf_seconds, "frames": samples.size(),
			"median_ms": snappedf(samples[samples.size() / 2], 0.01),
			"p95_ms": snappedf(samples[int(samples.size() * .95)], 0.01),
			"p99_ms": snappedf(samples[int(samples.size() * .99)], 0.01)}
	report["passed"] = saved.size() == VIEWS.size() and (not report.has("perf") or report.perf.p95_ms < 16.7)
	print("INTERIOR_LOOK_PREVIEW ", JSON.stringify(report))
	quit(0 if report.passed else 1)
