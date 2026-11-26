extends SceneTree
## Rendered review of the 0.18 canal warren (Forward+, High, 1600x900).
##   Godot --path game --script res://tests/warren_review.gd -- [--out=<dir>] [--only=<prefix>] [--exposure=<x>]
const C := preload("res://scripts/canal_settlement.gd")
const W := preload("res://scripts/canal_warren.gd")
var main: Node
var player: InteriorPlayer
var out := "res://../work/warren18/screens"
var only := ""
var exposure := 1.0
var work_light: OmniLight3D
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
	if work_light != null: work_light.global_position = eye + Vector3.UP * .3
	await frames(50)
	if exposure != 1.0:
		for env_node: WorldEnvironment in main.find_children("*", "WorldEnvironment", true, false):
			env_node.environment.tonemap_exposure *= exposure
	var begin := Time.get_ticks_usec()
	await frames(30)
	measures.append({"view": label, "fps": 30000000.0 / (Time.get_ticks_usec() - begin),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("WARREN_VIEW ", label, " ", measures[-1])

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg.begins_with("--exposure="): exposure = float(arg.trim_prefix("--exposure="))
		if arg == "--work-light":
			work_light = OmniLight3D.new()
			work_light.omni_range = 14.0
			work_light.light_energy = 3.0
			work_light.light_cull_mask = 2
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await frames(10)
	if work_light != null: main.add_child(work_light)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("Stranger").process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var F := C.FLOOR
	var D := W.DECK + 1.58
	await shot("01-gate-outside", W.at(-22.0, F + 1.6, 9.5), W.at(-28.5, F + 1.1, 8.0), 70)
	await shot("02-alley", W.at(-29.6, F + 1.6, 8.0), W.pos(1.7, F + 1.2, 7.0), 70)
	await shot("03-east-tunnel", W.pos(1.75, D, 6.6), W.pos(1.6, D - .3, -3.0))
	await shot("04-cave-in", W.pos(1.75, D, 1.6), W.pos(1.7, W.DECK + .9, -1.5))
	await shot("05-bridge", W.pos(1.75, D, -8.6), W.pos(-1.7, W.DECK + 1.0, -11.0))
	await shot("06-family-room", W.pos(-1.5, D, 1.35), W.pos(-4.6, W.DECK + .5, 4.6))
	await shot("07-altar", W.pos(-1.5, D, 18.4), W.pos(-6.3, F + 1.2, 20.5))
	await shot("08-yard", W.pos(-1.7, D, 26.6), W.pos(-5.2, F + .9, 31.5))
	await shot("09-store", W.pos(-1.4, D, 40.5), W.pos(-3.2, F + 1.3, 43.0))
	await shot("10-west-tunnel", W.pos(-1.75, D, 8.0), W.pos(-1.7, D - .3, 16.0))
	await shot("11-overview", W.at(-24.0, F + 16.0, -20.0), W.pos(0, F, 22.0), 70)
	await shot("12-yard-high", W.pos(-8.0, F + 6.0, 24.0), W.pos(-2.0, F, 33.0), 70)
	await shot("14-locked-door", W.pos(-1.5, D, 11.0), W.pos(-2.45, W.DECK + 1.0, 13.0), 70)
	var k := 0
	for door: Node3D in get_nodes_in_group("warren_locked"):
		if k >= 4: break
		if door.name == "Store window": continue
		var n := door.global_basis.z
		await shot("15-door-%d" % k, door.global_position + n * 1.7 + Vector3.UP * .6, door.global_position, 70)
		k += 1
	await shot("13-lane-chairs", C.at(14.9, F + 1.6, 27.0), C.at(14.4, F + 1.0, 14.0), 70)
	var report := FileAccess.open(out.path_join("render.json"), FileAccess.WRITE)
	var warren := main.find_child("Canal warren", true, false)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "resolution": "1600x900",
		"quality": "High", "views": measures, "counts": warren.get_meta("counts") if warren else {}}, "\t"))
	print("WARREN_COUNTS ", warren.get_meta("counts") if warren else "missing")
	print("WARREN_REVIEW_COMPLETE")
	quit()
