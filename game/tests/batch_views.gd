extends SceneTree
## 0.65: the same fixed views of each box-kit district, for comparing builds (InteriorColourBatch on and off):
##   godot --path game --script res://tests/batch_views.gd -- --out=<dir> [--no-colour-batch]
## The infected are cleared and time stopped before each picture, so what differs is what was built.
var main
var out_dir := "res://../work/v65/batch_views"
var cam: Camera3D

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func settle() -> void:
	await frames(45)
	for i in 900:
		var cs = main.coop.get("_chapter_screen")
		var busy: bool = main.coop.get("_catching") == true or main.coop.get("board_open") == true
		if not busy and (cs == null or not cs.visible): break
		await process_frame
	await frames(20)

func shot(label: String, eye: Vector3, aim: Vector3) -> void:
	var m = main.coop.mission
	for k in m.enemies.keys():
		var z = m.enemies[k]
		if is_instance_valid(z): z.queue_free()
		m.enemies.erase(k)
	main.player.reset_motion(eye + Vector3.DOWN * 1.6)
	main.coop.team[main.coop.local_id()].pos = eye + Vector3.DOWN * 1.6
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 72.0
		cam.far = 500.0
		root.add_child(cam)
	cam.current = true
	cam.global_position = eye
	cam.look_at(aim, Vector3.UP)
	Engine.time_scale = 1.0
	await frames(30)
	Engine.time_scale = 0.0
	await frames(6)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out_dir).path_join(label + ".png")
	var img: Image = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	print("BATCH_VIEW ", path)
	Engine.time_scale = 1.0

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(40)
	main.capturing = true
	var s = main.coop
	s.host()
	s.start_game()
	await frames(25)
	var m = s.mission
	s.harmless = true
	var o: Vector3 = m.Street.ORIGIN
	m.debug_jump("storeroad")
	await settle()
	await shot("a_storeroad", o + Vector3(0, 1.7, 8), o + Vector3(0, 1.4, 40))
	await shot("b_store_front", o + Vector3(-4, 1.7, 44), o + Vector3(2, 1.6, 56))
	m.debug_jump("siege")
	await settle()
	await shot("c_store_inside", o + Vector3(5.5, 1.7, 57.5), o + Vector3(-4, 1.2, 66))
	m.debug_jump("arcade")
	await settle()
	await shot("d_arcade", o + Vector3(43, 1.7, 186), o + Vector3(43, 1.8, 230))
	m.debug_jump("lobby")
	await settle()
	await shot("e_lobby", o + Vector3(28, 1.7, 514), o + Vector3(28, 1.5, 530))
	m.debug_jump("floor2")
	await settle()
	await shot("f_floor2", o + Vector3(30, m.SCHOOL.H + 1.7, 523.5), o + Vector3(50, m.SCHOOL.H + 1.4, 523.5))
	m.debug_jump("outerplaza")
	await settle()
	var os = m.outer_street
	await shot("g_outer_plaza", os.world(Vector3(40, 1.7, 668)), os.world(Vector3(20, 3, 690)))
	await shot("h_pizzahan", os.world(Vector3(23.0, 1.75, 785.2)), os.world(Vector3(23.0, 1.0, 777.6)))
	await shot("i_mart_atrium", os.world(Vector3(47.6, 1.75, 771.6)), os.world(Vector3(50.0, 2.0, 776.0)))
	quit(0)
