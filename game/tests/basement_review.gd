extends SceneTree
## Rendered review of the Nichols house rooms, the blood trail and the basement (0.22, Forward+ High, 1600x900).
##   Godot --path game --script res://tests/basement_review.gd -- [--out=<dir>] [--only=<prefix>] [--work-light] [--torch]
##     [--lights-on] [--flicker-off]
## --work-light lifts every room's ambient (a flat light for layout checks), --torch switches the flashlight on,
## --lights-on throws the basement switch first.
const HOUSE := Vector3(-12.0, -1.7, -82.0)
const F1 := 4.4
var main: Node
var player: InteriorPlayer
var out := "res://../work/basement-v22/screens"
var only := ""
var measures: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

## House space (x east, depth from the front facade, height above the ground-floor boards) to world.
static func hl(x: float, depth: float, up := 0.0) -> Vector3:
	return HOUSE + Vector3(x, up, -depth)

func shot(label: String, eye: Vector3, target: Vector3, fov := 72.0) -> void:
	if only != "" and not label.begins_with(only): return
	player.global_position = eye - Vector3.UP * 1.58
	player.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	player.camera.global_position = eye
	player.camera.look_at(target)
	player.camera.fov = fov
	await frames(50)
	var begin := Time.get_ticks_usec()
	await frames(30)
	measures.append({"view": label, "fps": 30000000.0 / (Time.get_ticks_usec() - begin),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("BASEMENT_VIEW ", label, " ", measures[-1])

func work_light() -> void:
	# A big shadowless lamp on the camera: every layer, so the house's own light layers do not matter.
	var lamp := OmniLight3D.new()
	lamp.name = "Review work light"
	lamp.omni_range = 30.0
	lamp.omni_attenuation = .6
	lamp.light_energy = 2.2
	lamp.light_cull_mask = 0xFFFFF
	lamp.shadow_enabled = false
	player.camera.add_child(lamp)
	for env_node: WorldEnvironment in main.find_children("*", "WorldEnvironment", true, false):
		env_node.environment.fog_enabled = false
		env_node.environment.volumetric_fog_enabled = false

func _run() -> void:
	var light := false
	var torch := false
	var lights_on := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--work-light": light = true
		if arg == "--torch": torch = true
		if arg == "--lights-on": lights_on = true
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
	await frames(30)
	if light: work_light()
	var prop := main.find_child("Nichols property", true, false)
	var basement: Node = prop.get("basement") if prop != null else null
	if lights_on and basement != null:
		basement.set_basement_lights(true, true)
	if "--flicker-off" in OS.get_cmdline_user_args() and basement != null:
		basement.set("flicker_enabled", false)
	if "--front-open" in OS.get_cmdline_user_args():
		for d in main.get_tree().get_nodes_in_group("nichols_doors"):
			if (d as Node3D).global_position.distance_to(hl(0, -.45)) < 1.5 and absf((d.get("_body") as Node3D).rotation.y) < 1.0:
				d.toggle()
		await frames(150)
	if torch:
		var story: Node = main.get("story")
		if story != null:
			story.debug_give_flashlight()
			story.flashlight.set_on(true)
			await frames(5)
	# Rooms (layout checks).
	await shot("r01-foyer", hl(0, .2, 1.58), hl(0, 6.5, 1.0), 75)
	await shot("r02-foyer-east", hl(-2.2, 1.6, 1.58), hl(4, 2.4, .9), 75)
	await shot("r03-parlour-door", hl(-7.0, 12.9, 1.58), hl(-7.0, 11.0, 1.6), 70)
	await shot("r04-parlour", hl(-5.0, 1.4, 1.58), hl(-11.5, 8.5, .7), 75)
	await shot("r05-dining", hl(5.0, 1.4, 1.58), hl(11.0, 9.0, .6), 75)
	await shot("r06-hall", hl(11.5, 12.2, 1.58), hl(-12.0, 12.2, .9), 70)
	await shot("r07-library", hl(-7.5, 14.0, 1.58), hl(-8.0, 19.6, .9), 78)
	await shot("r08-library-east", hl(-10.5, 16.5, 1.58), hl(-4.0, 16.5, 1.0), 78)
	await shot("r09-kitchen", hl(5.0, 14.0, 1.58), hl(11.5, 19.4, .6), 78)
	await shot("r10-master", hl(-4.8, 3.2, F1 + 1.58), hl(-12.0, 9.5, F1 + .8), 78)
	await shot("r11-nursery", hl(4.8, 3.2, F1 + 1.58), hl(12.0, 9.0, F1 + .6), 78)
	await shot("r13-parlour-doorway", hl(-7.2, 7.6, 1.58), hl(-7.0, 11.0, 1.55), 70)
	await shot("r12-corridor", hl(11.5, 1.3, F1 + 1.58), hl(-12.0, 1.3, F1 + 1.0), 70)
	# The blood trail and the way down.
	await shot("t01-entry", hl(-.3, .1, 1.58), hl(.7, 3.2, 0.0), 72)
	await shot("t02-stair-foot", hl(-.4, 2.0, 1.58), hl(1.9, 5.2, 0.0), 72)
	await shot("t03-nook", hl(2.0, 4.4, 1.58), hl(1.95, 9.4, .9), 72)
	await shot("t04-door", hl(2.0, 7.9, 1.58), hl(1.95, 9.4, .9), 72)
	await shot("t05-landing", hl(2.4, 10.0, 1.58), hl(-2.0, 10.2, -1.6), 78)
	await shot("t06-stairs-up", hl(-3.4, 10.2, -2.7 + 1.58), hl(2.0, 10.2, .6), 78)
	await shot("b01-cellar", hl(-3.4, 11.2, -2.7 + 1.58), hl(-8.5, 17.0, -2.4), 80)
	await shot("b02-cellar-east", hl(-8.0, 13.0, -2.7 + 1.58), hl(-0.3, 16.8, -2.0), 80)
	await shot("b03-hole", hl(-2.6, 15.6, -2.7 + 1.58), hl(0.0, 16.8, -2.0), 75)
	await shot("b04-corridor", hl(1.6, 16.8, -3.6 + 1.58), hl(12.4, 16.8, -2.4), 72)
	await shot("b05-corridor-back", hl(11.0, 16.6, -3.6 + 1.58), hl(0.0, 16.8, -2.6), 72)
	await shot("b06-door", hl(9.0, 16.6, -3.6 + 1.58), hl(12.4, 16.8, -2.0), 70)
	await shot("k01-kitchen-sink", hl(8.0, 14.2, 1.58), hl(8.0, 19.7, .9), 75)
	await shot("k02-fridge", hl(7.2, 15.2, 1.58), hl(12.3, 16.9, .9), 72)
	await shot("k03-jumper", hl(10.4, 18.6, 1.45), hl(12.6, 16.6, .45), 70)
	var report := FileAccess.open(out.path_join("render.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "resolution": "1600x900",
		"quality": "High", "views": measures}, "\t"))
	print("BASEMENT_REVIEW_COMPLETE")
	quit()
