extends SceneTree
## 0.49: the run in chapters, the squad AI holding still for a patch-up, and rounds through walking boxes.
## - a squad member patched up while it was running stays where it is until it is done;
## - the backstreets are put away at the start (hidden, silent) and woken when the chapter board comes up;
## - after Jonna's talk she walks out to the mart's front, pulls the steel shutter down and padlocks it; the street
##   behind is put away, the infected outside are gone, the shutter is solid;
## - the chapter leaderboard comes up with READY; the squad AI are ready; once the host is, the run goes on (stage 8);
## - the jeepney's walking box lets rounds through to the model, the Old Salmonan gate's bars let rounds between them.
##   godot --path game --script res://tests/coop_chapters.gd -- [--shots=<dir>]   (prints INTERIOR_CHAPTERS ok|FAIL)
var game
var session
var failed := []
var checks := 0
var shots := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("CHAPTERS CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func shot(name: String) -> void:
	if shots == "": return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_jpg(shots.path_join(name + ".jpg"), .9)
	print("CHAPTERS SHOT ", shots.path_join(name + ".jpg"))

func stand(at: Vector3, yaw: float) -> void:
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = yaw
	session.team[1].pos = at
	session.team[1].yaw = yaw

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): shots = a.trim_prefix("--shots=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(20)
	var m = session.mission
	session.harmless = true
	var bs: Node3D = m.street.backstreets
	check(not bs.visible, "the backstreets are put away at the start")
	check(not m.ahead_awake, "and not woken yet")
	var paused := true
	for a in bs.find_children("*", "AudioStreamPlayer3D", true, false):
		if (a as Node).can_process(): paused = false
	check(paused, "their sounds are paused")

	# --- rounds and walking boxes
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var jeep_box: CollisionShape3D = null
	for c in m.street.solid.get_children():
		if c is CollisionShape3D and c.has_meta("unseen") and (c.shape as BoxShape3D).size.is_equal_approx(Vector3(2.3, 2.4, 6.6)): jeep_box = c
	check(jeep_box != null, "the jeepney's walking box is marked for rounds to pass")
	var shot_mesh: Node = null
	for n in m.street.get_children():
		if String(n.name).begins_with("jeepney") and n.get_node_or_null("Shot mesh") != null: shot_mesh = n.get_node("Shot mesh")
	check(shot_mesh != null and shot_mesh.get_child_count() > 0, "the jeepney model itself is on the shot layer (%d shapes)" % (shot_mesh.get_child_count() if shot_mesh != null else 0))
	var o: Vector3 = m.Street.ORIGIN
	var gate_z: float = m.Street.GATE.z - .25
	var high := InteriorSurfaces.seen_ray(space, o + Vector3(-1.8, 1.75, gate_z - 2.0), o + Vector3(-1.8, 1.75, gate_z + 2.0), InteriorGun.MASK)
	var hit_gate: bool = not high.is_empty() and high.collider == m.street.gate
	check(not hit_gate, "a round between the gate's bars goes through")
	var low := InteriorSurfaces.seen_ray(space, o + Vector3(-1.8, .5, gate_z - 2.0), o + Vector3(-1.8, .5, gate_z + 2.0), InteriorGun.MASK)
	check(not low.is_empty() and low.collider == m.street.gate, "a round into the gate's lower sheet is stopped (%s)" % (str(low.collider.get_path()) + " " + str((low.position - o).snapped(Vector3.ONE * .01)) if not low.is_empty() else "nothing"))

	# --- to the office and Jonna's talk
	m.stage = 6
	m.wave_left = 0
	m.flags.office = true
	m.flags.backdoor_open = true
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var store: Vector3 = o + m.Street.STORE
	stand(m.ground(store + Vector3(.3, 0, -4.5)), 0.0)
	var bot_id: int = session.team.keys().filter(func(i): return i < 0)[0]
	var b = session.bots.bots[bot_id]

	# --- a squad member that was running when the patch-up began stays put
	var beside: Vector3 = m.ground(store + Vector3(1.5, 0, -4.5))
	b.body.global_position = beside
	b.body.velocity = Vector3(0, 0, -InteriorPlayer.RUN_SPEED)
	b.dest = beside + Vector3(0, 0, -9.0)
	b.run = true
	session.team[bot_id].pos = beside
	session.team[bot_id].hp = 30
	session.team[bot_id].kits = 0
	session.team[1].kits = 2
	session.team[1].hp = 200
	var started: bool = m.start_heal(1, bot_id)
	check(started, "the host starts patching the squad member up")
	var max_off := 0.0
	for i in 150:
		await physics_frame
		max_off = maxf(max_off, b.body.global_position.distance_to(beside))
		session.team[1].pos = game.player.global_position
	check(max_off < .3, "a running squad member stops dead for the patch-up (%.2f m)" % max_off)
	await frames(60)
	check(int(session.team[bot_id].hp) > 30, "and is patched up (%d)" % int(session.team[bot_id].hp))

	# (What the "jonna" action does, without walking up to her.)
	m.stage = 7
	m.talker = 1
	m.talk_index = -1
	m.talk_wait = .4
	m.jonna_step = 0
	m.jonna.visible = true
	check(m.stage == 7, "Jonna talks (stage 7)")
	var guard := 0
	while int(m.flags.get("lockup", 0)) == 0 and guard < 4000:
		m.talk_wait = minf(m.talk_wait, .05)
		await physics_frame
		guard += 1
	check(int(m.flags.get("lockup", 0)) >= 1, "after the talk Jonna goes to shut the front")
	var saw_pull := false
	var jonna_at_front := false
	guard = 0
	while int(m.flags.get("lockup", 0)) < 4 and guard < 6000:
		await physics_frame
		guard += 1
		if int(m.flags.get("lockup", 0)) == 2:
			saw_pull = true
			jonna_at_front = jonna_at_front or (m.jonna.position - (o + m.FRONT_SPOT)).length() < 1.0
			if shots != "" and float(m.flags.get("shutter", 0.0)) > .5 and float(m.flags.get("shutter", 0.0)) < .56:
				stand(m.ground(store + Vector3(1.6, 0, -2.5)), deg_to_rad(20.0))
				await shot("shutter_coming_down")
	check(saw_pull and jonna_at_front, "she pulls the shutter down standing at the front (%s)" % str((m.jonna.position - o).snapped(Vector3.ONE * .1)))
	await frames(3)
	check(bool(m.flags.get("locked", false)), "and padlocks it")
	check(float(m.flags.get("shutter", 0.0)) >= 1.0 and m.street.shutter_body.collision_layer == 2, "the shutter is down and solid")
	check(m.street.shutter_lock.visible, "the padlock is on")
	check(m.front_shut, "the street behind is put away")
	var outside := 0
	for k in m.enemies: if m.enemies[k].position.z < o.z + m.STORE_FRONT_Z: outside += 1
	check(outside == 0, "no infected left outside (%d)" % outside)
	var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(store + Vector3(0, 1.4, -6.0), store + Vector3(0, 1.4, -12.0), 2))
	check(not through.is_empty() and through.collider == m.street.shutter_body, "nothing walks or shoots through the shutter")

	# --- the chapter board
	await frames(4)
	check(bool(m.flags.get("board", false)), "the chapter leaderboard is up")
	check(session.board_open and game.current_menu == "coop_board", "every peer shows it (%s)" % game.current_menu)
	check(m.ahead_awake and bs.visible, "the backstreets are woken while it shows")
	check(m.stage == 7, "the run waits for READY")
	if shots != "": await shot("chapter_board")
	session._board_ready()
	await frames(4)
	check(m.stage == 8, "everyone ready (the squad AI always are): on to the backstreets (stage %d)" % m.stage)
	check(not session.board_open and not session.local_menu, "the board is gone and the game resumes")
	check(int(m.flags.get("lockup", 0)) == 5, "the lockup is done with")
	if shots != "":
		stand(m.ground(store + Vector3(1.0, 0, -4.0)), PI)
		await frames(10)
		await shot("store_after")
	print("INTERIOR_CHAPTERS %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
