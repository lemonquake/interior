extends SceneTree
## 0.26 review renders of the player's house from outside (work light, no lens).
##   Godot --path game --script res://tests/home_review.gd -- [--out=<dir>] [--night] [--only=a,b]
var main: Node
var out := "res://../work/v26/home"

const VIEWS := [
	["courtyard", Vector3(11.6, -1.3, 4.2), Vector3(4.0, .6, 3.6)],
	["lane", Vector3(17.5, -1.3, 4.6), Vector3(4.0, .5, 2.0)],
	["street-b", Vector3(22.6, -1.3, 0.0), Vector3(0.0, .8, 1.0)],
	["street-b-south", Vector3(22.0, -1.3, -12.0), Vector3(0.0, .5, 0.0)],
	["street-a", Vector3(-2.0, -1.3, 17.0), Vector3(-2.0, .6, 5.0)],
	["street-a-east", Vector3(12.0, -1.3, 17.0), Vector3(2.0, .6, 4.0)],
	["south", Vector3(-1.0, -1.3, -14.0), Vector3(-1.0, .6, 0.0)],
	["west", Vector3(-17.5, -1.3, 2.0), Vector3(-3.0, .6, 2.0)],
	["aerial-ne", Vector3(20.0, 14.0, 20.0), Vector3(0.0, 0.0, 2.0)],
	["aerial-sw", Vector3(-18.0, 13.0, -14.0), Vector3(0.0, 0.0, 2.0)],
	["top", Vector3(1.0, 34.0, 2.5), Vector3(1.0, 0.0, 2.0)],
]

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	var only := PackedStringArray()
	var night := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
		if arg == "--night": night = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(40)
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
		stranger.visible = false
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	if not night:
		var sun := DirectionalLight3D.new()
		sun.light_energy = 1.1
		sun.light_cull_mask = 0xFFFFF
		sun.shadow_enabled = false
		main.add_child(sun)
		sun.look_at_from_position(Vector3.ZERO, Vector3(-.5, -1.0, -.35), Vector3.UP)
		var fill := DirectionalLight3D.new()
		fill.light_energy = .5
		fill.light_cull_mask = 0xFFFFF
		main.add_child(fill)
		fill.look_at_from_position(Vector3.ZERO, Vector3(.6, -.4, .7), Vector3.UP)
	var camera: Camera3D = player.camera
	for view: Array in VIEWS:
		if not only.is_empty() and not str(view[0]) in only:
			continue
		player.global_position = (view[1] as Vector3) - Vector3.UP * 1.58
		camera.global_position = view[1]
		if str(view[0]) == "top":
			camera.look_at(view[2], Vector3(0, 0, 1))
		else:
			camera.look_at(view[2])
		camera.fov = 70.0
		await frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("home-%s.png" % view[0]))
	print("HOME_REVIEW ", out)
	quit()
