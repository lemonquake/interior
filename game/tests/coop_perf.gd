extends SceneTree
## 0.40: co-op frame rate, rendered (never headless), uncapped: the host with four squad AI on the store run, then
## with a full crowd coming, then while the squad shoots them down (ragdolls and blood).
##   godot --path game --script res://tests/coop_perf.gd -- --render-size=1920x1080 [--quality=2]
var main
var rows: Array = []
var anatomy

func _initialize() -> void: call_deferred("_run")

func _measure(label: String, seconds: float) -> void:
	for i in 30: await process_frame
	var samples: Array[float] = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	var process := 0.0
	var render_cpu := 0.0
	var render_gpu := 0.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var physics := 0.0
	var n := 0
	if anatomy != null: anatomy.begin()
	while Time.get_ticks_usec()-begin<seconds*1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
		process += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu()
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		n += 1
	var parts: Dictionary = anatomy.take() if anatomy != null else {}
	samples.sort()
	var row := {"view":label,"fps_median":snappedf(1000.0/samples[samples.size()/2],.1),
		"fps_1pct_low":snappedf(1000.0/samples[int(samples.size()*.99)],.1),"worst_ms":snappedf(samples[-1],.1),
		"process_ms":snappedf(process/n,.01),"render_cpu_ms":snappedf(render_cpu/n,.01),"render_gpu_ms":snappedf(render_gpu/n,.01),
		"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),"physics_ms":snappedf(physics/n,.01),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"infected":main.coop.mission.enemies.size(),"bodies":main.coop.mission.corpses.size()}
	row.merge(parts)
	rows.append(row)
	print("INTERIOR_COOP_PERF_ROW ",JSON.stringify(row))

func _run() -> void:
	var quality := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): quality = int(a.trim_prefix("--quality="))
	anatomy = (load("res://tests/frame_anatomy.gd") as GDScript).new()
	root.add_child(anatomy)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	main.set_meta("performance_audit",true)
	var s = main.coop
	s.host()
	s.fill_bots()
	s.start_game()
	for i in 20: await process_frame
	main._apply_quality(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var m = s.mission
	for i in 4: m.debug_skip()
	m.harmless = true
	m.wave_left = 0
	var stand: Vector3 = m.ground(m.Street.ORIGIN+Vector3(0,0,20))
	main.player.reset_motion(stand)
	main.player.rotation = Vector3(0,PI,0)
	s.team[1].pos = stand
	for id in s.bots.bots: s.bots.bots[id].body.global_position = stand+Vector3(randf_range(-1.5,1.5),.1,-1.5)
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	for id in s.bots.bots: s.bots.bots[id].reserve = 0
	for id in s.bots.bots: s.bots.bots[id].mag = 0
	await _measure("store run, squad of 5, no infected",4.0)
	for i in 20: m.spawn(m.ground(stand+Vector3(randf_range(-3,3),0,14+i*.8)))
	await _measure("20 infected coming, squad holding fire",5.0)
	for id in s.bots.bots:
		s.bots.bots[id].reserve = 300
		s.bots.bots[id].mag = 17
	await _measure("squad shooting them down",6.0)
	await _measure("after: bodies and blood",3.0)
	print("INTERIOR_COOP_PERF ",JSON.stringify(rows))
	s.end_session()
	quit()
