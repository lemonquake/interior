extends SceneTree
## 0.63 (owner: "as soon as the players trigger facing Heavy-arm, clean up all the old blood and zombie bodies, etc.
## Then only load the Outer Streets map as soon as the Leaderboard UI shows after defeating Heavy-arm"):
##  1. dead infected (with their blood) in the school and far across the field; Heavy-arm spots the squad: the old
##     bodies and blood are gone, what lies round the squad stays; Outer Street is not built;
##  2. Heavy-arm down, out through the rear gate: the chapter board is up and only then is Outer Street built.
##   godot --headless --path game --script res://tests/heavy_clean_board.gd
var game
var session
var m
var o: Vector3
var checks := 0
var failed := []
var built_at_board := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("HEAVY_CLEAN CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func kill_at(at: Vector3) -> void:
	var z = m.spawn(m.ground(o + at), false)
	if z == null: return
	await frames(2)
	var key := -1
	for k in m.enemies.keys():
		if m.enemies[k] == z: key = k
	for i in 6:
		if m.enemies.has(key): m.damage(session.local_id(), key, "spine", z.position + Vector3.UP * 1.2, Vector3.FORWARD, 60.0, 1.0)
		await frames(2)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.start_game()
	await frames(20)
	m = session.mission
	session.harmless = true
	o = m.Street.ORIGIN
	m.debug_jump("field")
	await frames(60)
	for k in m.enemies.keys():
		if is_instance_valid(m.enemies[k]) and not m.enemies[k].has_meta("boss"): m.enemies[k].queue_free()
		m.enemies.erase(k)
	await frames(4)
	# The night so far: some dead far off (in the school's ground floor, the field's far side), some round the squad.
	var player: InteriorPlayer = game.player
	player.reset_motion(o + Vector3(40.0, .05, 566.0))
	session.team[session.local_id()].pos = player.global_position
	for at: Vector3 in [Vector3(10.0, 0, 518.0), Vector3(20.0, 0, 545.0), Vector3(5.0, 0, 555.0), Vector3(41.0, 0, 568.0), Vector3(38.0, 0, 564.0)]:
		await kill_at(at)
	await frames(30)
	var bodies_before: int = m.corpses.size()
	var blood = session.blood()
	var blood_before: int = blood.count() + blood.spots() if blood != null else 0
	check(bodies_before >= 4, "dead lying about before (%d bodies, %d blood)" % [bodies_before, blood_before])
	check(m.outer_street == null, "Outer Street not built in the field")
	# Facing him: the squad walks up the field until he spots them.
	for i in 400:
		if bool(m.flags.get("heavy_clean", false)): break
		player.reset_motion(o + Vector3(40.0, .05, 572.0 + i * .035))
		session.team[session.local_id()].pos = player.global_position
		await physics_frame
	await frames(10)
	check(bool(m.flags.get("heavy_clean", false)), "Heavy-arm spotted the squad (cleanup flagged)")
	var near := 0
	var far := 0
	for c in m.corpses:
		if not is_instance_valid(c): continue
		if c.where().distance_to(player.global_position) < m.CLEAN_KEEP: near += 1
		else: far += 1
	check(far == 0, "the old bodies are gone (%d far left, %d near kept, %d before)" % [far, near, bodies_before])
	var blood_after: int = blood.count() + blood.spots() if blood != null else 0
	check(blood == null or blood_after < blood_before, "the old blood is gone (%d -> %d)" % [blood_before, blood_after])
	check(m.outer_street == null, "Outer Street still not built while Heavy-arm is fought")
	# Heavy-arm down, the key, the gate, out: the board.
	m.debug_jump("pilcstout")
	for i in 600:
		if m.outer_street != null:
			built_at_board = bool(m.flags.get("board", false)) or session.board_open
			break
		await process_frame
	check(m.outer_street != null and built_at_board, "Outer Street built only once the chapter board is up (built %s, board %s)" % [str(m.outer_street != null), str(built_at_board)])
	print("INTERIOR_HEAVY_CLEAN %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
