extends SceneTree
## 0.56: PILCST frame rate, rendered (never headless), uncapped. The host and four squad AI jump into the school and
## stand in each floor's corridor; then a class comes down the corridor, the squad shoots them down (ragdolls, blood),
## and the bodies and blood stay. One INTERIOR_SCHOOL_PERF_ROW line a view.
##   godot --path game --script res://tests/school_perf.gd -- [--quality=2] [--quick]
var main
var rows: Array = []
var quick := false

func _initialize() -> void: call_deferred("_run")

func _measure(label: String, seconds: float) -> void:
	for i in 30: await process_frame
	var samples: Array[float] = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	var process := 0.0
	var render_cpu := 0.0
	var render_gpu := 0.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var physics := 0.0
	var n := 0
	var ticks0 := Engine.get_physics_frames()
	while Time.get_ticks_usec() - begin < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	samples.sort()
	var m = main.coop.mission
	var blood = main.zombies.blood if main.get("zombies") != null else null
	var row := {"view": label, "ticks_per_frame": snappedf(float(Engine.get_physics_frames() - ticks0) / maxf(n, 1), .01), "fps_median": snappedf(1000.0 / samples[samples.size() / 2], .1),
		"fps_1pct_low": snappedf(1000.0 / samples[int(samples.size() * .99)], .1), "worst_ms": snappedf(samples[-1], .1),
		"process_ms": snappedf(process / n, .01), "physics_ms": snappedf(physics / n, .01),
		"render_cpu_ms": snappedf(render_cpu / n, .01), "render_gpu_ms": snappedf(render_gpu / n, .01),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"bodies_active": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"pairs": int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		"vram_mb": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"infected": m.enemies.size(), "corpses": m.corpses.size(),
		"blood_nodes": blood.get_child_count() if blood != null else -1}
	rows.append(row)
	print("INTERIOR_SCHOOL_PERF_ROW ", JSON.stringify(row))

func _place(s, at: Vector3, yaw: float) -> void:
	main.player.reset_motion(at)
	main.player.rotation = Vector3(0, yaw, 0)
	s.team[1].pos = at
	s.team[1].yaw = yaw
	var i := 0
	for id in s.bots.bots:
		i += 1
		s.bots.bots[id].body.global_position = at + Vector3(-.9 * i, .1, (i % 2) * .8 - .4)

func _run() -> void:
	var quality := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): quality = int(a.trim_prefix("--quality="))
		if a == "--quick": quick = true
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	main.set_meta("performance_audit", true)
	var s = main.coop
	s.host()
	s.fill_bots()
	s.start_game()
	for i in 20: await process_frame
	main._apply_quality(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var m = s.mission
	m.harmless = true
	s.harmless = true
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	var views := [["lobby", "ground floor lobby", Vector3(28, 0, 516.5), PI],
		["floor2", "2F corridor looking west", Vector3(50, H, 523.5), -PI * .5 + PI],
		["floor3", "3F corridor looking west", Vector3(52, 2 * H, 523.5), PI * .5],
		["floor5", "5F corridor looking west", Vector3(52, 4 * H, 523.5), PI * .5]]
	if quick: views = [views[2]]
	var split := "--split" in OS.get_cmdline_user_args()
	for v: Array in views:
		var r: Array = m.debug_jump(v[0])
		if r.is_empty():
			print("INTERIOR_SCHOOL_PERF jump failed ", v[0], " ", m.debug_note)
			continue
		for i in 30: await physics_frame
		var at: Vector3 = m.ground(o + (v[2] as Vector3))
		# (A jump past the mart's board loads it behind the chapter screen: wait it out.)
		for i in 1200:
			if not s._catching: break
			await process_frame
		if s._chapter_screen != null: s._chapter_screen.visible = false
		for k in m.enemies.keys():
			if is_instance_valid(m.enemies[k]): m.enemies[k].queue_free()
			m.enemies.erase(k)
		for id in s.bots.bots:
			s.bots.bots[id].reserve = 0
			s.bots.bots[id].mag = 0
		_place(s, at, v[3])
		await _measure(String(v[1]) + ", squad of 5, quiet", 4.0)
		if split:
			s.set_physics_process(false)
			await _measure("  same, host AI and figures paused", 3.0)
			s.set_physics_process(true)
			for k in m.enemies.keys():
				if is_instance_valid(m.enemies[k]): m.enemies[k].queue_free()
				m.enemies.erase(k)
			for i in 10: await physics_frame
			s.set_physics_process(false)
			await _measure("  same, no infected at all, AI paused", 3.0)
			s.set_physics_process(true)
			for b in s.bots.bots.values(): b.body.visible = false
			await _measure("  same, no infected, squad running", 3.0)
	# The fight, on the fifth floor (or the quick view's floor).
	var fight_at: Vector3 = main.player.global_position
	var fwd: Vector3 = -main.player.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	for i in 20:
		var p: Vector3 = fight_at + fwd * (10.0 + i * .9) + Vector3(fwd.z, 0, -fwd.x) * randf_range(-1.0, 1.0)
		m.spawn(m.ground(p), false, true)
	await _measure("20 students coming, squad holding fire", 5.0)
	for id in s.bots.bots:
		s.bots.bots[id].reserve = 300
		s.bots.bots[id].mag = 17
	await _measure("squad shooting them down", 6.0)
	await _measure("after: bodies and blood", 4.0)
	if split:
		s.set_physics_process(false)
		await _measure("  after, AI paused", 3.0)
		for d in get_nodes_in_group("blood_decals"): d.visible = false
		await _measure("  after, AI paused, blood decals hidden", 3.0)
		for c in m.corpses: if is_instance_valid(c): c.visible = false
		await _measure("  after, AI paused, blood hidden, bodies hidden (still simulated)", 3.0)
		for k in m.enemies.keys():
			if is_instance_valid(m.enemies[k]) and not m.enemies[k].dead: m.enemies[k].visible = false
		await _measure("  after, AI paused, blood, bodies and infected hidden", 3.0)
		for c in m.corpses: if is_instance_valid(c): c.queue_free()
		m.corpses.clear()
		await _measure("  after, AI paused, blood hidden, bodies removed", 3.0)
		for d in get_nodes_in_group("blood_decals"): d.visible = true
		await _measure("  after, AI paused, bodies removed, blood shown", 3.0)
		s.set_physics_process(true)
	for wave in 3:
		for i in 14:
			var p: Vector3 = fight_at + fwd * (9.0 + i * .9) + Vector3(fwd.z, 0, -fwd.x) * randf_range(-1.0, 1.0)
			m.spawn(m.ground(p), false, true)
		for i in 300: await process_frame
	await _measure("after 4 waves: %d bodies, blood everywhere" % m.corpses.size(), 5.0)
	print("INTERIOR_SCHOOL_PERF ", JSON.stringify(rows))
	s.end_session()
	quit()
