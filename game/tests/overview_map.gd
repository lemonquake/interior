extends SceneTree
## 0.66: a top-down picture of part of the co-op world, lit flat, with coloured pins (mission route, start, gate).
##   godot --path game --script res://tests/overview_map.gd -- --rect=x0,z0,x1,z1 [--name=start] [--stage=place]
## World coordinates. Saved to work/v66/map/<name>.jpg. Pins: red Dodong's escort route (numbered order: dark to
## bright), blue the squad's start, white the courtyard gate.
var main
var session
var m
var args := OS.get_cmdline_user_args()

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func pin(at: Vector3, colour: Color, size := .7) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	mat.no_depth_test = true
	s.material = mat
	mi.mesh = s
	root.add_child(mi)
	mi.global_position = at + Vector3.UP * .5

func run() -> void:
	var rect := [-120.0, -20.0, 30.0, 70.0]
	var name := "overview"
	for a in args:
		if a.begins_with("--rect="): rect = Array(a.trim_prefix("--rect=").split(",")).map(func(v): return float(v))
		if a.begins_with("--name="): name = a.trim_prefix("--name=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20: await process_frame
	session = main.coop
	session.host()
	session.start_game()
	m = session.mission
	session.harmless = true
	for a in args:
		if a.begins_with("--stage="):
			print(m.debug_command(1, "jump " + a.trim_prefix("--stage=")))
	await frames(60)
	for i in 1800:
		var cs = session.get("_chapter_screen")
		if session.get("_catching") != true and (cs == null or not cs.visible): break
		await process_frame
	await frames(30)
	main.hud.hide()
	for c in main.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.2
	sun.rotation = Vector3(-1.25, .5, 0)
	sun.shadow_enabled = false
	root.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.08, .08, .1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.85, .85, .85)
	e.ambient_light_energy = 1.2
	env.environment = e
	for w in main.find_children("*", "WorldEnvironment", true, false): (w as WorldEnvironment).environment = e
	for i in m.route.size(): pin(m.route[i], Color(.3 + .7 * float(i) / m.route.size(), 0, 0))
	pin(main.player.global_position, Color(.2, .4, 1.0), 1.0)
	pin(Vector3(12.6, -2.9, 4.1), Color.WHITE, 1.0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var w: float = rect[2] - rect[0]
	var h: float = rect[3] - rect[1]
	cam.size = maxf(w, h)
	cam.near = 1.0
	cam.far = 400.0
	root.add_child(cam)
	cam.global_position = Vector3((rect[0] + rect[2]) * .5, 120.0, (rect[1] + rect[3]) * .5)
	cam.rotation = Vector3(-PI * .5, 0, 0)
	cam.current = true
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://../work/v66/map")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_jpg(dir + "/" + name + ".jpg", .9)
	print("MAP saved ", dir + "/" + name + ".jpg", " rect ", rect)
	quit()
