extends SceneTree
## 0.23 rendered review of the walled town (Forward+, High, 1600x900): the streets, the perimeter wall, the slum
## route, the north hole and the Nichols wall, at eye height under the real night lighting.
##   Godot --path game --script res://tests/siege_review.gd -- [--out=<dir>] [--only=<prefix>[,<prefix>...]] [--bright] [--torch]
## --bright also saves a brightened copy (<view>-b.png): the town grade overrides exposure each frame, so dark
## renders are inspected that way. --torch turns the drawer flashlight on for every view.
var main: Node
var player: InteriorPlayer
var out := "res://../work/v23/screens"
var only := ""
var bright := false
var measures: Array[Dictionary] = []

const EYE := -2.9 + 1.58
const VIEWS := [
	["01-gate-lane", Vector3(13.6, EYE, 4.0), Vector3(20.0, -1.8, 8.0)],
	["02-corner-east", Vector3(21.0, EYE, 16.0), Vector3(60.0, -1.6, 18.0)],
	["03-street-a-west", Vector3(17.5, EYE, 19.0), Vector3(-30.0, -1.6, 18.0)],
	["04-street-b-north", Vector3(21.0, EYE, 38.0), Vector3(21.0, -1.6, 70.0)],
	["05-street-b-south", Vector3(21.0, EYE, -4.0), Vector3(21.0, -1.6, -40.0)],
	["06-street-c-east", Vector3(19.0, EYE, 49.0), Vector3(60.0, -1.6, 49.0)],
	["07-street-c-west", Vector3(14.0, EYE, 49.0), Vector3(-30.0, -1.6, 49.0)],
	["08-street-d-south", Vector3(-19.0, EYE, 12.0), Vector3(-19.0, -1.6, -40.0)],
	["09-street-d-north", Vector3(-19.0, EYE, 24.0), Vector3(-19.0, -1.6, 70.0)],
	["10-slum-mouth", Vector3(-12.0, EYE, 18.6), Vector3(-40.0, -1.8, 18.0)],
	["11-north-hole", Vector3(20.0, EYE, 47.0), Vector3(22.5, -2.2, 56.0)],
	["12-south-wall", Vector3(19.5, EYE, -10.0), Vector3(12.0, -1.8, -19.0)],
	["13-camp", Vector3(1.2, EYE, 19.4), Vector3(-.5, -2.4, 26.5)],
	["16-checkpoint", Vector3(-16.5, EYE, 17.6), Vector3(-22.5, -2.5, 13.0)],
	["17-covered-body", Vector3(21.6, EYE, 8.2), Vector3(24.4, -2.7, 11.4)],
	["18-nw-corner", Vector3(-16.0, EYE, 48.5), Vector3(-22.9, -2.4, 53.8)],
	["19-secret", Vector3(21.8, EYE, -14.5), Vector3(19.4, -2.2, -18.4)],
	["20-hole-close", Vector3(21.3, EYE, 51.2), Vector3(21.3, -2.0, 54.8)],
	["21-tyre-fire", Vector3(19.4, EYE, 29.6), Vector3(22.7, -2.7, 33.6)],
	["22-street-d-south", Vector3(-19.0, EYE, 14.0), Vector3(-19.0, -1.8, 6.0)],
	["14-street-a-east", Vector3(-10.0, EYE, 18.0), Vector3(30.0, -1.6, 18.0)],
	["15-street-b-mid", Vector3(20.0, EYE, 28.0), Vector3(21.5, -1.8, 4.0)],
]

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func shot(label: String, eye: Vector3, target: Vector3, fov := 72.0) -> void:
	if only != "" and not Array(only.split(",")).any(func(prefix: String) -> bool: return label.begins_with(prefix)): return
	player.global_position = eye - Vector3.UP * 1.58
	player.camera.global_position = eye
	player.camera.look_at(target)
	player.camera.fov = fov
	await frames(50)
	var begin := Time.get_ticks_usec()
	await frames(40)
	measures.append({"view": label, "fps": snappedf(40000000.0 / (Time.get_ticks_usec() - begin), .1),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(label + ".png"))
	if bright:
		# x2.6, clipped (the brightened copy is for inspection only).
		image.convert(Image.FORMAT_RGB8)
		var data := image.get_data()
		for i in data.size():
			data[i] = mini(255, data[i] * 13 / 5)
		Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGB8, data).save_png(out.path_join(label + "-b.png"))
	print("SIEGE_VIEW ", label, " ", measures[-1])

func _run() -> void:
	var torch := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--bright": bright = true
		if arg == "--torch": torch = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await frames(10)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	if torch:
		var story: Node = main.get("story")
		if story != null:
			story.debug_give_flashlight()
			story.flashlight.set_on(true)
	for view: Array in VIEWS:
		await shot(view[0], view[1], view[2])
	var report := FileAccess.open(out.path_join("render.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "resolution": "1600x900",
		"quality": "High", "views": measures}, "\t"))
	print("SIEGE_REVIEW_COMPLETE")
	quit()
