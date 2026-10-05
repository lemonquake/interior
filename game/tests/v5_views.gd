extends SceneTree
## RENDERED review captures for the studio and the neighbourhood (do not run with --headless).
##   godot --path game --script res://tests/v5_views.gd -- --views=studio|outdoor|all --out=<dir> [--size=1600x900] [--quality=2]
## Writes one PNG per view; prints V5_VIEW <name> for each.

const VIEWS := [
	# [name, set, camera, target, studio door open, entry door open, fov]
	["studio-1-from-living-room", "studio", Vector3(-.55, 1.6, .45), Vector3(-2.35, 1.25, 3.6), false, false, 72.0],
	["studio-2-door-open", "studio", Vector3(-.55, 1.6, .45), Vector3(-2.35, 1.25, 3.6), true, false, 72.0],
	["studio-3-desk", "studio", Vector3(-3.6, 1.62, 3.55), Vector3(-2.6, 1.0, 7.1), true, false, 70.0],
	["studio-4-guitar-wall", "studio", Vector3(-2.15, 1.6, 4.55), Vector3(-5.6, 1.25, 4.6), true, false, 72.0],
	["studio-5-drums", "studio", Vector3(-2.0, 1.65, 3.6), Vector3(-4.7, .85, 6.5), true, false, 70.0],
	["studio-6-keys-and-door", "studio", Vector3(-4.6, 1.6, 6.0), Vector3(-1.6, 1.0, 3.6), true, false, 72.0],
	["outdoor-1-photo1-view", "outdoor", Vector3(5.3, 1.55, 3.35), Vector3(13.5, .4, 4.6), false, true, 75.0],
	["outdoor-2-railing-out", "outdoor", Vector3(4.5, 1.6, 4.35), Vector3(5.5, -.5, 22.0), false, true, 72.0],
	["outdoor-3-toward-stairs", "outdoor", Vector3(2.7, 1.55, 3.6), Vector3(8.6, -1.0, 3.4), false, true, 62.0],
	["outdoor-4-courtyard-gate", "outdoor", Vector3(11.0, -1.3, 4.0), Vector3(24.0, 1.0, 0.0), false, true, 72.0],
	["outdoor-6-overhead", "outdoor", Vector3(8.0, 75.0, 24.0), Vector3(8.0, -2.9, 20.0), false, true, 70.0],
	["outdoor-5-courtyard-sky", "outdoor", Vector3(10.5, -1.3, 3.4), Vector3(12.0, 3.0, 20.0), false, true, 72.0],
]

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.get_slice("=", 1)
	return fallback

func _run() -> void:
	var which := _arg("views", "all")
	var out := _arg("out", "user://v5")
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
	var hud := main.find_children("*", "CanvasLayer", true, false)
	for layer in hud:
		(layer as CanvasLayer).visible = false
	var studio_door: InteriorSlidingDoor = null
	var entry: InteriorHingedDoor = null
	for door in get_nodes_in_group("interior_doors"):
		if door is InteriorSlidingDoor:
			studio_door = door
		else:
			entry = door
	for view: Array in VIEWS:
		if which != "all" and view[1] != which:
			continue
		if studio_door != null:
			studio_door.snap(view[4])
		if entry != null:
			entry.snap(view[5])
		camera.fov = view[6]
		camera.global_position = view[2]
		camera.look_at(view[3])
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(str(view[0]) + ".png"))
		print("V5_VIEW ", view[0])
	quit(0)
