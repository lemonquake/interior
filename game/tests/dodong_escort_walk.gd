extends SceneTree
## 0.66: the escort from the courtyard gate. Dodong waits outside the gate; the squad (host + 2 squad AI) speak to
## him and keep close (the host is stood 3 m behind him every half second, the squad AI follow on their own) until he
## is home. Fails if he stalls for 6 s with someone close, if he leaves the ground, or if the walk takes too long.
##   godot --headless --path game --script res://tests/dodong_escort_walk.gd [-- --fight]
## `--fight`: the infected may hurt (the squad AI defend him); otherwise nobody can be hurt.
## Prints INTERIOR_DODONG_WALK ok|FAIL.
var game
var session
var m
var failed := []
var args := OS.get_cmdline_user_args()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failed.append(label)
	print("WALK CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.add_bot()
	session.start_game()
	await frames(30)
	m = session.mission
	var fight := "--fight" in args
	session.harmless = not fight
	m.harmless = not fight
	check(m.stage == 0, "stage 0 at the start")
	check(m.guide.position.distance_to(m.GATE_SPOT) < .3, "Dodong outside the courtyard gate (%s)" % m.guide.position)
	check(m.objective().begins_with("Dodong is waiting"), "objective names the gate")
	# Out of the house to the gate.
	game.player.reset_motion(m.guide.position + Vector3(1.5, .05, 0))
	session.team[1].pos = m.guide.position + Vector3(1.5, 0, 0)
	await frames(10)
	session.team[1].pos = m.guide.position + Vector3(1.5, 0, 0)
	check(m.candidate(1) == "talk", "E speaks to Dodong at the gate (%s)" % m.candidate(1))
	m.interact(1, "talk")
	await frames(5)
	check(m.stage == 1, "the escort begins")
	var t0 := Time.get_ticks_msec()
	var last: Vector3 = m.guide.position
	var still := 0.0
	var log_t := 0.0
	var worst_air := 0.0
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	while m.stage == 1 and Time.get_ticks_msec() - t0 < 360000:
		await frames(30)
		# (The test's host never shoots back: kept on their feet, or Dodong waits for them, as he should.)
		if fight: session.team[1].hp = m.MAX_HP
		var g: Vector3 = m.guide.position
		var back := Vector3(-sin(m.guide.rotation.y), 0, -cos(m.guide.rotation.y))
		var spot: Vector3 = g - back * 3.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.5, spot + Vector3.DOWN * 3.0, 2))
		var stand: Vector3 = (hit.position if not hit.is_empty() else g) + Vector3.UP * .05
		game.player.reset_motion(stand)
		session.team[1].pos = stand
		if m.waypoint < m.warren_at:
			var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3.UP * .8, g + Vector3.DOWN * 2.0, 2))
			if not under.is_empty(): worst_air = maxf(worst_air, absf(g.y - under.position.y))
		if g.distance_to(last) < .05: still += .5
		else: still = 0.0
		last = g
		if still >= 6.0:
			check(false, "Dodong stalled at %s (waypoint %d)" % [g, m.waypoint])
			break
		log_t += .5
		if log_t >= 10.0:
			log_t = 0.0
			print("WALK t=%.0fs waypoint %d/%d at %s hp %d infected %d" % [(Time.get_ticks_msec() - t0) / 1000.0, m.waypoint, m.route.size(), g.snapped(Vector3.ONE * .1), m.guide_hp, m.enemies.size()])
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("WALK done in %.0f s, stage %d, guide hp %d, worst gap to the ground %.2f m" % [secs, m.stage, m.guide_hp, worst_air])
	check(m.stage == 2, "Dodong home (stage %d)" % m.stage)
	check(worst_air < .25, "feet on the ground outdoors (%.2f m)" % worst_air)
	check(m.guide.position.distance_to(m.route[m.route.size() - 1]) < .5, "at his door")
	print("INTERIOR_DODONG_WALK ", "ok" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)
