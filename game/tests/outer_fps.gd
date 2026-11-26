extends SceneTree
## 0.63: frame times standing at a few places in Outer Street (the player's own camera, real rendering).
##   godot --path game --script res://tests/outer_fps.gd -- --render-size=1920x1080
var main
var spots := [
	["avenue", Vector3(44.0, 0, 618.0), PI],
	["bus_aisle", Vector3(38.0, .36, 653.0), PI],
	["plaza", Vector3(40.3, 0, 665.0), PI],
	["terrace", Vector3(16.0, 5.0, 676.0), -PI * .5],
	["overpass", Vector3(24.0, 5.6, 690.0), -PI * .5],
	["concourse_lit", Vector3(33.0, -5.2, 686.0), PI],
	["platform", Vector3(29.5, -10.2, 713.0), PI],
	["tunnel", Vector3(34.6, -11.3, 754.0), PI],
	["riverside", Vector3(8.0, 0, 790.0), PI * .5],
]

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
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
	m.debug_jump("outerstreet")
	await frames(120)
	m.flags.outer_shutter = true
	m.flags.outer_power = true
	var o: Vector3 = m.outer_street.world(Vector3.ZERO)
	for sp: Array in spots:
		var player: InteriorPlayer = main.player
		player.reset_motion(o + (sp[1] as Vector3))
		player.rotation.y = float(sp[2])
		s.team[s.local_id()].pos = player.global_position
		await frames(60)
		var times: Array = []
		var last := Time.get_ticks_usec()
		for i in 180:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
		times.sort()
		var med: float = times[times.size() / 2]
		var p95: float = times[int(times.size() * .95)]
		print("OUTER_FPS %-14s median %.2f ms (%.0f fps)  p95 %.2f ms  enemies %d" % [sp[0], med, 1000.0 / med, p95, m.enemies.size()])
	quit(0)
