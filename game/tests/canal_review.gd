extends SceneTree
## Rendered review of the 0.17 canal settlement (Forward+, High, 1600x900).
##   Godot --path game --script res://tests/canal_review.gd -- [--out=<dir>] [--only=<prefix>]
const C := preload("res://scripts/canal_settlement.gd")
var main: Node
var player: InteriorPlayer
var out := "res://../work/canal17/screens"
var only := ""
var exposure := 1.0
var measures: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func shot(label: String, eye: Vector3, target: Vector3, fov := 72.0) -> void:
	if only != "" and not label.begins_with(only): return
	player.global_position = eye - Vector3.UP * 1.58
	player.camera.global_position = eye
	player.camera.look_at(target)
	player.camera.fov = fov
	if exposure != 1.0:
		var env: Environment = main.get_viewport().world_3d.environment if main.get_viewport().world_3d.environment else main.find_children("*", "WorldEnvironment", true, false)[0].environment
		env.tonemap_exposure = 1.02 * exposure
	await frames(60)
	var begin := Time.get_ticks_usec()
	await frames(60)
	measures.append({"view": label, "fps": 60000000.0 / (Time.get_ticks_usec() - begin),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CANAL_VIEW ", label, " ", measures[-1])

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg.begins_with("--exposure="): exposure = float(arg.trim_prefix("--exposure="))
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
	main.get_node("Stranger").process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var F := C.FLOOR
	await shot("01-bridge-view", C.at(-.5, F + 1.62, C.BRIDGE_Z - 1.6), C.at(1.5, C.WATER + 1.8, 22.0), 70)
	await shot("02-catwalk-north", C.at(4.7, C.CATWALK + 1.6, 6.0), C.at(4.3, C.CATWALK + 1.3, 22.0))
	await shot("03-catwalk-bulb", C.at(4.8, C.CATWALK + 1.6, C.STAIR_Z + 7.5), C.at(4.4, C.CATWALK + 1.4, C.STAIR_Z + 2.0))
	await shot("04-lane", C.at(14.9, F + 1.6, 27.0), C.at(14.4, F + 1.4, 10.0))
	await shot("05-entry", Vector3(-27.0, -1.3, 18.0), Vector3(-45.0, -1.0, 18.5))
	await shot("06-far-path", C.at(-7.1, C.PATH + 1.6, 12.0), C.at(5.0, C.FLOOR + .5, 26.0))
	await shot("07-footbridge", C.at(4.5, C.CATWALK + 1.6, C.FOOT_Z + .3), C.at(-7.0, C.PATH + 1.2, C.FOOT_Z - .5))
	await shot("08-shrine", C.at(-7.0, C.path_y(28.0) + 1.6, 28.6), C.at(-8.8, C.path_y(31.0) + 1.0, 31.0), 66)
	await shot("09-overview", C.at(-2.0, F + 12.0, -14.0), C.at(1.0, C.WATER, 30.0), 70)
	await shot("10-stair-trench", C.at(10.5, F + 1.6, C.STAIR_Z), C.at(5.0, C.CATWALK + .8, C.STAIR_Z), 70)
	var report := FileAccess.open(out.path_join("render.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "resolution": "1600x900",
		"quality": "High", "views": measures, "counts": main.find_child("Canal settlement", true, false).get_meta("counts")}, "\t"))
	print("CANAL_REVIEW_COMPLETE")
	quit()
