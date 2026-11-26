extends SceneTree
## 0.49: the mart siege always ends, and the office opens with Jonna. Three ways it used to hang for good:
## A. the back group still hammering at a shut (braced) back door, outside where nobody can reach them;
## B. a wave whose spawns keep failing (a player standing in the front spawn ground);
## C. a straggler that never comes (asleep up the street).
##   godot --headless --path game --script res://tests/coop_siege_end.gd   (prints INTERIOR_SIEGE_END ok|FAIL)
var game
var session
var m
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("SIEGE CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

## Physics frames until `cond` holds (or `limit` frames).
func until(cond: Callable, limit: int) -> bool:
	for i in limit:
		if cond.call(): return true
		await physics_frame
	return cond.call()

func clear() -> void:
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)

func siege() -> void:
	m.stage = 5
	m.stage_time = 0.0
	m.flags.erase("backdoor")
	m.street.back_door_hp = 100.0
	m._mop_wait = 0.0

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
	clear()
	var o: Vector3 = m.Street.ORIGIN
	var store: Vector3 = o + m.Street.STORE
	var player: InteriorPlayer = game.player
	player.reset_motion(m.ground(store + Vector3(0, 0, -2.0)))
	session.team[1].pos = player.global_position

	# --- A: the back group at a shut, braced door
	siege()
	m.wave_left = 0
	m.back_left = 0
	var door: Vector3 = o + m.Street.BACK_DOOR + Vector3(0, 0, .9)
	var back: Array = []
	for i in 3:
		var z = m.spawn(m.ground(door + Vector3(-.6 + i * .6, 0, .4 + i * .3)))
		z.back = true
		back.append(z)
	# A table braced against it inside, as players do.
	var t = m.street.tables[0]
	t.global_position = o + m.Street.BACK_DOOR + Vector3(0, .4, -.9)
	var broke := await until(func(): return bool(m.flags.get("backdoor", false)), 60 * 12)
	check(broke, "A: with nobody left inside, the back group breaks the door in (hp %.0f)" % m.street.back_door_hp)
	for k in m.enemies.keys(): m.damage(1, k, "head", m.enemies[k].global_position + Vector3.UP * 1.5, Vector3.FORWARD, 999.0, 60.0)
	var six := await until(func(): return m.stage == 6, 60 * 4)
	check(six, "A: and once they are down the siege is over (stage %d)" % m.stage)
	var office := await until(func(): return bool(m.flags.get("office", false)) and m.jonna.visible, 60 * 8)
	check(office, "A: Jonna opens the office and calls them in")

	# --- B: spawns that keep failing
	clear()
	siege()
	m.flags.office = false
	m.wave_left = 3
	m.back_left = 0
	m.next_spawn = 0.0
	# A player standing in the middle of the front spawn ground: most spots are within 4 m of them and refused.
	player.reset_motion(m.ground(o + Vector3(0, 0, 43.0)))
	session.team[1].pos = player.global_position
	var fails_seen := [0]   # (an array: a lambda captures plain locals by value)
	var stuck := await until(func():
		# keep the infected that do appear out of it: put them down at once
		for k in m.enemies.keys(): m.damage(1, k, "head", m.enemies[k].global_position + Vector3.UP * 1.5, Vector3.FORWARD, 999.0, 60.0)
		fails_seen[0] = maxi(fails_seen[0], m._spawn_fails)
		return m.wave_left == 0, 60 * 40)
	print("SIEGE B most failures in a row: %d" % fails_seen[0])
	check(stuck, "B: the wave counts down even when spawns fail (left %d)" % m.wave_left)
	var b_end := await until(func(): return m.stage == 6, 60 * 25)
	check(b_end, "B: and the siege ends (stage %d)" % m.stage)

	# --- C: a straggler that never comes
	clear()
	siege()
	m.wave_left = 0
	m.back_left = 0
	var far = m.spawn(m.ground(o + Vector3(0, 0, 8.0)), true)
	check(far != null, "C: a sleeper up the street")
	var c_end := await until(func(): return m.stage == 6, 60 * 22)
	check(c_end, "C: after 15 s out of the mart it is let go and the siege ends (stage %d)" % m.stage)
	print("INTERIOR_SIEGE_END %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
