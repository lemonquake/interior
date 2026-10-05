extends SceneTree
## RENDERED review captures for run 6: the TV broadcast, the glitching clock, the courtyard gate
## and the street (do not run with --headless).
##   godot --path game --script res://tests/v6_views.gd -- --views=tv|street|all --out=<dir> [--size=1600x900]
## Writes one PNG per view; prints V6_VIEW <name> for each.

const VIEWS := [
	# [name, set, camera, target, fov, action]
	["tv-1-off", "tv", Vector3(-.35, 1.55, -.2), Vector3(-.55, 1.6, -2.6), 60.0, "off"],
	["tv-2-warming", "tv", Vector3(-.35, 1.55, -.2), Vector3(-.55, 1.6, -2.6), 60.0, "on:0.6"],
	["tv-3-news", "tv", Vector3(-.35, 1.55, -.2), Vector3(-.55, 1.6, -2.6), 60.0, "wait:2.4"],
	["tv-4-news-close", "tv", Vector3(-.5, 1.72, -1.35), Vector3(-.55, 1.74, -2.6), 62.0, "wait:3.0"],
	["tv-5-static-ch4", "tv", Vector3(-.35, 1.55, -.2), Vector3(-.55, 1.6, -2.6), 60.0, "channel"],
	["clock-1", "tv", Vector3(-.5, .92, -1.85), Vector3(-.55, .78, -2.3), 50.0, "news"],
	["clock-2", "tv", Vector3(-.5, .92, -1.85), Vector3(-.55, .78, -2.3), 50.0, "wait:1.0"],
	["clock-3", "tv", Vector3(-.5, .92, -1.85), Vector3(-.55, .78, -2.3), 50.0, "wait:1.0"],
	["gate-1-courtyard", "street", Vector3(10.2, -1.32, 4.1), Vector3(13.5, -1.6, 4.1), 72.0, "gate:closed"],
	["gate-2-open", "street", Vector3(10.6, -1.32, 3.6), Vector3(14.5, -1.6, 4.6), 72.0, "gate:open"],
	["street-1-lane", "street", Vector3(13.6, -1.32, 4.4), Vector3(22.0, -1.6, 8.0), 72.0, ""],
	["street-2-street-b", "street", Vector3(20.2, -1.32, 6.0), Vector3(20.5, -1.6, 30.0), 72.0, ""],
	["street-3-street-a", "street", Vector3(19.5, -1.32, 18.6), Vector3(-5.0, -1.6, 17.0), 72.0, ""],
	["street-4-back-to-house", "street", Vector3(20.0, -1.32, 10.0), Vector3(10.0, -1.0, 3.0), 72.0, ""],
]

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.get_slice("=", 1)
	return fallback

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _run() -> void:
	var which := _arg("views", "all")
	var out := _arg("out", "user://v6")
	var size := _arg("size", "1600x900").split("x")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(int(size[0]), int(size[1]))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 6:
		await process_frame
	var lighting := InteriorLighting.find_in(main)
	if lighting != null:
		lighting.apply_quality(int(_arg("quality", "2")))
	var player: Node = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = player.camera
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var tv: InteriorTelevision = main.find_child("TelevisionController", true, false)
	var gate: Node = null
	for door in get_nodes_in_group("interior_doors"):
		if door.has_method("unlock"):
			gate = door
	for view: Array in VIEWS:
		if which != "all" and view[1] != which:
			continue
		camera.fov = view[4]
		camera.global_position = view[2]
		camera.look_at(view[3])
		var action: String = view[5]
		if action == "off" and tv != null:
			tv.set_power(false)
		elif action.begins_with("on:") and tv != null:
			tv.set_power(true)
			await _wait(float(action.get_slice(":", 1)))
		elif action.begins_with("wait:"):
			await _wait(float(action.get_slice(":", 1)))
		elif action == "channel" and tv != null:
			tv.change_channel(1)
			await _wait(.5)
		elif action == "news" and tv != null:
			tv.change_channel(-1)
		elif action.begins_with("gate:") and gate != null:
			gate.call("snap_open" if action.ends_with("open") else "snap_closed")
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(str(view[0]) + ".png"))
		print("V6_VIEW ", view[0])
	quit(0)
