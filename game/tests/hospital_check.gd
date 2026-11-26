extends SceneTree
## 0.68: the hospital chapter end to end on a host with one squad AI (scripts/coop/hospital.gd, lucky.gd):
##   godot --headless --path game --script res://tests/hospital_check.gd
## The board after the bridge, the people outside, every seal and what it puts away, Doctor Berido found and
## following, the duct, the bookcase and the hidden stair walked by the real player, the five things, the door, the
## laboratory's people, the story, Doctor Lucky (his leap and his wall), the flare. Prints INTERIOR_HOSPITAL ok|FAIL.
var game
var session
var m
var hp
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("HOSPITAL CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func at(l: Vector3) -> Vector3: return hp.world(hp.HO + l)
func here() -> Vector3: return hp.local(game.player.global_position) - hp.HO

func tp(l: Vector3, yaw := PI) -> void:
	session.debug_move_one(1, at(l), yaw)
	await frames(12)

func walk(yaw: float, seconds: float) -> void:
	game.player.rotation.y = yaw
	Input.action_press("forward")
	await frames(int(seconds * 60))
	Input.action_release("forward")
	await frames(6)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(30)
	m = session.mission
	session.harmless = true
	# Across the bridge: the board, the hospital loading behind it.
	print("HOSPITAL > ", m.debug_command(1, "jump outerbridge"))
	await frames(40)
	for i in 1500:
		if session._chapter_screen == null or not session._chapter_screen.visible: break
		await frames(1)
	m._win_outer_street()
	await frames(10)
	check(bool(m.flags.get("board", false)) and bool(m.flags.get("bridge_out", false)) and m.stage == 17, "across the bridge: the board up, stage %d" % m.stage)
	var t0 := Time.get_ticks_msec()
	for i in 2400:
		if session._load_done: break
		await frames(1)
	check(session._load_done and m.hospital != null, "the board loaded the hospital (%d ms)" % (Time.get_ticks_msec() - t0))
	await frames(30)
	check(m.escape == null or m.escape.people.is_empty(), "Ma'am Teves and her students are gone")
	session._board_ready()
	await frames(20)
	hp = m.hospital
	check(m.stage == m.HOSPITAL, "READY: into the hospital (stage %d)" % m.stage)
	check(here().distance_to(hp.SPAWN) < 4.0, "outside the hospital (%s)" % str(here().snapped(Vector3.ONE * .1)))
	check(hp.people.size() == 6 and hp.doc != null, "the six outside and Doctor Berido are there")
	check(m.objective().begins_with("Speak to the doctors"), "objective: %s" % m.objective())
	# The talk outside.
	await tp(hp.NPC_AT[0] + Vector3(1.4, 0, -.6))
	check(m.candidate(1) == "hosp_talk", "E by the ambulance: %s" % m.candidate(1))
	m.interact(1, "hosp_talk")
	await frames(20)
	check(bool(m.flags.get("hosp_talked", false)) and m.text_line.begins_with("Doctor"), "the doctors talk: %s" % m.text_line.left(40))
	for i in 8:
		m.interact(1, "hosp_listen")
		await frames(8)
	# Inside: the shutters, the street put away.
	await tp(Vector3(0, 0, 5.0))
	await frames(30)
	check(bool(m.flags.get("hosp_inside", false)) and bool(m.flags.get("hosp_shut", false)), "inside: the shutters coming down")
	await frames(240)
	check(hp.R_OUT in hp.gone and hp.people.is_empty(), "the street put away behind the shutters")
	check(not hp.shutter_shape.disabled, "the shutters are shut")
	# Every way up but one is blocked: the lobby's stair, the west corridor, the way north.
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	for pair: Array in [[Vector3(-8.2, 1.2, 4.0), Vector3(-8.2, 1.2, 11.0), "the grand stair's gap"], [Vector3(-8.0, 1.0, 8.0), Vector3(-13.0, 1.0, 8.0), "the west corridor"], [Vector3(0, 1.0, 14.0), Vector3(0, 1.0, 21.0), "the way north"], [Vector3(16.0, 1.0, 8.0), Vector3(22.0, 1.0, 8.0), "the east hall's end"]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at(pair[0]), at(pair[1]), 2))
		check(not hit.is_empty(), "blocked: %s" % pair[2])
	# Up the stairwell: the second floor, the fire door, the ground floor put away (not the lobby).
	await tp(Vector3(-12.0, hp.F2, 23.3), -PI * .5)
	await frames(60)
	check(bool(m.flags.get("hosp_upstairs", false)) and bool(m.flags.get("hosp_f1_shut", false)), "the second floor, the fire door shut")
	await frames(30)
	check(hp.R_F1 in hp.gone and not (hp.R_LOBBY in hp.gone), "the ground floor put away; the lobby kept for the balcony")
	# Doctor Berido, in the supply room.
	await tp(Vector3(20.8, hp.F2, 33.6), PI * .5)
	check(m.candidate(1) == "hosp_berido", "E by Doctor Berido: %s" % m.candidate(1))
	m.interact(1, "hosp_berido")
	for i in 12:
		await frames(10)
		m.interact(1, "hosp_listen")
	await frames(30)
	check(bool(m.flags.get("hosp_berido_talk", false)) and hp._doc_state == "follow", "he talked and follows (%s)" % hp._doc_state)
	await tp(Vector3(9.0, hp.F2, 30.0))
	await frames(400)
	check(hp._doc_local().x < 15.0, "he came out through the hole after the squad (%s)" % str(hp._doc_local().snapped(Vector3.ONE * .1)))
	# The ladder up into the duct (climbed for real), the crawl.
	await tp(Vector3(hp.LADDER_FOOT.x, hp.F2, 19.6), PI)
	game.player.rotation.y = PI
	Input.action_press("forward")
	await frames(240)
	Input.action_release("forward")
	await frames(20)
	check(here().y > 6.7 and here().y < 7.4, "up the ladder into the duct (%s)" % str(here().snapped(Vector3.ONE * .1)))
	check(game.player.crouching, "crouched in the duct")
	check(bool(m.flags.get("hosp_ladder", false)), "the ladder flag")
	await walk(PI, 9.0)
	await walk(-PI * .5, 16.0)
	await frames(80)
	check(bool(m.flags.get("hosp_records", false)) and here().y < 5.0, "dropped into the records room (%s)" % str(here().snapped(Vector3.ONE * .1)))
	Input.action_release("crouch")
	# The bookcase and the hidden stair.
	await tp(Vector3(-10.1, hp.F2, 31.9), 0.0)
	check(m.candidate(1) == "hosp_bookcase", "E at the bookcase: %s" % m.candidate(1))
	m.interact(1, "hosp_bookcase")
	await frames(140)
	await walk(PI, 1.8)
	await walk(-PI * .5, 7.0)
	await frames(30)
	check(here().y > 8.0, "up the hidden stair to the third floor (%s)" % str(here().snapped(Vector3.ONE * .1)))
	await tp(Vector3(-7.0, hp.F3, 29.0))
	await frames(40)
	check(bool(m.flags.get("hosp_third", false)) and bool(m.flags.get("hosp_f2_shut", false)), "the third floor; the second put away")
	var alive := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and not z.dead: alive += 1
	check(alive == 0, "the third floor is quiet (%d)" % alive)
	# The five things.
	for it: Array in hp.ITEMS:
		await tp(Vector3(it[2].x, hp.F3, it[2].z) + Vector3(.6, 0, .6))
		check(m.candidate(1) == "hosp_item_" + str(it[0]), "E at the %s: %s" % [it[1], m.candidate(1)])
		m.interact(1, "hosp_item_" + str(it[0]))
	await frames(20)
	await tp(hp.BERIDO_DOOR + Vector3(-1.6, 0, 0), -PI * .5)
	for i in 300:
		if hp._doc_local().distance_to(hp.BERIDO_DOOR) < 1.0: break
		await frames(2)
	check(m.candidate(1) == "hosp_give", "E at the doctor with them: %s" % m.candidate(1))
	m.interact(1, "hosp_give")
	check(bool(m.flags.get("hosp_items", false)), "all five given")
	await frames(460)
	check(bool(m.flags.get("lab_open", false)) and hp.big_door_n.position.z > hp.h(0, 0, 26.0).z, "the laboratory's door opened")
	m.flush_later()
	await frames(10)
	var lab := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and not z.dead: lab += 1
	check(lab >= 12, "the laboratory's people come out (%d)" % lab)
	for k in m.enemies.keys():
		if is_instance_valid(m.enemies[k]): m.damage(1, k, "head", m.enemies[k].global_position + Vector3.UP * 1.5, Vector3.FORWARD, 999.0, 60.0)
	await frames(60)
	check(bool(m.flags.get("hosp_lab_clear", false)), "the laboratory cleared")
	await tp(Vector3(9.0, hp.F3, 21.0))
	for i in 900:
		if hp._doc_state == "story": break
		await frames(2)
	for i in 10:
		m.interact(1, "hosp_listen")
		await frames(10)
	for i in 300:
		if m.flags.has("lucky") or hp.lucky != null: break
		await frames(2)
	await frames(60)
	check(hp.lucky != null and hp.lucky.boss != null, "Doctor Lucky out of his pod")
	var seen := {}
	for i in 1500:
		seen[hp.lucky.state] = true
		if i % 240 == 0: hp.lucky.special_wait = 0.0
		await frames(1)
	print("HOSPITAL lucky states seen: ", seen.keys())
	check(seen.has("leap") and seen.has("land"), "he leaps")
	check(seen.has("wall"), "he clings to the walls")
	check(hp.lucky.boss.global_position.y > at(Vector3(0, hp.F3 - 1.0, 0)).y, "he stays in the building")
	hp.lucky.debug_kill()
	await frames(30)
	check(bool(m.flags.get("hosp_lucky_dead", false)), "Doctor Lucky dead")
	await tp(Vector3(14.0, hp.LAB_ROOF, 30.6), PI)
	await frames(20)
	check(bool(m.flags.get("hosp_roof", false)), "on the roof")
	check(m.candidate(1) == "hosp_flare", "E at the flare: %s" % m.candidate(1))
	m.interact(1, "hosp_flare")
	await frames(320)
	check(m.stage == m.WON, "the flare up: won (stage %d)" % m.stage)
	print("INTERIOR_HOSPITAL %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
