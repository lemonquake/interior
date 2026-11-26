extends SceneTree
## 0.66: the whole squad run's frame rate, place by place, as play leaves the world: one game, the host and four
## squad AI, nobody hurt; chapter 1 by teleports at stage 0 (nothing behind put away yet), then forward by the debug
## jumps (each settles everything behind it the way play does, chapter loads included). Rendered, uncapped.
##   godot --path game --script res://tests/coop_perf_sweep.gd -- --render-size=1920x1080 [--quality=2] [--only=a,b]
##   [--mobile-test --render-size=1600x720 --quality=0 with --rendering-method gl_compatibility: the phone path]
## Prints INTERIOR_SWEEP_ROW {json} per place and INTERIOR_SWEEP_DONE.
var main
var s
var m
var rows: Array = []
var only: Array = []
var anatomy
const GO := ["courtyard", "bridge", "farbank", "warrengate", "plankbridge", "dodonghouse"]
const JUMP := ["ramp", "gate", "storeroad", "mart", "siege", "office", "jonna", "backstreets", "arcade", "brickalley",
	"school", "lobby", "floor2", "floor3", "floor4", "floor5", "horde", "sneak", "field", "heavyarm",
	"outerstreet", "outerbus", "outerplaza", "outerterrace", "outerstation", "outerplatform", "outertunnel", "outerriver",
	"outerpizza", "outermart", "outerboutique", "outerbridge"]

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _settled() -> void:
	# (0.67: a jump's catch-up starts on the session's next frame: wait for it to begin before waiting for its end.)
	await frames(10)
	for i in 1800:
		var cs = s.get("_chapter_screen")
		if s.get("_catching") != true and (cs == null or not cs.visible): break
		await process_frame
	await frames(45)

func _measure(label: String, seconds := 3.0) -> void:
	var samples: Array[float] = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	var process := 0.0
	var physics := 0.0
	var n := 0
	var draws := 0
	var objects := 0
	if anatomy != null: anatomy.begin()
	while Time.get_ticks_usec() - begin < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects = maxi(objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		n += 1
	var parts: Dictionary = anatomy.take() if anatomy != null else {}
	samples.sort()
	var p: Vector3 = main.player.global_position - m.Street.ORIGIN
	var row := {"place": label, "stage": m.stage, "fps": snappedf(1000.0 / samples[samples.size() / 2], .1),
		"low1": snappedf(1000.0 / samples[int(samples.size() * .99)], .1), "worst_ms": snappedf(samples[-1], .1),
		"process_ms": snappedf(process / n, .01), "physics_ms": snappedf(physics / n, .01), "draws": draws, "objects": objects,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"physics_bodies": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"infected": m.enemies.size(), "dead": m.corpses.size() + m.victims.size(), "at": str(p.snapped(Vector3.ONE * .1))}
	row.merge(parts)
	rows.append(row)
	print("INTERIOR_SWEEP_ROW ", JSON.stringify(row))

func _quiet() -> void:
	for k in m.enemies.keys():
		if m.enemies[k].has_meta("boss"): continue
		if m.enemies[k].asleep: continue
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	m.wave_left = 0
	m.next_spawn = 9999.0

func _run() -> void:
	var quality := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): quality = int(a.trim_prefix("--quality="))
		if a.begins_with("--only="): only = Array(a.trim_prefix("--only=").split(","))
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
	await frames(60)
	for place in GO:
		if not only.is_empty() and not place in only: continue
		print("SWEEP > go ", place, " -> ", m.debug_command(1, "go " + place))
		m.next_spawn = 9999.0
		await frames(60)
		_quiet()
		await _measure("go " + place)
	for place in JUMP:
		if not only.is_empty() and not place in only: continue
		print("SWEEP > jump ", place, " -> ", m.debug_command(1, "jump " + place))
		await _settled()
		_quiet()
		await frames(20)
		await _measure("jump " + place)
	print("INTERIOR_SWEEP_DONE ", JSON.stringify(rows))
	s.end_session()
	quit()
