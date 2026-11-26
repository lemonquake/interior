extends SceneTree
## Rendered review of the Nichols property (Forward+, High, 1600x900).
##   Godot --path game --script res://tests/nichols_review.gd -- [--out=<dir>] [--only=<prefix>] [--map] [--work-light]
var main: Node
var player: InteriorPlayer
var out := "res://../work/nichols/screens"
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
	player.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	player.camera.global_position = eye
	player.camera.look_at(target)
	player.camera.fov = fov
	await frames(60)
	var begin := Time.get_ticks_usec()
	await frames(60)
	measures.append({"view": label, "fps": 60000000.0 / (Time.get_ticks_usec() - begin),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("NICHOLS_VIEW ", label, " ", measures[-1])
	if "--fogtest=debug" in OS.get_cmdline_user_args():
		var prop := main.find_child("Nichols property", true, false)
		print("  paused ", paused, " prop process ", prop.can_process() if prop else "none", " inside ", prop.get("_inside") if prop else -1)
		for l: Light3D in main.find_children("*", "DirectionalLight3D", true, false):
			print("  ", l.name, " vol ", l.light_volumetric_fog_energy, " mask ", l.light_cull_mask, " vis ", l.visible, " energy ", l.light_energy)
		var env: Environment = main.find_children("*", "WorldEnvironment", true, false)[0].environment
		print("  inject ", env.volumetric_fog_ambient_inject, " vf ", env.volumetric_fog_enabled, " ambient ", env.ambient_light_energy, " ", env.ambient_light_source)
		var inner := main.find_child("Moon through the windows", true, false) as DirectionalLight3D
		inner.light_volumetric_fog_energy = 0.0
		await frames(40)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(label + "-novol.png"))
		inner.light_volumetric_fog_energy = 5.0
		inner.shadow_enabled = false
		await frames(40)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(label + "-noshadow.png"))

## Orthographic top-down map with a flat work light, for layout checks.
func map(label: String, centre: Vector3, size: float) -> void:
	if only != "" and not label.begins_with(only): return
	player.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	player.camera.size = size
	player.camera.far = 400.0
	player.camera.global_position = centre + Vector3.UP * 120.0
	player.camera.look_at(centre, Vector3.FORWARD)
	for n: Node in main.find_children("*", "Node3D", true, false):
		if n.has_method("_update_visibility"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.visible = true
	await frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("NICHOLS_MAP ", label)

func work_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = false
	main.add_child(sun)
	for env_node: WorldEnvironment in main.find_children("*", "WorldEnvironment", true, false):
		env_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_node.environment.ambient_light_color = Color(.8, .8, .8)
		env_node.environment.ambient_light_energy = 1.5
		env_node.environment.fog_enabled = false
		env_node.environment.volumetric_fog_enabled = false

func _run() -> void:
	var want_map := false
	var light := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--map": want_map = true
		if arg == "--work-light": light = true
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
	if light: work_light()
	var fogtest := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fogtest="): fogtest = arg.trim_prefix("--fogtest=")
	if fogtest != "":
		await frames(5)
		for l: Light3D in main.find_children("*", "DirectionalLight3D", true, false):
			if fogtest == "nomoon": l.light_volumetric_fog_energy = 0.0
			print("DIRLIGHT ", l.name, " vol ", l.light_volumetric_fog_energy, " shadow ", l.shadow_enabled, " mask ", l.light_cull_mask, " vis ", l.visible)
		var env: Environment = main.find_children("*", "WorldEnvironment", true, false)[0].environment
		print("ENV inject ", env.volumetric_fog_ambient_inject, " density ", env.volumetric_fog_density, " enabled ", env.volumetric_fog_enabled)
	if want_map:
		await map("map-south", Vector3(-5, 0, -60), 140.0)
		await map("map-wide", Vector3(-20, 0, -10), 400.0)
	await shot("00-gate-south", Vector3(15.0, -1.32, 3.6), Vector3(-6.0, 1.0, -60.0), 72)
	await shot("00b-gate-arrow", Vector3(13.4, -1.32, 4.3), Vector3(-12.0, 6.0, -90.0), 72)
	await shot("01-path", Vector3(20.4, -1.3, -27.0), Vector3(-12.0, 3.0, -88.0), 70)
	await shot("02-gate", Vector3(-11.0, -1.3, -52.5), Vector3(-12.0, 1.5, -82.0), 70)
	await shot("03-drive", Vector3(-4.0, -1.3, -71.5), Vector3(-12.0, 2.5, -84.0), 72)
	await shot("04-porch", Vector3(-8.5, -.2, -78.6), Vector3(-12.0, -.4, -82.6), 72)
	await shot("05-foyer", Vector3(-12.0, -.1, -83.0), Vector3(-12.0, 1.4, -90.0), 75)
	await shot("06-parlour", Vector3(-16.6, -.1, -90.8), Vector3(-24.1, .0, -87.2), 75)
	await shot("07-corridor", Vector3(-16.5, 4.3, -83.3), Vector3(-25.0, 3.6, -83.4), 75)
	await shot("08-dining", Vector3(-7.4, -.1, -83.4), Vector3(-3.6, -.6, -88.0), 75)
	await shot("09-hall", Vector3(.2, -.1, -94.2), Vector3(-24.0, -.4, -94.2), 70)
	await shot("10-master", Vector3(-16.8, 4.3, -85.0), Vector3(-21.0, 3.8, -92.0), 75)
	await shot("11-nursery", Vector3(-7.2, 4.3, -85.2), Vector3(-1.0, 3.4, -90.0), 75)
	await shot("12-bridge", Vector3(-12.0, 4.4, -83.0), Vector3(-12.0, 1.0, -89.5), 75)
	await shot("13-exterior", Vector3(9.0, 2.0, -52.0), Vector3(-12.0, 3.5, -88.0), 65)
	if only == "" or only.begins_with("2"):
		var story: Node = main.get("story")
		if story != null:
			story.debug_give_flashlight()
			story.flashlight.set_on(true)
			await frames(5)
		await shot("20-torch-foyer", Vector3(-12.0, -.1, -83.2), Vector3(-12.0, .6, -89.5), 75)
		await shot("21-torch-dining", Vector3(-7.4, -.1, -83.4), Vector3(-3.6, -.6, -88.0), 75)
		await shot("22-torch-parlour-fire", Vector3(-19.5, -.1, -87.4), Vector3(-24.2, .1, -87.5), 70)
		await shot("23-torch-nursery", Vector3(-7.2, 4.3, -85.2), Vector3(-1.0, 3.2, -90.0), 75)
		await shot("24-torch-library", Vector3(-17.5, -.1, -95.8), Vector3(-23.0, .3, -99.5), 75)
		await shot("25-torch-wallpaper", Vector3(-16.0, 4.3, -83.4), Vector3(-16.0, 4.0, -84.5), 70)
		await shot("26-torch-hall-doll", Vector3(-20.0, -.1, -94.2), Vector3(-24.2, -1.2, -94.2), 70)
	var report := FileAccess.open(out.path_join("render.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "resolution": "1600x900",
		"quality": "High", "views": measures}, "\t"))
	print("NICHOLS_REVIEW_COMPLETE")
	quit()
