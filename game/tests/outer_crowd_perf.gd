extends SceneTree
## 0.67: Outer Street's crowd frames (0.66 left ~40 ms frames at the plaza and the boutique on PC). At each place: the
## debug jump, the chapter caught up, then the squad walks into the place's zones the way play does (their infected
## arrive through mission `later`), everything there woken and hunting the squad (nobody hurt), and `--seconds` of
## frames measured with the frame anatomy (tests/frame_anatomy.gd): median, 1% low, worst, the long frames' split.
##   godot --path game --script res://tests/outer_crowd_perf.gd -- --render-size=1920x1080 [--quality=2] [--only=a,b]
## Prints INTERIOR_CROWD_ROW {json} per place.
var main
var s
var m
var anatomy
var seconds := 6.0
## [label, jump, where the squad stands (street-local), extra infected woken round it]
const PLACES := [
	["plaza", "outerplaza", Vector3(44.0, 0, 676.0), 8],
	["concourse", "outerstation", Vector3(33.0, -5.2, 690.0), 6],
	["platform", "outerplatform", Vector3(29.5, -10.2, 716.0), 6],
	["river", "outerriver", Vector3(10.0, 0, 792.0), 8],
	["mart", "outermart", Vector3(53.2, .15, 767.0), 8],
	["boutique", "outermart", Vector3(72.0, .15, 778.0), 8],
	["bridge", "outerbridge", Vector3(94.0, 2.0, 840.0), 10],
]

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _settled() -> void:
	await frames(10)
	for i in 3600:
		var cs = s.get("_chapter_screen")
		if s.get("_catching") != true and (cs == null or not cs.visible) and not bool(s.get("board_open")): break
		await process_frame
	await frames(45)

func _run() -> void:
	var quality := 2
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): quality = int(a.trim_prefix("--quality="))
		if a.begins_with("--only="): only = Array(a.trim_prefix("--only=").split(","))
		if a.begins_with("--seconds="): seconds = float(a.trim_prefix("--seconds="))
	anatomy = (load("res://tests/frame_anatomy.gd") as GDScript).new()
	root.add_child(anatomy)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40: await process_frame
	main.set_meta("performance_audit", true)
	s = main.coop
	s.host()
	s.fill_bots()
	s.start_game()
	for i in 20: await process_frame
	main._apply_quality(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	m = s.mission
	m.harmless = true
	s.harmless = true
	for p: Array in PLACES:
		if not only.is_empty() and not str(p[0]) in only: continue
		print("CROWD > ", p[0], " ", m.debug_command(1, "jump " + str(p[1])))
		await _settled()
		var os = m.outer_street
		var at: Vector3 = os.world(p[2] as Vector3)
		s.debug_move_squad(m.ground(at + Vector3.UP * .5), PI)
		await frames(30)
		# The place's own, plus a few more, woken and coming.
		for i in int(p[3]):
			var a := TAU * float(i) / float(p[3])
			var sp: Vector3 = m.ground(at + Vector3(cos(a) * 9.0, .5, sin(a) * 9.0))
			if not sp.is_finite(): continue
			var z = m.spawn(sp, false)
			if z != null: z.asleep = false
		for i in 30: await process_frame
		for z in m.enemies.values():
			if is_instance_valid(z) and z.position.distance_to(at) < 30.0: z.asleep = false
		var samples: Array[float] = []
		anatomy.begin()
		var begin := Time.get_ticks_usec()
		var prev := begin
		var draws := 0
		while Time.get_ticks_usec() - begin < seconds * 1000000.0:
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now - prev) / 1000.0)
			prev = now
			draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var parts: Dictionary = anatomy.take()
		samples.sort()
		var awake := 0
		for z in m.enemies.values():
			if is_instance_valid(z) and not z.asleep and not z.dead: awake += 1
		var row := {"place": p[0], "fps": snappedf(1000.0 / samples[samples.size() / 2], .1), "low1": snappedf(1000.0 / samples[int(samples.size() * .99)], .1),
			"worst_ms": snappedf(samples[-1], .1), "over25": samples.filter(func(x: float) -> bool: return x > 25.0).size(), "draws": draws, "awake": awake}
		row.merge(parts)
		print("INTERIOR_CROWD_ROW ", JSON.stringify(row))
		for k in m.enemies.keys():
			if m.enemies[k].has_meta("boss"): continue
			m.enemies[k].queue_free()
			m.enemies.erase(k)
		await frames(20)
	print("INTERIOR_CROWD_DONE")
	s.end_session()
	quit()
