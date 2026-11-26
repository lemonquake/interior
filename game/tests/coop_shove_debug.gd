extends SceneTree
## 0.49: the T shove pushes like a person (one body, a step back, a short stagger), and Q W E R T Y opens the debug
## menu in a co-op game (T is the co-op shove and used to be swallowed before the menu saw it).
##   godot --headless --path game --script res://tests/coop_shove_debug.gd   (prints INTERIOR_SHOVE_DEBUG ok|FAIL)
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("SHOVE CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	await process_frame
	await process_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.start_game()
	await frames(20)
	var m = session.mission
	session.harmless = true
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	await frames(2)
	var o: Vector3 = m.Street.ORIGIN
	var at: Vector3 = m.ground(o + Vector3(0, 0, 20.5))
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = PI    # facing +Z
	session.team[1].pos = at
	session.team[1].yaw = PI

	# --- the shove
	var front = m.spawn(m.ground(at + Vector3(0, 0, .95)))
	var side = m.spawn(m.ground(at + Vector3(.75, 0, .9)))
	var behind = m.spawn(m.ground(at + Vector3(0, 0, 2.8)))
	# Asleep: they stand where they are until something wakes them (the shove wakes the one it meets).
	for z in [front, side, behind]:
		z.asleep = true
	await frames(3)
	var f0: Vector3 = front.position
	var s0: Vector3 = side.position
	var b0: Vector3 = behind.position
	m.shove(1)
	var front_stun: float = front.stun
	var side_stun: float = side.stun
	var behind_stun: float = behind.stun
	var max_front := 0.0
	for i in 45:
		await physics_frame
		max_front = maxf(max_front, Vector2(front.position.x - f0.x, front.position.z - f0.z).length())
	print("SHOVE front moved %.2f m (stun %.2f %s), side moved %.2f (stun %.2f), behind moved %.2f" % [max_front, front_stun, front.stun_clip,
		Vector2(side.position.x - s0.x, side.position.z - s0.z).length(), side_stun, Vector2(behind.position.x - b0.x, behind.position.z - b0.z).length()])
	check(max_front > .12 and max_front < .7, "the one in front goes back a step, not across the street (%.2f m)" % max_front)
	check(front_stun > 0.0 and front_stun <= .7, "a short stagger (%.2f s)" % front_stun)
	check(front.stun_clip != "knockdown", "not knocked flat by a plain shove")
	check(side_stun <= .05, "only one body is pushed (the one beside: stun %.2f)" % side_stun)
	# (It may wake at the noise and walk: what counts is that the shove did not stagger it.)
	check(behind_stun <= .05, "the one two metres back is not pushed (stun %.2f)" % behind_stun)

	# --- Q W E R T Y in a co-op game
	var menu = game.get_node("DebugMenu")
	check(not menu.open, "the debug menu starts shut")
	for code: Key in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]:
		await key(code, true)
		await key(code, false)
	await frames(2)
	check(menu.open, "Q W E R T Y opens the debug menu in a co-op game")
	check(not player.playing, "the player stands still while it is open")
	var before := int(session.team[1].kits)
	menu._coop("kit")
	check(int(session.team[1].kits) == mini(before + 1, m.MAX_KITS), "a co-op debug action works for the host")
	await key(KEY_ESCAPE, true)
	await key(KEY_ESCAPE, false)
	await frames(2)
	check(not menu.open, "Esc shuts it")
	await frames(2)
	check(player.playing, "and the game goes on")
	print("INTERIOR_SHOVE_DEBUG %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
