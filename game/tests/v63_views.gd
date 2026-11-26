extends SceneTree
## 0.63 review captures (Forward+, real lighting, waits until the chapter screen has faded):
##   godot --path game --script res://tests/v63_views.gd -- --set=school|outer|all [--out=<dir>] [--only=a,b]
## School set: room 208 after the blast and the 5F mechanical room door. Outer set: Outer Street.
var main
var out_dir := "res://../work/v63/screens"
var cam: Camera3D
var only: PackedStringArray = []

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func settle() -> void:
	# Until the chapter screen (loading, then "Ready") is gone.
	await frames(45)
	for i in 900:
		var cs = main.coop.get("_chapter_screen")
		var busy: bool = main.coop.get("_catching") == true or main.coop.get("board_open") == true
		if not busy and (cs == null or not cs.visible): break
		await process_frame
	await frames(20)

func shot(label: String, eye: Vector3, aim: Vector3, stand: Vector3 = Vector3.INF) -> void:
	if not only.is_empty() and not label.get_slice("_", 0) in only and not label in only: return
	var player: InteriorPlayer = main.player
	var at := stand if stand.is_finite() else Vector3(eye.x, eye.y - 1.6, eye.z)
	player.reset_motion(at)
	main.coop.team[main.coop.local_id()].pos = at
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 72.0
		cam.far = 500.0
		root.add_child(cam)
	cam.current = true
	cam.global_position = eye
	cam.look_at(aim, Vector3.UP)
	await frames(24)
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out_dir).path_join(label + ".jpg")
	var img: Image = root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(path, 0.92)
	print("V63_VIEW ", path)

func _run() -> void:
	var which := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.trim_prefix("--out=")
		if a.begins_with("--set="): which = a.trim_prefix("--set=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
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
	if which in ["school", "all"]:
		var H: float = m.SCHOOL.H
		m.debug_jump("duct")
		await settle()
		var dx: float = m.school.mech_door_x
		await shot("s01_mech_door_shut", o + Vector3(36.4, 4 * H + 1.6, 530.2), o + Vector3(dx, 4 * H + 1.0, 525.0))
		m.flags.mechdoor = true
		await frames(60)
		await shot("s02_mech_door_forced", o + Vector3(36.4, 4 * H + 1.6, 530.2), o + Vector3(dx, 4 * H + 1.0, 523.0))
		await shot("s03_mech_door_corridor", o + Vector3(33.0, 4 * H + 1.6, 523.3), o + Vector3(dx, 4 * H + 1.0, 525.2))
		m.debug_jump("blast")
		await settle()
		await shot("s04_2f_from_fire_door", o + Vector3(54.0, H + 1.6, 523.5), o + Vector3(14.0, H + 1.2, 523.5))
		await shot("s05_2f_desk_wall_down", o + Vector3(46.0, H + 1.6, 523.2), o + Vector3(36.0, H + .3, 523.6))
		await shot("s06_208_door_spill", o + Vector3(21.0, H + 1.6, 523.2), o + Vector3(14.8, H + 1.0, 525.0))
		await shot("s07_208_breach", o + Vector3(14.6, H + 1.6, 526.0), o + Vector3(11.0, H - .6, 536.0))
		await shot("s08_roof_to_ramp", o + Vector3(11.0, 4.4, 535.0), o + Vector3(11.0, .4, 545.0))
		await shot("s09_ramp_from_field", o + Vector3(14.5, 1.7, 551.0), o + Vector3(11.0, 2.2, 538.0))
	if which in ["outer", "all"]:
		m.debug_jump("outerstreet")
		await settle()
		var os = m.outer_street
		if os != null and os.has_method("review_views"):
			for v: Array in os.review_views():
				if v.size() > 3:
					for k: String in v[3]: m.flags[k] = v[3][k]
					await frames(30)
				await shot(str(v[0]), os.world(v[1]), os.world(v[2]))
	if which in ["hospital"]:
		# 0.68: the hospital (hospital-local spots).
		var jumps := [["hospital", [["h01_street", Vector3(0, 1.7, -21), Vector3(0, 4.0, 0)], ["h02_ambulance", Vector3(-13, 1.7, -14), Vector3(-7, 1.2, -6.6)]]],
			["hosplobby", [["h03_lobby", Vector3(7, 1.7, 13.5), Vector3(-4, 2.5, 2)], ["h04_lobby_ring", Vector3(1, 1.6, 12), Vector3(0, 8.0, 4.5)], ["h05_er", Vector3(11, 1.7, 11.2), Vector3(20, 1.0, 19.5)]]],
			["hosp2f", [["h06_2f_corridor", Vector3(-14, 5.9, 23), Vector3(10, 5.2, 23)], ["h07_balcony", Vector3(-6, 5.9, 19), Vector3(4, 2.0, 3)]]],
			["berido", [["h08_theatre", Vector3(7.5, 5.9, 26.5), Vector3(12, 5.0, 32)], ["h09_supply_berido", Vector3(16.6, 5.2, 32.8), Vector3(22.6, 4.8, 34.6)]]],
			["kitchen", [["h10_cafeteria", Vector3(-11.2, 5.9, 2.0), Vector3(-20, 5.0, 16)]]],
			["records", [["h11_records_bookcase", Vector3(-4.5, 5.9, 27.0), Vector3(-10.1, 5.4, 33.2)]]],
			["hosp3f", [["h12_3f_corridor", Vector3(-22.5, 10.1, 24), Vector3(4, 9.6, 24)], ["h13_big_door", Vector3(-3, 10.1, 24.6), Vector3(4, 10.4, 24)]]],
			["lab", [["h14_lab", Vector3(5.6, 10.2, 14.0), Vector3(16, 10.0, 28)], ["h15_tanks", Vector3(10, 10.0, 20.5), Vector3(14, 10.0, 24)]]],
			["lucky", [["h16_lucky", Vector3(8, 10.1, 20), Vector3(14, 9.6, 33)], ["h17_catwalk", Vector3(22.8, 13.7, 14.2), Vector3(12, 8.6, 30)]]],
			["hosproof", [["h18_roof", Vector3(8, 17.9, 18), Vector3(14, 16.5, 30)]]]]
		for j: Array in jumps:
			m.debug_jump(str(j[0]))
			await settle()
			var hp = m.hospital
			if str(j[0]) == "lucky": await frames(260)
			for v: Array in j[1]:
				await shot(str(v[0]), hp.world(hp.HO + (v[1] as Vector3)), hp.world(hp.HO + (v[2] as Vector3)))
	quit(0)
