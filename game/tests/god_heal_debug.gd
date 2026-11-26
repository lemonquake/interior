extends SceneTree
## 0.55: the debug menu's invulnerability, heal and healthkits, pressed through the menu itself.
##   godot --headless --path game --script res://tests/god_heal_debug.gd -- --coop   host + one squad AI
##   godot --headless --path game --script res://tests/god_heal_debug.gd -- --solo   the single-player game
## Prints GOD_HEAL ok|FAIL.
var game
var menu
var failed := []
var checks := 0
## (`--key=coop_harmless`: the old switch, to see what it let through.)
var god_key := "god"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("GOD CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func toggle(key: String, on: bool) -> void:
	var box: CheckBox = menu._controls[key]
	box.button_pressed = on

func press(text: String) -> bool:
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == text and not (b as Button).disabled:
			(b as Button).pressed.emit()
			return true
	print("GOD no button '%s'" % text)
	return false

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	menu = game.get_node("DebugMenu")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--key="): god_key = a.trim_prefix("--key=")
	if "--solo" in OS.get_cmdline_user_args(): await solo()
	else: await coop()
	print("GOD_HEAL %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)

func hp(session, id: int) -> int: return int(session.team[id].hp)

func coop() -> void:
	var session = game.coop
	# (Off the game's own port: a running game may be hosting on it.)
	session.host_port = 25131
	session.host()
	session.add_bot()
	session.start_game()
	await frames(30)
	var m = session.mission
	var o: Vector3 = m.Street.ORIGIN
	var bot := 0
	for id: int in session.team:
		if session.is_bot(id): bot = id
	m.debug_command(1, "jump storeroad")
	await frames(20)
	menu.show_menu()
	await process_frame
	check(menu._controls.has(god_key) , "an Invulnerable switch in the menu")
	toggle(god_key, true)
	await frames(2)
	check(bool(session.harmless) and bool(m.harmless), "it makes the squad invulnerable")
	menu.close()
	m.log_hits = true
	# Infected all round the host and the squad AI, hunting.
	var host: Vector3 = game.player.global_position
	for i in 8:
		var a := TAU * i / 8.0
		var z = m.spawn(m.ground(host + Vector3(cos(a), 0, sin(a)) * 1.6))
		if z != null: z.asleep = false
	await frames(600)
	check(m.blocked_hits > 0, "they did strike: %d blows refused" % m.blocked_hits)
	var before: int = m.blocked_hits
	check(hp(session, 1) == 100 and hp(session, bot) == 100, "infected: no damage (host %d, AI %d)" % [hp(session, 1), hp(session, bot)])
	m.debug_command(1, "kill")
	await frames(10)
	# A grenade at the host's feet (its own, and a teammate's).
	game.grenades._explode(game.player.global_position + Vector3(.4, .1, .4), true)
	game.grenades.remote_boom("x", game.player.global_position + Vector3(-.4, .1, .3))
	session.blast_hurt(85, true)
	await frames(10)
	check(hp(session, 1) == 100 and m.blocked_hits >= before + 3, "grenades: no damage (%d), %d blasts refused" % [hp(session, 1), m.blocked_hits - before])
	# A fall of 14 m.
	var solo_health: float = game.zombies.health
	game.player.reset_motion(game.player.global_position + Vector3(0, 14, 0))
	await frames(150)
	check(hp(session, 1) == 100 and is_equal_approx(game.zombies.health, solo_health), "a long fall: no damage (%d, %.0f)" % [hp(session, 1), game.zombies.health])
	# Heavy-arm: his charge, his slabs, his fists, his pack, a drum going up beside the host.
	m.debug_command(1, "jump heavyarm")
	await frames(30)
	var fight = m.escape.fight
	var heavy_before: int = m.blocked_hits
	var stand := func(at: Vector3) -> void:
		game.player.reset_motion(at)
		session.team[1].pos = at
	stand.call(o + Vector3(44.0, 0, 590.0))
	await frames(60)
	for kind in ["charge", "throw", "roar", "charge"]:
		stand.call(o + Vector3(44.0, 0, 592.0))
		print("GOD ", fight.debug_force(kind))
		for i in 300:
			if i % 20 == 0: stand.call(fight.boss.position + Vector3(0, 0, -1.2) if kind != "throw" else o + Vector3(44.0, 0, 590.0))
			await physics_frame
	check(hp(session, 1) == 100 and hp(session, bot) == 100 and m.blocked_hits > heavy_before, "Heavy-arm and his pack: no damage (host %d, AI %d), %d blows refused" % [hp(session, 1), hp(session, bot), m.blocked_hits - heavy_before])
	var drum_before: int = m.blocked_hits
	stand.call(fight.barrel_at(0) + Vector3(.8, -.44, 0))
	await frames(5)
	fight.explode(0, 1)
	await frames(30)
	check(hp(session, 1) == 100 and m.blocked_hits > drum_before, "a fuel drum beside the host: no damage (%d), refused" % hp(session, 1))
	# Off again: the switch, then the heal.
	menu.show_menu()
	await process_frame
	toggle(god_key, false)
	await frames(2)
	check(not bool(session.harmless) and not bool(m.harmless), "the switch turns it off")
	session.team[1].hp = 37
	session.team[bot].hp = 12
	check(press("Heal the squad"), "a Heal the squad button")
	await frames(4)
	check(hp(session, 1) == 100 and hp(session, bot) == 100, "heal: everyone to 100 (host %d, AI %d)" % [hp(session, 1), hp(session, bot)])
	session.team[1].hp = 0
	await frames(10)
	check(game.player.downed, "down at 0")
	check(press("Heal me"), "a Heal me button (co-op)")
	await frames(10)
	check(hp(session, 1) == 100 and not game.player.downed, "heal me: back up from down, 100 (%d)" % hp(session, 1))
	# Healthkits.
	session.team[1].kits = 0
	session.team[1].kit_sizes = []
	check(press("Healthkit +1 (me)"), "a Healthkit +1 button")
	await frames(2)
	check(int(session.team[1].kits) == 1, "one healthkit (%d)" % int(session.team[1].kits))
	check(press("Healthkits: full (squad)"), "a full healthkits button")
	await frames(2)
	check(int(session.team[1].kits) == m.MAX_KITS and int(session.team[bot].kits) == m.MAX_KITS, "the squad's kits full (%d, %d)" % [int(session.team[1].kits), int(session.team[bot].kits)])
	print("GOD reply: ", m.debug_command(1, "kits 2"))
	check(int(session.team[1].kits) == 2, "kits 2 (%d)" % int(session.team[1].kits))
	session.team[1].hp = 50
	m.start_heal(1, 1)
	await frames(240)
	check(hp(session, 1) > 50 and int(session.team[1].kits) == 1, "a given kit works: patched up (%d, kits %d)" % [hp(session, 1), int(session.team[1].kits)])
	menu.close()

func solo() -> void:
	game._play()
	await frames(30)
	var z = game.zombies
	menu.show_menu()
	await process_frame
	check(menu._controls.has(god_key), "an Invulnerable switch in the menu")
	toggle(god_key, true)
	await frames(2)
	check(bool(z.invulnerable), "it makes the player invulnerable")
	menu.close()
	z.body.bleeding = 1.5
	for i in 6: z.spawn_ahead(1.5 + i * .2, "", TAU * i / 6.0)
	await frames(600)
	game.grenades._explode(game.player.global_position + Vector3(.4, .1, .4), true)
	game.player.reset_motion(game.player.global_position + Vector3(0, 14, 0))
	await frames(150)
	check(is_equal_approx(z.health, 100.0) and not z._down, "infected, a grenade, a fall, bleeding: no damage (%.1f)" % z.health)
	check(z.blocked_hits >= 3 and z.body.bleeding == 0.0, "they did strike: %d hurts refused, no bleeding" % z.blocked_hits)
	menu.show_menu()
	await process_frame
	toggle(god_key, false)
	menu.close()
	await frames(2)
	z.kill_all()
	z.hurt_player(55.0, game.player.global_position + Vector3.RIGHT)
	await frames(2)
	check(z.health < 50.0 and z.body.bleeding > 0.0, "off again: hurt and bleeding (%.1f)" % z.health)
	menu.show_menu()
	await process_frame
	check(press("Heal me"), "a Heal me button")
	await frames(2)
	check(is_equal_approx(z.health, 100.0) and z.body.bleeding == 0.0 and z.body.ceiling == 100.0, "heal me: 100, the bleeding stopped (%.1f)" % z.health)
	menu.close()
