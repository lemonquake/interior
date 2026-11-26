extends SceneTree
## 0.30: frame rate while playing, rendered (never headless, never --fixed-fps), uncapped, adaptive resolution off:
## the street empty, with a dozen zombies coming, while they are being shot down, and with the bodies and blood left.
##   godot --path game --script res://tests/play_perf.gd -- --render-size=1920x1080 [--quality=2] [--count=12]

var main: Node
var rows: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _measure(label: String, seconds: float) -> void:
	for i in 30:
		await process_frame
	var samples: Array[float] = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	var draws := 0.0
	var spikes: Array = []
	while Time.get_ticks_usec() - begin < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		if (now - previous) > 9000 and spikes.size() < 60:
			spikes.append([int((now - begin) / 1000.0), snappedf((now - previous) / 1000.0, .1), Engine.get_physics_frames()])
		previous = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	samples.sort()
	var row := {"view": label, "fps_median": snappedf(1000.0 / samples[samples.size() / 2], .1),
		"fps_1pct_low": snappedf(1000.0 / samples[int(samples.size() * .99)], .1), "worst_ms": snappedf(samples[-1], .1),
		"draw_calls": int(draws / samples.size()), "frames": samples.size(),
		"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, .01),
		"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, .01)}
	rows.append(row)
	print("INTERIOR_PLAY_PERF_ROW ", JSON.stringify(row))
	print("INTERIOR_PLAY_PERF_SPIKES ", label, " ", JSON.stringify(spikes))

func _run() -> void:
	var quality := 2
	var count := 12
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--count="):
			count = int(argument.trim_prefix("--count="))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40:
		await process_frame
	main.set_meta("performance_audit", true)
	main._play()
	main._apply_quality(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	var player: InteriorPlayer = main.player
	var eye := Vector3(20.2, -1.32, 6.0)
	player.global_position = eye - Vector3.UP * 1.58
	player.camera.look_at(Vector3(20.5, -1.65, 31.0))
	player.reset_physics_interpolation()
	var zombies: InteriorZombies = main.zombies
	zombies.invulnerable = true
	await _measure("street, empty", 4.0)
	if "--empty-only" in OS.get_cmdline_user_args():
		quit()
		return
	var made := 0
	for i in count:
		var at := zombies.ground(Vector3(20.3 + (i % 4 - 1.5) * 1.3, -1.3, 13.0 + (i / 4) * 2.6))
		if at.is_finite() and zombies.spawn(at) != null:
			made += 1
	await _measure("street, %d zombies coming" % made, 5.0)
	# Shoot them down with the rifle's own rounds: hit reactions, ragdolls, blood in the air and on the ground.
	var story: Node = main.story
	if story != null and story.get("gun") != null:
		var gun: InteriorGun = story.gun
		if story.has_method("debug_give_gun"):
			story.debug_give_gun()
	var targets := zombies.alive()
	var begin := Time.get_ticks_msec()
	var index := 0
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - begin < 5000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		if samples.size() % 6 == 0 and not targets.is_empty():
			var zombie: InteriorZombie = targets[index % targets.size()]
			index += 1
			if is_instance_valid(zombie):
				var bones: Array = zombie._bodies.keys()
				var body := zombie._bodies.get(bones[index % bones.size()]) as PhysicalBone3D
				if body != null:
					var way := (body.global_position - eye).normalized()
					var p: Dictionary = InteriorGun.PROFILES["rifle"]
					zombie.shot(body, body.global_position - way * .1, way, float(p.damage), float(p.knock), "rifle", float(p.damage) * float(p.get("sever", .5)))
	samples.sort()
	if not samples.is_empty():
		var row := {"view": "street, shooting them", "fps_median": snappedf(1000.0 / samples[samples.size() / 2], .1),
			"fps_1pct_low": snappedf(1000.0 / samples[int(samples.size() * .99)], .1), "worst_ms": snappedf(samples[-1], .1), "frames": samples.size()}
		rows.append(row)
		print("INTERIOR_PLAY_PERF_ROW ", JSON.stringify(row))
	zombies.kill_all()
	await _measure("street, bodies and blood", 4.0)
	print("INTERIOR_PLAY_PERF ", JSON.stringify({"quality": quality, "window": str(root.size), "rows": rows}))
	quit()
