extends SceneTree
## 0.56: stills of PILCST spots by torchlight (rendered), for checking props, blockers and doors.
##   godot --path game --script res://tests/school_shots.gd -- --out=<dir> [--only=label,label]
var game

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var out := "user://school_shots"
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30: await process_frame
	var s = game.coop
	s.host()
	s.start_game()
	for i in 20: await physics_frame
	game._apply_quality(2)
	var m = s.mission
	s.harmless = true
	m.debug_jump("floor2")
	for i in 30: await physics_frame
	# (A jump past the mart's board loads it behind the chapter screen: wait it out.)
	for i in 1200:
		if not s._catching: break
		await process_frame
	if s._chapter_screen != null: s._chapter_screen.visible = false
	s.set_physics_process(false)
	m.flags.fired = (1 << m.school.doors.size()) - 1
	for k in m.enemies.keys():
		if is_instance_valid(m.enemies[k]): m.enemies[k].queue_free()
		m.enemies.erase(k)
	game.story.gun.holster(true)
	game.story.flashlight.set_on(true)
	game.hud.visible = false
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	var shots := [
		["registrar_behind", Vector3(47.5, 0, 515.2), Vector3(47.5, 1.0, 522.0)],
		["registrar_front", Vector3(47.5, 0, 521.0), Vector3(47.5, 1.0, 514.5)],
		["hall_block_2f", Vector3(37.0, H, 523.5), Vector3(42.0, H + 1.2, 523.5)],
		["classroom_202", Vector3(15.2, H, 521.2), Vector3(9.0, H + .4, 517.0)],
		["corridor_3f", Vector3(44.0, 2 * H, 523.5), Vector3(30.0, 2 * H + 1.0, 523.5)],
		["cafeteria", Vector3(22.5, 0, 520.5), Vector3(8.0, .6, 517.0)],
		["room_501", Vector3(2.0, 4 * H, 515.5), Vector3(7.0, 4 * H + .8, 521.5)],
		["mech_door_5f", Vector3(35.0, 4 * H, 523.0), Vector3(36.0, 4 * H + 1.0, 525.2)],
		["hall_block_4f", Vector3(12.5, 3 * H, 523.5), Vector3(17.4, 3 * H + 1.2, 523.5)],
		["kitchen", Vector3(14.5, 0, 526.5), Vector3(7.0, .6, 531.0)],
		["music_avr_4f", Vector3(44.5, 3 * H, 526.5), Vector3(44.0, 3 * H + .5, 532.0)],
		["computer_lab", Vector3(38.5, 3 * H, 520.5), Vector3(27.0, 3 * H + .5, 517.0)],
		["fire_door_2f", Vector3(57.6, H, 523.6), Vector3(52.0, H + 1.2, 523.5)],
		["stair_block_2f", Vector3(4.55, H, 524.4), Vector3(3.0, H + 2.2, 530.5)],
	]
	for sh: Array in shots:
		if not only.is_empty() and not String(sh[0]) in only: continue
		var at: Vector3 = o + (sh[1] as Vector3)
		var aim: Vector3 = o + (sh[2] as Vector3)
		game.player.reset_motion(at)
		game.player.look_at(Vector3(aim.x, at.y, aim.z))
		game.player.camera.look_at(aim)
		for i in 24:
			m.school.sync(m.flags, 1.0 / 60.0, game.player.global_position)
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join(String(sh[0]) + ".png"))
		print("SCHOOL_SHOT ", sh[0])
	s.end_session()
	quit()
