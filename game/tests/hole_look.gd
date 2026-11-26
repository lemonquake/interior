extends SceneTree
## 0.67: a look at a spot the hole audit (tests/coop_hole_audit.gd) reported. The squad game, a teleport (`go`) or
## a debug jump to get the world there as play leaves it, then the camera at `--eye` (street-local) aimed at `--at`,
## the work light on so the shapes read; one JPEG per `--shot=name:ex,ey,ez:ax,ay,az`.
##   godot --path game --script res://tests/hole_look.gd -- --go=floor5 [--jump] --out=<dir> --shot=a:1,2,3:4,5,6 ...
var main
var s
var m

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _v(t: String) -> Vector3:
	var f := t.split_floats(",")
	return Vector3(f[0], f[1], f[2])

func _run() -> void:
	var place := ""
	var jump := false
	var out := ProjectSettings.globalize_path("res://../work/v67/holes")
	var shots: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--go="): place = a.trim_prefix("--go=")
		if a == "--jump": jump = true
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--shot="): shots.append(a.trim_prefix("--shot=").split(":"))
	DirAccess.make_dir_recursive_absolute(out)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.capturing = true
	s = main.coop
	s.host()
	s.add_bot()
	s.start_game()
	await frames(40)
	m = s.mission
	m.harmless = true
	s.harmless = true
	if place != "":
		print("LOOK > ", m.debug_command(1, ("jump " if jump else "go ") + place))
		await frames(10)
		for i in 7200:
			var cs = s.get("_chapter_screen")
			if s.get("_catching") != true and (cs == null or not cs.visible) and not bool(s.get("board_open")): break
			await process_frame
		await frames(30)
		# (A capture: the chapter screen waits for a player to look at it; out of the way.)
		var screen = s.get("_chapter_screen")
		if screen != null: screen.visible = false
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 400.0
	root.add_child(cam)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 18.0
	lamp.light_energy = 2.5
	root.add_child(lamp)
	for sh: PackedStringArray in shots:
		var eye: Vector3 = m.Street.ORIGIN + _v(sh[1])
		var at: Vector3 = m.Street.ORIGIN + _v(sh[2])
		main.player.reset_motion(eye - Vector3(0, 1.6, 0))
		s.team[s.local_id()].pos = eye - Vector3(0, 1.6, 0)
		cam.current = true
		cam.global_position = eye
		cam.look_at(at, Vector3.UP)
		lamp.global_position = eye + Vector3(0, .4, 0)
		await frames(20)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join(sh[0] + ".jpg"), .9)
		print("LOOK_SHOT ", out.path_join(sh[0] + ".jpg"))
	s.end_session()
	quit()
